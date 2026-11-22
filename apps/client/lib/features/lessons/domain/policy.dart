import 'package:flutter/foundation.dart';

import 'lesson.dart';

/// A tutor's cancellation policy, shown to parents. The lead tutor's policy
/// decides what a no-show or a late cancellation costs.
///
/// The rules here mirror services/api/internal/scheduling/policy.go, so the
/// demo backend behaves like the server.
@immutable
class CancellationPolicy {
  /// Creates a policy.
  const CancellationPolicy({
    required this.membershipId,
    required this.noticeHours,
    required this.lateCancellationBillable,
    required this.noShowBillable,
    required this.summary,
    this.isDefault = false,
  });

  /// Penny's default until a tutor sets their own: a day's notice, late
  /// cancellations free, no-shows charged.
  factory CancellationPolicy.defaultFor(String membershipId) =>
      CancellationPolicy(
        membershipId: membershipId,
        noticeHours: 24,
        lateCancellationBillable: false,
        noShowBillable: true,
        summary: defaultPolicySummary,
        isDefault: true,
      );

  /// Whose policy it is.
  final String membershipId;

  /// Cancelling with less notice than this is late.
  final int noticeHours;

  /// Whether a late cancellation is charged.
  final bool lateCancellationBillable;

  /// Whether a no-show is charged.
  final bool noShowBillable;

  /// The policy in the tutor's words.
  final String summary;

  /// Whether the tutor has not set one, so the default applies.
  final bool isDefault;
}

/// The default policy's words, as the server has them.
const defaultPolicySummary =
    'Cancel at least 24 hours before the lesson. Missed lessons are '
    'charged; late cancellations are not.';

/// The longest notice a policy may ask for: two weeks.
const maxNoticeHours = 14 * 24;

/// What a tutor sets.
@immutable
class PolicyDraft {
  /// Creates a draft.
  const PolicyDraft({
    required this.noticeHours,
    required this.lateCancellationBillable,
    required this.noShowBillable,
    this.summary = '',
  });

  /// Cancelling with less notice than this is late.
  final int noticeHours;

  /// Whether a late cancellation is charged.
  final bool lateCancellationBillable;

  /// Whether a no-show is charged.
  final bool noShowBillable;

  /// The policy in the tutor's words.
  final String summary;
}

/// Whether cancelling a lesson starting at [start], at [now], by [party],
/// breaks [policy]'s notice period. Only the student's side can cancel
/// late: a tutor's cancellation is never charged.
bool isLateCancellation(
  CancellationPolicy policy,
  CancellationParty party,
  DateTime start,
  DateTime now,
) {
  if (party != CancellationParty.student) return false;
  return now.isAfter(start.subtract(Duration(hours: policy.noticeHours)));
}

/// Whether a lesson in [status], cancelled late or not, is charged under
/// its lead tutor's [policy].
bool isBillable(
  CancellationPolicy policy,
  LessonStatus status, {
  bool lateCancellation = false,
}) => switch (status) {
  LessonStatus.completed => true,
  LessonStatus.noShow => policy.noShowBillable,
  LessonStatus.cancelled => lateCancellation && policy.lateCancellationBillable,
  LessonStatus.scheduled => false,
};
