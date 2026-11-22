import 'package:flutter/foundation.dart';

import 'lesson.dart';

/// Which lessons of a recurring lesson a change applies to. "This lesson"
/// changes the lesson itself; the others change the series from a day on
/// (api/openapi.yaml, `updateSeries`).
enum SeriesScope {
  /// Only the lesson opened.
  thisLesson,

  /// The lesson opened and every later one.
  thisAndFollowing,

  /// Every lesson from today on.
  allFuture,
}

/// Repeat rules as RFC 5545 RRULEs without DTSTART, UNTIL or COUNT: the
/// series' own fields say when it starts and ends.
///
/// Penny's forms book weekly lessons. A rule the API accepts but these
/// helpers do not read (monthly, say) still works; it just has no weekdays.
abstract final class Recurrence {
  static const _codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  /// A rule repeating on [weekdays] (DateTime.monday to DateTime.sunday)
  /// every [interval] weeks: `FREQ=WEEKLY;BYDAY=MO,TH`.
  static String weekly(Set<int> weekdays, {int interval = 1}) {
    assert(weekdays.isNotEmpty, 'A weekly rule needs at least one day.');
    final days = [
      for (final d in weekdays.toList()..sort()) _codes[d - 1],
    ].join(',');
    return [
      'FREQ=WEEKLY',
      if (interval > 1) 'INTERVAL=$interval',
      'BYDAY=$days',
    ].join(';');
  }

  /// The weekdays and interval of a weekly [rule], or null if [rule] is not
  /// weekly or names no days.
  static ({Set<int> weekdays, int interval})? parseWeekly(String rule) {
    final parts = _parts(rule);
    if (parts['FREQ'] != 'WEEKLY') return null;
    final days = <int>{};
    for (final code in (parts['BYDAY'] ?? '').split(',')) {
      final i = _codes.indexOf(code.trim());
      if (i >= 0) days.add(i + 1);
    }
    if (days.isEmpty) return null;
    return (
      weekdays: days,
      interval: int.tryParse(parts['INTERVAL'] ?? '') ?? 1,
    );
  }

  /// Whether [rule] repeats every [interval] days.
  static int? parseDaily(String rule) {
    final parts = _parts(rule);
    if (parts['FREQ'] != 'DAILY') return null;
    return int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
  }

  static Map<String, String> _parts(String rule) {
    final out = <String, String>{};
    for (final part
        in rule.toUpperCase().replaceFirst('RRULE:', '').split(';')) {
      final i = part.indexOf('=');
      if (i > 0) {
        out[part.substring(0, i).trim()] = part.substring(i + 1).trim();
      }
    }
    return out;
  }
}

/// A recurring lesson: a rule, evaluated in the team's timezone, and the
/// lesson it repeats. Every occurrence is its own [Lesson], booked ahead
/// over a rolling 12 weeks, so each carries its own notes and attendance.
@immutable
class Series {
  /// Creates a series.
  const Series({
    required this.id,
    required this.startsOn,
    required this.startTime,
    required this.durationMinutes,
    required this.recurrence,
    required this.timezone,
    required this.tutors,
    required this.students,
    required this.feeCents,
    required this.bookedUntil,
    required this.version,
    this.until,
    this.place,
    this.title = '',
    this.currency = 'SGD',
  });

  /// The series' ID.
  final String id;

  /// The first day, in the team's timezone, as UTC midnight.
  final DateTime startsOn;

  /// The wall-clock start: "16:00".
  final String startTime;

  /// How long each lesson lasts.
  final int durationMinutes;

  /// The repeat rule, such as `FREQ=WEEKLY;BYDAY=TH`.
  final String recurrence;

  /// The timezone the rule is evaluated in.
  final String timezone;

  /// The last day lessons may fall on; null repeats until stopped.
  final DateTime? until;

  /// Tutors, lead first.
  final List<LessonTutor> tutors;

  /// Students.
  final List<LessonStudent> students;

  /// Where lessons are.
  final LessonPlace? place;

  /// "Guitar, Grade 5", or empty.
  final String title;

  /// Each lesson's fee, in cents.
  final int feeCents;

  /// ISO 4217.
  final String currency;

  /// Lessons exist up to this day; more are booked as time passes.
  final DateTime bookedUntil;

  /// Send back when changing it.
  final int version;

  /// Minutes after midnight that each lesson starts.
  int get startMinute {
    final parts = startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// The lead tutor.
  LessonTutor? get lead {
    for (final t in tutors) {
      if (t.isLead) return t;
    }
    return tutors.firstOrNull;
  }
}

/// What it takes to book a recurring lesson.
@immutable
class SeriesDraft {
  /// Creates a draft.
  const SeriesDraft({
    required this.startsOn,
    required this.startTime,
    required this.durationMinutes,
    required this.recurrence,
    required this.tutors,
    required this.studentIds,
    this.until,
    this.locationId,
    this.title = '',
    this.feeCents = 0,
  });

  /// The first day, as UTC midnight.
  final DateTime startsOn;

  /// "16:00".
  final String startTime;

  /// How long each lesson lasts.
  final int durationMinutes;

  /// The repeat rule.
  final String recurrence;

  /// The last day lessons may fall on.
  final DateTime? until;

  /// Who teaches; exactly one lead.
  final List<TutorChoice> tutors;

  /// Who attends.
  final List<String> studentIds;

  /// A saved place.
  final String? locationId;

  /// A title.
  final String title;

  /// Each lesson's fee in cents.
  final int feeCents;
}

/// Changes to a series from [from] on. Null leaves a value.
@immutable
class SeriesChanges {
  /// Creates changes.
  const SeriesChanges({
    required this.from,
    this.startTime,
    this.durationMinutes,
    this.tutors,
    this.studentIds,
    this.locationId,
    this.title,
    this.feeCents,
  });

  /// The first day the change applies to, as UTC midnight. A day after the
  /// series started splits it: the old series ends the day before.
  final DateTime from;

  /// A new start, "16:30".
  final String? startTime;

  /// A new length.
  final int? durationMinutes;

  /// New tutors.
  final List<TutorChoice>? tutors;

  /// New students.
  final List<String>? studentIds;

  /// A new place.
  final String? locationId;

  /// A new title.
  final String? title;

  /// A new fee.
  final int? feeCents;
}

/// "16:00" for [minute] minutes after midnight.
String clockTime(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';
