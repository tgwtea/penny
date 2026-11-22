import 'package:penny_ui/penny_ui.dart';

import '../../../core/team_time.dart';
import '../../lessons/domain/lesson.dart';

/// The calendar's pure layout rules, apart from its widgets so they are
/// tested on their own: which instants a view loads, which hours its grid
/// shows, and how columns are counted.

/// What the calendar shows: one person's lessons, or the team's.
enum CalendarScope {
  /// The signed-in tutor's own lessons.
  mine,

  /// Every tutor's, for people who may see the team timetable.
  team,
}

/// The instants a view of [unit] around [date] (a team date) loads.
({DateTime from, DateTime to}) rangeFor(
  DateUnit unit,
  DateTime date,
  TeamTime time,
) {
  DateTime at(DateTime d) => time.instant(DateTime.utc(d.year, d.month, d.day));
  switch (unit) {
    case DateUnit.day:
      return (from: at(date), to: at(_addDays(date, 1)));
    case DateUnit.week:
      final monday = DateNavigator.startOfWeek(date);
      return (from: at(monday), to: at(_addDays(monday, 7)));
    case DateUnit.month:
      final days = MonthGrid.daysFor(date);
      return (from: at(days.first), to: at(_addDays(days.last, 1)));
  }
}

/// The seven days, Monday first, of the week containing [date].
List<DateTime> weekOf(DateTime date) {
  final monday = DateNavigator.startOfWeek(date);
  return [for (var i = 0; i < 7; i++) _addDays(monday, i)];
}

/// The hours a grid of [lessons] shows: working hours, widened to fit the
/// earliest start and the latest end with an hour to spare (Timetable
/// guideline, "Default range").
({int start, int end}) hoursFor(List<Lesson> lessons, TeamTime time) {
  var start = 8;
  var end = 20;
  for (final l in lessons) {
    final s = time.wallClock(l.startsAt);
    final e = time.wallClock(l.endsAt);
    start = s.hour - 1 < start ? s.hour - 1 : start;
    final last = e.day != s.day ? 24 : e.hour + (e.minute > 0 ? 2 : 1);
    end = last > end ? last : end;
  }
  return (start: start < 0 ? 0 : start, end: end > 24 ? 24 : end);
}

/// "4 lessons, 1 clash", "1 lesson" or "No lessons". Cancelled lessons are
/// not counted.
String lessonCount(List<Lesson> lessons) {
  final active = lessons
      .where((l) => l.status != LessonStatus.cancelled)
      .toList();
  if (active.isEmpty) return 'No lessons';
  final clashes = active.where((l) => l.clashes.isNotEmpty).length;
  final count = '${active.length} lesson${active.length == 1 ? '' : 's'}';
  return clashes == 0
      ? count
      : '$count, $clashes clash${clashes == 1 ? '' : 'es'}';
}

/// [lessons] once each, by start: a lesson several tutors teach is in each
/// of their timetable columns.
List<Lesson> distinctLessons(Iterable<Lesson> lessons) {
  final seen = <String>{};
  return [
    for (final l in lessons)
      if (seen.add(l.id)) l,
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

/// The team date [instant] falls on, as a local DateTime for the
/// navigator and grids, which compare fields only.
DateTime localDate(TeamTime time, DateTime instant) {
  final d = time.dateOf(instant);
  return DateTime(d.year, d.month, d.day);
}

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
