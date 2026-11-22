import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

/// {@template cancellation_policy_summary}
/// The lead tutor's policy, as parents see it.
/// {@endtemplate}
@immutable
class CancellationPolicySummary {
  /// {@macro cancellation_policy_summary}
  const CancellationPolicySummary({
    required this.noticeHours,
    required this.lateCancellationBillable,
    required this.noShowBillable,
    required this.summary,
  });

  /// Converts a `Map<String, dynamic>` to a [CancellationPolicySummary].
  factory CancellationPolicySummary.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CancellationPolicySummary',
      json,
      () => CancellationPolicySummary(
        noticeHours: json['noticeHours'] as int,
        lateCancellationBillable: json['lateCancellationBillable'] as bool,
        noShowBillable: json['noShowBillable'] as bool,
        summary: json['summary'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CancellationPolicySummary? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CancellationPolicySummary.fromJson(json);
  }

  final int noticeHours;
  final bool lateCancellationBillable;
  final bool noShowBillable;
  final String summary;

  /// Converts a [CancellationPolicySummary] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'noticeHours': noticeHours,
      'lateCancellationBillable': lateCancellationBillable,
      'noShowBillable': noShowBillable,
      'summary': summary,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    noticeHours,
    lateCancellationBillable,
    noShowBillable,
    summary,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CancellationPolicySummary &&
        noticeHours == other.noticeHours &&
        lateCancellationBillable == other.lateCancellationBillable &&
        noShowBillable == other.noShowBillable &&
        summary == other.summary;
  }
}
