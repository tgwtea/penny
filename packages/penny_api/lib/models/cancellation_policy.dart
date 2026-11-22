import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class CancellationPolicy {
  const CancellationPolicy({
    required this.membershipId,
    required this.noticeHours,
    required this.lateCancellationBillable,
    required this.noShowBillable,
    required this.summary,
    required this.isDefault,
  });

  /// Converts a `Map<String, dynamic>` to a [CancellationPolicy].
  factory CancellationPolicy.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CancellationPolicy',
      json,
      () => CancellationPolicy(
        membershipId: json['membershipId'] as String,
        noticeHours: json['noticeHours'] as int,
        lateCancellationBillable: json['lateCancellationBillable'] as bool,
        noShowBillable: json['noShowBillable'] as bool,
        summary: json['summary'] as String,
        isDefault: json['isDefault'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CancellationPolicy? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CancellationPolicy.fromJson(json);
  }

  final String membershipId;

  /// Cancelling with less notice than this is late.
  final int noticeHours;
  final bool lateCancellationBillable;
  final bool noShowBillable;

  /// The policy in the tutor's words, shown to parents.
  final String summary;

  /// The tutor has not set a policy, so Penny's default applies.
  final bool isDefault;

  /// Converts a [CancellationPolicy] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'membershipId': membershipId,
      'noticeHours': noticeHours,
      'lateCancellationBillable': lateCancellationBillable,
      'noShowBillable': noShowBillable,
      'summary': summary,
      'isDefault': isDefault,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    membershipId,
    noticeHours,
    lateCancellationBillable,
    noShowBillable,
    summary,
    isDefault,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CancellationPolicy &&
        membershipId == other.membershipId &&
        noticeHours == other.noticeHours &&
        lateCancellationBillable == other.lateCancellationBillable &&
        noShowBillable == other.noShowBillable &&
        summary == other.summary &&
        isDefault == other.isDefault;
  }
}
