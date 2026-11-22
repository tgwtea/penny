import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/team_time.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/series.dart';
import 'package:penny/features/lessons/presentation/series_views.dart';
import 'package:penny/features/timetable/presentation/calendar_layout.dart';
import 'package:penny_ui/penny_ui.dart';

const _sg = TeamTime('Asia/Singapore');

Lesson _lesson(
  String id,
  int hour, {
  int minutes = 45,
  LessonStatus status = LessonStatus.scheduled,
  bool clash = false,
}) {
  final start = _sg.instant(DateTime.utc(2026, 11, 19, hour));
  return Lesson(
    id: id,
    startsAt: start,
    endsAt: start.add(Duration(minutes: minutes)),
    status: status,
    kind: LessonKind.regular,
    tutors: const [],
    students: const [],
    feeCents: 0,
    billable: false,
    version: 1,
    clashes: clash
        ? [Clash(lessonId: 'x', startsAt: start, endsAt: start, who: 'Mei')]
        : const [],
  );
}

void main() {
  test('a week loads Monday to Monday in the team\'s time', () {
    final r = rangeFor(DateUnit.week, DateTime(2026, 11, 19), _sg);
    expect(r.from, DateTime.utc(2026, 11, 15, 16));
    expect(r.to, DateTime.utc(2026, 11, 22, 16));
    final day = rangeFor(DateUnit.day, DateTime(2026, 11, 19), _sg);
    expect(day.to.difference(day.from), const Duration(days: 1));
  });

  test('hours widen past working hours to fit, with an hour to spare', () {
    expect(hoursFor(const [], _sg), (start: 8, end: 20));
    expect(hoursFor([_lesson('a', 7), _lesson('b', 21)], _sg), (
      start: 6,
      end: 23,
    ));
  });

  test('columns count lessons and clashes, not cancellations', () {
    expect(lessonCount(const []), 'No lessons');
    expect(lessonCount([_lesson('a', 14)]), '1 lesson');
    expect(
      lessonCount([
        _lesson('a', 14, clash: true),
        _lesson('b', 15),
        _lesson('c', 16, status: LessonStatus.cancelled),
      ]),
      '2 lessons, 1 clash',
    );
  });

  test('a lesson in several columns counts once', () {
    final a = _lesson('a', 14);
    expect(distinctLessons([a, _lesson('b', 10), a]).map((l) => l.id), [
      'b',
      'a',
    ]);
  });

  test('repeat rules read as people say them', () {
    Series s(String rule) => Series(
      id: 's',
      startsOn: DateTime.utc(2026, 11, 19),
      startTime: '16:00',
      durationMinutes: 45,
      recurrence: rule,
      timezone: 'Asia/Singapore',
      tutors: const [],
      students: const [],
      feeCents: 0,
      bookedUntil: DateTime.utc(2027, 2, 11),
      version: 1,
    );
    expect(
      repeatText(s(Recurrence.weekly({DateTime.thursday}))),
      'Every Thursday',
    );
    expect(
      repeatText(s(Recurrence.weekly({DateTime.monday, DateTime.thursday}))),
      'Every Monday and Thursday',
    );
    expect(
      repeatText(s(Recurrence.weekly({DateTime.friday}, interval: 2))),
      'Every two weeks on Friday',
    );
    expect(repeatText(s('FREQ=DAILY')), 'Every day');
    expect(repeatText(s('FREQ=MONTHLY;BYMONTHDAY=1')), 'Repeats');
    expect(Recurrence.weekly({4, 1}), 'FREQ=WEEKLY;BYDAY=MO,TH');
    final fortnightly = Recurrence.parseWeekly(
      'FREQ=WEEKLY;INTERVAL=2;BYDAY=FR',
    );
    expect(fortnightly?.weekdays, {DateTime.friday});
    expect(fortnightly?.interval, 2);
  });
}
