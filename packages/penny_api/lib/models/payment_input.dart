import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/payment_method.dart';

@immutable
class PaymentInput {
  PaymentInput({
    required this.amountCents,
    required this.paidOn,
    required this.method,
  }) {
    amountCents.validate(min: 1);
  }

  /// Converts a `Map<String, dynamic>` to a [PaymentInput].
  factory PaymentInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentInput',
      json,
      () => PaymentInput(
        amountCents: json['amountCents'] as int,
        paidOn: Date.fromJson(json['paidOn'] as String),
        method: PaymentMethod.fromJson(json['method'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentInput.fromJson(json);
  }

  final int amountCents;
  final Date paidOn;
  final PaymentMethod method;

  /// Converts a [PaymentInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'amountCents': amountCents,
      'paidOn': paidOn.toJson(),
      'method': method.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([amountCents, paidOn, method]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentInput &&
        amountCents == other.amountCents &&
        paidOn == other.paidOn &&
        method == other.method;
  }
}
