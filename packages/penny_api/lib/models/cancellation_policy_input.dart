import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class CancellationPolicyInput {
  CancellationPolicyInput({
    required this.noticeHours,
    required this.lateCancellationBillable,
    required this.noShowBillable,
    this.summary,
  }) {
    noticeHours.validate(min: 0, max: 336);
    summary?.validate(maxLength: 500);
  }

  /// Converts a `Map<String, dynamic>` to a [CancellationPolicyInput].
  factory CancellationPolicyInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CancellationPolicyInput',
      json,
      () => CancellationPolicyInput(
        noticeHours: json['noticeHours'] as int,
        lateCancellationBillable: json['lateCancellationBillable'] as bool,
        noShowBillable: json['noShowBillable'] as bool,
        summary: json['summary'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CancellationPolicyInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CancellationPolicyInput.fromJson(json);
  }

  final int noticeHours;
  final bool lateCancellationBillable;
  final bool noShowBillable;
  final String? summary;

  /// Converts a [CancellationPolicyInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'noticeHours': noticeHours,
      'lateCancellationBillable': lateCancellationBillable,
      'noShowBillable': noShowBillable,
      'summary': ?summary,
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
    return other is CancellationPolicyInput &&
        noticeHours == other.noticeHours &&
        lateCancellationBillable == other.lateCancellationBillable &&
        noShowBillable == other.noShowBillable &&
        summary == other.summary;
  }
}
