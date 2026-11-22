import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/lesson_repository.dart';
import 'package:penny/features/lessons/domain/location.dart';
import 'package:penny/features/lessons/domain/policy.dart';
import 'package:penny/features/students/domain/student.dart';
import 'package:penny/features/students/domain/student_repository.dart';

/// A team as its owner, who also tutors ([tutorId]).
typedef LessonFixture = ({
  LessonRepository lessons,
  LocationRepository locations,
  PolicyRepository policies,
  StudentRepository students,
  String teamId,
  String tutorId,
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
}
