import 'package:flutter/foundation.dart';

/// Times in a team's timezone (DESIGN.md: times are always shown in the
/// team's timezone, whatever the device's).
///
/// Penny's teams are in fixed-offset zones today, listed here. A zone with
/// daylight saving needs a timezone database (the `timezone` package); add
/// it here, behind this same class, when the first such team appears.
/// Unknown zones fall back to UTC rather than guessing.
@immutable
class TeamTime {
  /// Times for a team in [timezone], an IANA name.
  const TeamTime(this.timezone);

  /// The team's IANA timezone name.
  final String timezone;

  static const _offsetMinutes = {
    'Asia/Singapore': 480,
    'Asia/Kuala_Lumpur': 480,
    'Asia/Hong_Kong': 480,
    'Asia/Manila': 480,
    'Asia/Shanghai': 480,
    'Asia/Taipei': 480,
    'Asia/Jakarta': 420,
    'Asia/Bangkok': 420,
    'Asia/Ho_Chi_Minh': 420,
    'Asia/Tokyo': 540,
    'Asia/Seoul': 540,
    'Asia/Kolkata': 330,
    'UTC': 0,
  };

  /// How far the team's clock is ahead of UTC.
  Duration get offset => Duration(minutes: _offsetMinutes[timezone] ?? 0);

  /// The team's wall clock at [instant]: a DateTime whose fields read the
  /// team's date and time. It is marked UTC so the device's own timezone
  /// never shifts it again; format it, never compare it with instants.
  DateTime wallClock(DateTime instant) => instant.toUtc().add(offset);

  /// The instant at which the team's clock reads [wall]'s fields.
  DateTime instant(DateTime wall) => DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  ).subtract(offset);

  /// The start of the team's day containing [instant], as an instant.
  DateTime startOfDay(DateTime instant) {
    final w = wallClock(instant);
    return this.instant(DateTime.utc(w.year, w.month, w.day));
  }

  /// The team's calendar date at [instant], at midnight, as wall clock.
  DateTime dateOf(DateTime instant) {
    final w = wallClock(instant);
    return DateTime.utc(w.year, w.month, w.day);
  }
}
