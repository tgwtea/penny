import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/lesson_repository.dart';
import 'package:penny/features/lessons/domain/location.dart';
import 'package:penny/features/lessons/domain/policy.dart';
import 'package:penny/features/lessons/domain/series.dart';
import 'package:penny/features/students/domain/student.dart';
import 'package:penny/features/students/domain/student_repository.dart';
import 'package:penny/features/timetable/domain/timetable.dart';

/// A team as its owner, who also tutors ([tutorId]), with a teacher
/// ([otherTutorId]).
typedef LessonFixture = ({
  LessonRepository lessons,
  LocationRepository locations,
  PolicyRepository policies,
  StudentRepository students,
  SeriesRepository series,
  TimetableRepository timetable,
  CalendarFeedRepository feeds,
  String teamId,
  String tutorId,
  String otherTutorId,
});

/// What every LessonRepository, LocationRepository and PolicyRepository
/// must do (ADR 012). Times are relative to now: the late-cancellation rule
/// depends on it.
void lessonRepositoryContract(
  String implementation,
  Future<LessonFixture> Function() setUp,
) {
  final soon = DateTime.now().toUtc().add(const Duration(hours: 3));
  final later = soon.add(const Duration(days: 10));

  Future<(LessonFixture, String)> withStudent() async {
    final f = await setUp();
    final s = await f.students.create(
      f.teamId,
      const StudentDraft(name: 'Cora Lessons'),
    );
    return (f, s.id);
  }

  LessonDraft draft(LessonFixture f, String student, DateTime start) =>
      LessonDraft(
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 45)),
        tutors: [(membershipId: f.tutorId, role: TutorRole.lead)],
        studentIds: [student],
        feeCents: 6000,
        title: 'Guitar',
      );

  group('$implementation honours the lesson contracts', () {
    test('books a lesson and lists it in its range only', () async {
      final (f, student) = await withStudent();
      final l = await f.lessons.create(f.teamId, draft(f, student, soon));
      expect(l.status, LessonStatus.scheduled);
      expect(l.billable, isFalse);
      expect(l.lead?.membershipId, f.tutorId);
      expect(l.students.single.name, 'Cora Lessons');

      final inRange = await f.lessons.lessons(
        f.teamId,
        from: soon.subtract(const Duration(hours: 1)),
        to: soon.add(const Duration(hours: 1)),
      );
      expect(inRange.map((x) => x.id), contains(l.id));
      final outside = await f.lessons.lessons(
        f.teamId,
        from: later,
        to: later.add(const Duration(days: 1)),
      );
      expect(outside.map((x) => x.id), isNot(contains(l.id)));
    });

    test('a stale version is refused; done and Undo round-trip', () async {
      final (f, student) = await withStudent();
      final l = await f.lessons.create(f.teamId, draft(f, student, soon));
      final done = await f.lessons.complete(f.teamId, l);
      expect(done.status, LessonStatus.completed);
      expect(done.billable, isTrue);
      expect(done.students.single.attendance, Attendance.present);

      await expectLater(
        f.lessons.reopen(f.teamId, l),
        throwsA(isA<ConflictFailure>()),
        reason: 'the lesson changed since this version',
      );
      final undone = await f.lessons.reopen(f.teamId, done);
      expect(undone.status, LessonStatus.scheduled);
      expect(undone.billable, isFalse);
    });

    test('overlapping lessons for one tutor clash, and never block', () async {
      final (f, student) = await withStudent();
      final other = await f.students.create(
        f.teamId,
        const StudentDraft(name: 'Dex Overlap'),
      );
      final a = await f.lessons.create(f.teamId, draft(f, student, later));
      final b = await f.lessons.create(
        f.teamId,
        draft(f, other.id, later.add(const Duration(minutes: 30))),
      );
      expect(b.clashes.single.lessonId, a.id);
      expect(b.clashes.single.membershipId, f.tutorId);
      final reread = await f.lessons.lesson(f.teamId, a.id);
      expect(reread.clashes.single.lessonId, b.id);
    });

    test('a late cancellation by the family is free by default', () async {
      final (f, student) = await withStudent();
      final l = await f.lessons.create(f.teamId, draft(f, student, soon));
      final cancelled = await f.lessons.cancel(
        f.teamId,
        l,
        party: CancellationParty.student,
        reason: 'Unwell',
        makeup: (
          startsAt: later,
          endsAt: later.add(const Duration(minutes: 45)),
        ),
      );
      expect(cancelled.status, LessonStatus.cancelled);
      expect(cancelled.cancellation?.late, isTrue);
      expect(cancelled.billable, isFalse);
      expect(cancelled.makeupLessonId, isNotNull);
      final makeup = await f.lessons.lesson(
        f.teamId,
        cancelled.makeupLessonId!,
      );
      expect(makeup.kind, LessonKind.makeup);
      expect(makeup.makeupForLessonId, l.id);
    });

    test('the lead tutor\'s own policy decides', () async {
      final (f, student) = await withStudent();
      final def = await f.policies.policy(f.teamId, f.tutorId);
      expect(def.isDefault, isTrue);
      expect(def.noticeHours, 24);
      final set = await f.policies.setPolicy(
        f.teamId,
        f.tutorId,
        const PolicyDraft(
          noticeHours: 48,
          lateCancellationBillable: true,
          noShowBillable: false,
          summary: 'Two days, please.',
        ),
      );
      expect(set.isDefault, isFalse);
      final l = await f.lessons.create(f.teamId, draft(f, student, soon));
      final noShow = await f.lessons.markNoShow(f.teamId, l);
      expect(noShow.status, LessonStatus.noShow);
      expect(noShow.billable, isFalse, reason: 'this policy waives no-shows');
      final detail = await f.lessons.lesson(f.teamId, l.id);
      expect(detail.policy?.summary, 'Two days, please.');
    });

    test('tasks are added, ticked and removed; history records it', () async {
      final (f, student) = await withStudent();
      final l = await f.lessons.create(f.teamId, draft(f, student, soon));
      final task = await f.lessons.addItem(
        f.teamId,
        l.id,
        kind: ItemKind.task,
        body: 'Practise scales',
      );
      expect(task.done, isFalse);
      final ticked = await f.lessons.updateItem(
        f.teamId,
        l.id,
        task.id,
        done: true,
      );
      expect(ticked.done, isTrue);
      final detail = await f.lessons.lesson(f.teamId, l.id);
      expect(detail.items?.single.body, 'Practise scales');
      await f.lessons.deleteItem(f.teamId, l.id, task.id);
      expect((await f.lessons.lesson(f.teamId, l.id)).items, isEmpty);
      final history = await f.lessons.history(f.teamId, l.id);
      expect(history.first.action, 'lesson.created');
      expect(history.length, greaterThanOrEqualTo(3));
    });

    test('places are saved, checked and archived', () async {
      final f = await setUp();
      final place = await f.locations.create(
        f.teamId,
        const LocationDraft(
          name: 'Room 9',
          kind: LocationKind.inPerson,
          addressLine1: '1 Test Road',
          postalCode: '123456',
        ),
      );
      expect(
        (await f.locations.locations(f.teamId)).map((l) => l.id),
        contains(place.id),
      );
      await expectLater(
        f.locations.create(
          f.teamId,
          const LocationDraft(
            name: 'Nowhere',
            kind: LocationKind.inPerson,
            postalCode: '12',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      await f.locations.archive(f.teamId, place.id);
      expect(
        (await f.locations.locations(f.teamId)).map((l) => l.id),
        isNot(contains(place.id)),
      );
    });
  });

  // Series and the timetable, in the team's time (Singapore, UTC+8).
  const offset = Duration(hours: 8);
  final wall = soon.add(offset);
  final firstDay = DateTime.utc(wall.year, wall.month, wall.day + 2);
  DateTime at(DateTime day, int hour) =>
      DateTime.utc(day.year, day.month, day.day, hour).subtract(offset);
  DateTime plusDays(DateTime day, int n) =>
      DateTime.utc(day.year, day.month, day.day + n);

  SeriesDraft weekly(LessonFixture f, String student) => SeriesDraft(
    startsOn: firstDay,
    startTime: '16:00',
    durationMinutes: 45,
    recurrence: Recurrence.weekly({firstDay.weekday}),
    tutors: [(membershipId: f.tutorId, role: TutorRole.lead)],
    studentIds: [student],
    title: 'Guitar',
    feeCents: 6000,
  );

  Future<List<Lesson>> lessonsOf(LessonFixture f, String student) =>
      f.lessons.lessons(
        f.teamId,
        from: at(firstDay, 0),
        to: at(plusDays(firstDay, 21), 0),
        studentId: student,
      );

  group('$implementation honours the series and timetable contracts', () {
    test('a weekly series books each week as its own lesson', () async {
      final (f, student) = await withStudent();
      final s = await f.series.create(f.teamId, weekly(f, student));
      expect(Recurrence.parseWeekly(s.recurrence)?.weekdays, {
        firstDay.weekday,
      });
      expect(s.startTime, '16:00');
      expect(s.lead?.membershipId, f.tutorId);
      expect(
        s.bookedUntil.isAfter(plusDays(firstDay, 60)),
        isTrue,
        reason: 'booked weeks ahead',
      );
      final booked = await lessonsOf(f, student);
      expect(booked, hasLength(3));
      expect(booked.map((l) => l.seriesId).toSet(), {s.id});
      expect(booked.first.startsAt, at(firstDay, 16));
      expect(booked[1].startsAt, at(plusDays(firstDay, 7), 16));
      final read = await f.series.series(f.teamId, s.id);
      expect(read.version, s.version);
    });

    test('a change from a later day splits the series', () async {
      final (f, student) = await withStudent();
      final s = await f.series.create(f.teamId, weekly(f, student));
      final second = plusDays(firstDay, 7);
      final changed = await f.series.update(
        f.teamId,
        s,
        SeriesChanges(from: second, startTime: '17:00'),
      );
      expect(changed.id, isNot(s.id));
      expect(changed.startsOn, second);
      expect(changed.startTime, '17:00');
      final booked = await lessonsOf(f, student);
      expect(booked.first.startsAt, at(firstDay, 16));
      expect(booked.first.seriesId, s.id);
      expect(booked[1].startsAt, at(second, 17));
      expect(booked[1].seriesId, changed.id);
      final old = await f.series.series(f.teamId, s.id);
      expect(old.until, plusDays(second, -1));

      await expectLater(
        f.series.update(f.teamId, s, SeriesChanges(from: second)),
        throwsA(isA<ConflictFailure>()),
        reason: 'the series changed since this version',
      );
    });

    test('a change from the first day rewrites every lesson', () async {
      final (f, student) = await withStudent();
      final s = await f.series.create(f.teamId, weekly(f, student));
      final changed = await f.series.update(
        f.teamId,
        s,
        SeriesChanges(from: firstDay, durationMinutes: 60, title: 'Piano'),
      );
      expect(changed.id, s.id);
      expect(changed.version, greaterThan(s.version));
      final booked = await lessonsOf(f, student);
      expect(booked.every((l) => l.length == const Duration(hours: 1)), isTrue);
      expect(booked.every((l) => l.title == 'Piano'), isTrue);
    });

    test('ending a series removes the lessons after the day', () async {
      final (f, student) = await withStudent();
      final s = await f.series.create(f.teamId, weekly(f, student));
      final second = plusDays(firstDay, 7);
      final ended = await f.series.end(f.teamId, s, after: second);
      expect(ended.until, second);
      expect(await lessonsOf(f, student), hasLength(2));
    });

    test('the timetable has a column for every tutor', () async {
      final (f, student) = await withStudent();
      final shared = await f.lessons.create(
        f.teamId,
        LessonDraft(
          startsAt: at(firstDay, 9),
          endsAt: at(firstDay, 10),
          tutors: [
            (membershipId: f.tutorId, role: TutorRole.lead),
            (membershipId: f.otherTutorId, role: TutorRole.assisting),
          ],
          studentIds: [student],
        ),
      );
      final day = await f.timetable.timetable(
        f.teamId,
        from: at(firstDay, 0),
        to: at(plusDays(firstDay, 1), 0),
      );
      final ids = day.map((c) => c.membershipId).toList();
      expect(ids, containsAll([f.tutorId, f.otherTutorId]));
      for (final id in [f.tutorId, f.otherTutorId]) {
        final column = day.firstWhere((c) => c.membershipId == id);
        expect(
          column.lessons.map((l) => l.id),
          contains(shared.id),
          reason: 'a shared lesson is in each tutor\'s column',
        );
      }

      final quiet = plusDays(firstDay, 200);
      final empty = await f.timetable.timetable(
        f.teamId,
        from: at(quiet, 0),
        to: at(plusDays(quiet, 1), 0),
      );
      expect(empty.map((c) => c.membershipId), containsAll(ids));
      expect(empty.every((c) => c.lessons.isEmpty), isTrue);

      final only = await f.timetable.timetable(
        f.teamId,
        from: at(firstDay, 0),
        to: at(plusDays(firstDay, 1), 0),
        teacherIds: [f.otherTutorId],
      );
      expect(only.map((c) => c.membershipId), [f.otherTutorId]);

      await expectLater(
        f.timetable.timetable(
          f.teamId,
          from: at(firstDay, 0),
          to: at(plusDays(firstDay, 8), 0),
        ),
        throwsA(isA<ValidationFailure>()),
        reason: 'at most 7 days at a time',
      );
    });

    test('a calendar link is made, replaced and stopped', () async {
      final f = await setUp();
      final first = await f.feeds.createFeed(f.teamId, f.tutorId);
      expect(first, contains('/v1/calendar/'));
      final second = await f.feeds.createFeed(f.teamId, f.tutorId);
      expect(second, isNot(first));
      await f.feeds.revokeFeed(f.teamId, f.tutorId);
      await expectLater(
        f.feeds.revokeFeed(f.teamId, f.tutorId),
        throwsA(isA<NotFoundFailure>()),
        reason: 'no link left to stop',
      );
    });
  });
}
