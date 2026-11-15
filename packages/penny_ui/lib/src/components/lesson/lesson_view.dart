import 'package:flutter/foundation.dart';

import '../../foundation/format.dart';

/// Where a lesson is in its life.
enum LessonViewStatus {
  /// The default; shows no badge.
  scheduled,

  /// Completed.
  done,

  /// Cancelled.
  cancelled,

  /// The student did not come.
  noShow,
}

/// A tutor on a lesson, as the components need them.
@immutable
class LessonViewTutor {
  /// Creates a tutor reference.
  const LessonViewTutor({required this.membershipId, required this.name});

  /// The tutor's membership in the team (not their user ID: one person can
  /// teach in several teams).
  final String membershipId;

  /// The tutor's full name.
  final String name;
}

/// What LessonRow and LessonBlock show about one lesson.
///
/// Apps map their domain lesson into this; penny_ui knows nothing of
/// repositories or permissions. Times are already in the team's timezone.
@immutable
class LessonView {
  /// Creates a lesson view.
  const LessonView({
    required this.id,
    required this.start,
    required this.end,
    required this.students,
    required this.tutors,
    this.status = LessonViewStatus.scheduled,
    this.hasClash = false,
    this.isMakeUp = false,
    this.location,
    this.isOnline = false,
  });

  /// The lesson's ID.
  final String id;

  /// When it starts, in the team's timezone.
  final DateTime start;

  /// When it ends, in the team's timezone.
  final DateTime end;

  /// Student names, in display order. Any number (ADR 017).
  final List<String> students;

  /// Tutors, lead first. Any number (ADR 017).
  final List<LessonViewTutor> tutors;

  /// Its status.
  final LessonViewStatus status;

  /// Whether a tutor or student on it is double-booked. Clashes warn and
  /// never block (ADR 019); the rule itself lives in the app's domain.
  final bool hasClash;

  /// Whether it replaces a cancelled lesson.
  final bool isMakeUp;

  /// The address line of an in-person location.
  final String? location;

  /// Whether it happens online.
  final bool isOnline;

  /// Whether more than one tutor teaches it.
  bool get isShared => tutors.length > 1;

  /// The one meta line under the names, from the viewer's point of view: the
  /// other tutors ("Shared with Aisha"), else the place, else "Make-up".
  /// [viewerMembershipId] is the tutor looking at it, if any.
  String? metaLine({String? viewerMembershipId}) {
    final others = tutors
        .where((t) => t.membershipId != viewerMembershipId)
        .toList();
    if (isShared && others.isNotEmpty) {
      final names = PennyFormat.names(
        others.map((t) => PennyFormat.firstName(t.name)).toList(),
      );
      return 'Shared with $names';
    }
    if (location != null) return location;
    if (isOnline) return 'Online';
    if (isMakeUp) return 'Make-up';
    return null;
  }
}
