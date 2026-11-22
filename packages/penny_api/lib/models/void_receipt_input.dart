import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/payment_input.dart';

@immutable
class VoidReceiptInput {
  VoidReceiptInput({required this.reason, this.correction}) {
    reason.validate(minLength: 1, maxLength: 500);
  }

  /// Converts a `Map<String, dynamic>` to a [VoidReceiptInput].
  factory VoidReceiptInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'VoidReceiptInput',
      json,
      () => VoidReceiptInput(
        reason: json['reason'] as String,
        correction: PaymentInput.maybeFromJson(
          json['correction'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static VoidReceiptInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return VoidReceiptInput.fromJson(json);
  }

  final String reason;
  final PaymentInput? correction;

  /// Converts a [VoidReceiptInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'reason': reason, 'correction': ?correction?.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([reason, correction]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoidReceiptInput &&
        reason == other.reason &&
        correction == other.correction;
  }
}
