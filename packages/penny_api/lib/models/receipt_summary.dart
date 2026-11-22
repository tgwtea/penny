import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/member_ref.dart';
import 'package:penny_api/models/student_ref.dart';

@immutable
class ReceiptSummary {
  const ReceiptSummary({
    required this.id,
    required this.number,
    required this.issuedAt,
    required this.amountCents,
    required this.currency,
    required this.student,
    required this.payee,
    required this.voided,
  });

  /// Converts a `Map<String, dynamic>` to a [ReceiptSummary].
  factory ReceiptSummary.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ReceiptSummary',
      json,
      () => ReceiptSummary(
        id: json['id'] as String,
        number: json['number'] as String,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        amountCents: json['amountCents'] as int,
        currency: json['currency'] as String,
        student: StudentRef.fromJson(json['student'] as Map<String, dynamic>),
        payee: MemberRef.fromJson(json['payee'] as Map<String, dynamic>),
        voided: json['voided'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ReceiptSummary? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ReceiptSummary.fromJson(json);
  }

  final String id;
  final String number;
  final DateTime issuedAt;
  final int amountCents;
  final String currency;
  final StudentRef student;

  /// A team member, as other records mention them.
  final MemberRef payee;
  final bool voided;

  /// Converts a [ReceiptSummary] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'amountCents': amountCents,
      'currency': currency,
      'student': student.toJson(),
      'payee': payee.toJson(),
      'voided': voided,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    number,
    issuedAt,
    amountCents,
    currency,
    student,
    payee,
    voided,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptSummary &&
        id == other.id &&
        number == other.number &&
        issuedAt == other.issuedAt &&
        amountCents == other.amountCents &&
        currency == other.currency &&
        student == other.student &&
        payee == other.payee &&
        voided == other.voided;
  }
}
