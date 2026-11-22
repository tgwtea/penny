import 'package:meta/meta.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/payment_method.dart';

@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.amountCents,
    required this.paidOn,
    required this.method,
    required this.recordedBy,
    required this.recordedAt,
  });

  /// Converts a `Map<String, dynamic>` to a [PaymentRecord].
  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentRecord',
      json,
      () => PaymentRecord(
        amountCents: json['amountCents'] as int,
        paidOn: Date.fromJson(json['paidOn'] as String),
        method: PaymentMethod.fromJson(json['method'] as String),
        recordedBy: json['recordedBy'] as String,
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentRecord? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentRecord.fromJson(json);
  }

  final int amountCents;
  final Date paidOn;
  final PaymentMethod method;

  /// Who confirmed it.
  final String recordedBy;
  final DateTime recordedAt;

  /// Converts a [PaymentRecord] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'amountCents': amountCents,
      'paidOn': paidOn.toJson(),
      'method': method.toJson(),
      'recordedBy': recordedBy,
      'recordedAt': recordedAt.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([amountCents, paidOn, method, recordedBy, recordedAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRecord &&
        amountCents == other.amountCents &&
        paidOn == other.paidOn &&
        method == other.method &&
        recordedBy == other.recordedBy &&
        recordedAt == other.recordedAt;
  }
}
