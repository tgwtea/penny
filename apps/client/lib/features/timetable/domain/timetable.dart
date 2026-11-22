import 'package:flutter/foundation.dart';

import '../../lessons/domain/lesson.dart';

/// One tutor's column of the team timetable: who, and the lessons they
/// tutor in the range. A tutor with no lessons still has a column, so free
/// time shows.
@immutable
class TutorColumn {
  /// Creates a column.
  const TutorColumn({
    required this.membershipId,
    required this.name,
    required this.lessons,
  });

  /// The tutor's membership.
  final String membershipId;

  /// Their name.
  final String name;

  /// Their lessons, by start. A lesson several tutors teach is in each of
  /// their columns.
  final List<Lesson> lessons;
}

/// The team timetable (PRD R3): every current owner and teacher side by
/// side. Needs `view_team_timetable`; others get a ForbiddenFailure.
abstract interface class TimetableRepository {
  /// One column per current owner and teacher, owners first, then by name,
  /// with lessons overlapping [from] to [to] (instants, at most 7 days
  /// apart). [teacherIds] keeps only those tutors' columns.
  Future<List<TutorColumn>> timetable(
    String teamId, {
    required DateTime from,
    required DateTime to,
    List<String>? teacherIds,
  });
}

/// A tutor's private calendar link (an iCalendar feed) to subscribe to in
/// Google or Apple Calendar. Penny keeps only a hash of the link, so it is
/// shown once, when made.
abstract interface class CalendarFeedRepository {
  /// Makes a new link for [membershipId] and returns it. Any earlier link
  /// stops working. The tutor themselves, or the owner.
  Future<String> createFeed(String teamId, String membershipId);

  /// Stops [membershipId]'s link working.
  Future<void> revokeFeed(String teamId, String membershipId);
}
