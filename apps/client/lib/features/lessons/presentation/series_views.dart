// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/team_time.dart';
import '../domain/lesson.dart';
import '../domain/series.dart';

/// How a series and its scopes read (brand book, "Voice").

/// "Every Thursday", "Every Monday and Thursday", "Every two weeks on
/// Thursday", "Every day", or "Repeats" for a rule Penny's forms do not
/// book.
String repeatText(Series s) {
  final weekly = Recurrence.parseWeekly(s.recurrence);
  if (weekly != null) {
    final names = [
      for (final d in weekly.weekdays.toList()..sort())
        // 16 November 2026 was a Monday.
        PennyFormat.weekday(DateTime(2026, 11, 15 + d)),
    ];
    final days = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return switch (weekly.interval) {
      1 => 'Every $days',
      2 => 'Every two weeks on $days',
      final n => 'Every $n weeks on $days',
    };
  }
  final daily = Recurrence.parseDaily(s.recurrence);
  if (daily == 1) return 'Every day';
  if (daily != null) return 'Every $daily days';
  return 'Repeats';
}

/// "Every Thursday, 16:00 to 16:45, until Thu 11 Feb."
String seriesSummary(BuildContext context, Series s) {
  final start = DateTime(2000, 1, 1, s.startMinute ~/ 60, s.startMinute % 60);
  final end = start.add(Duration(minutes: s.durationMinutes));
  final until = s.until;
  return '${repeatText(s)}, ${PennyFormat.timeRange(context, start, end)}'
      '${until == null ? '' : ', until ${PennyFormat.shortDate(until)}'}.';
}

/// The scopes offered when changing a lesson that repeats.
const seriesScopeChoices = [
  PennyChoice(value: SeriesScope.thisLesson, label: 'This lesson'),
  PennyChoice(
    value: SeriesScope.thisAndFollowing,
    label: 'This and following lessons',
  ),
  PennyChoice(
    value: SeriesScope.allFuture,
    label: 'All lessons from today',
    description: 'Lessons that are done or cancelled stay as they were.',
  ),
];

/// The first day a change in [scope] applies to: the day of the lesson
/// opened, or today, as a team date.
DateTime seriesChangeFrom(
  SeriesScope scope, {
  required Lesson lesson,
  required TeamTime time,
  required DateTime now,
}) => scope == SeriesScope.thisAndFollowing
    ? time.dateOf(lesson.startsAt)
    : time.dateOf(now);
