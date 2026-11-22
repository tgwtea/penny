import 'package:meta/meta.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/payment_request_status.dart';
import 'package:penny_api/models/public_payment_line.dart';
import 'package:penny_api/models/receipt_ref.dart';
import 'package:penny_api/models/student_ref.dart';

@immutable
class FamilyPaymentRequest {
  const FamilyPaymentRequest({
    required this.teamName,
    required this.payeeName,
    required this.studentFirstName,
    required this.amountCents,
    required this.currency,
    required this.reference,
    required this.dueOn,
    required this.lines,
    required this.status,
    required this.payerConfirmed,
    required this.coTaught,
    required this.id,
    required this.student,
    required this.createdAt,
    this.paynowPayload,
    this.cancellationPolicy,
    this.receipt,
  });

  /// Converts a `Map<String, dynamic>` to a [FamilyPaymentRequest].
  factory FamilyPaymentRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyPaymentRequest',
      json,
      () => FamilyPaymentRequest(
        teamName: json['teamName'] as String,
        payeeName: json['payeeName'] as String,
        studentFirstName: json['studentFirstName'] as String,
        amountCents: json['amountCents'] as int,
        currency: json['currency'] as String,
        reference: json['reference'] as String,
        dueOn: Date.fromJson(json['dueOn'] as String),
        lines: (json['lines'] as List)
            .map<PublicPaymentLine>(
              (e) => PublicPaymentLine.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        status: PaymentRequestStatus.fromJson(json['status'] as String),
        payerConfirmed: json['payerConfirmed'] as bool,
        paynowPayload: json['paynowPayload'] as String?,
        coTaught: json['coTaught'] as bool,
        cancellationPolicy: json['cancellationPolicy'] as String?,
        id: json['id'] as String,
        student: StudentRef.fromJson(json['student'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
        receipt: ReceiptRef.maybeFromJson(
          json['receipt'] as Map<String, dynamic>?,
        ),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyPaymentRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyPaymentRequest.fromJson(json);
  }

  final String teamName;
  final String payeeName;
  final String studentFirstName;
  final int amountCents;
  final String currency;
  final String reference;
  final Date dueOn;
  final List<PublicPaymentLine> lines;
  final PaymentRequestStatus status;
  final bool payerConfirmed;

  /// The PayNow QR code's content. Absent once paid or cancelled.
  final String? paynowPayload;
  final bool coTaught;

  /// The payee's cancellation policy, in their words.
  final String? cancellationPolicy;
  final String id;
  final StudentRef student;
  final DateTime createdAt;
  final ReceiptRef? receipt;

  /// Converts a [FamilyPaymentRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'teamName': teamName,
      'payeeName': payeeName,
      'studentFirstName': studentFirstName,
      'amountCents': amountCents,
      'currency': currency,
      'reference': reference,
      'dueOn': dueOn.toJson(),
      'lines': lines.map((e) => e.toJson()).toList(),
      'status': status.toJson(),
      'payerConfirmed': payerConfirmed,
      'paynowPayload': ?paynowPayload,
      'coTaught': coTaught,
      'cancellationPolicy': ?cancellationPolicy,
      'id': id,
      'student': student.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'receipt': ?receipt?.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    teamName,
    payeeName,
    studentFirstName,
    amountCents,
    currency,
    reference,
    dueOn,
    listHash(lines),
    status,
    payerConfirmed,
    paynowPayload,
    coTaught,
    cancellationPolicy,
    id,
    student,
    createdAt,
    receipt,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyPaymentRequest &&
        teamName == other.teamName &&
        payeeName == other.payeeName &&
        studentFirstName == other.studentFirstName &&
        amountCents == other.amountCents &&
        currency == other.currency &&
        reference == other.reference &&
        dueOn == other.dueOn &&
        listsEqual(lines, other.lines) &&
        status == other.status &&
        payerConfirmed == other.payerConfirmed &&
        paynowPayload == other.paynowPayload &&
        coTaught == other.coTaught &&
        cancellationPolicy == other.cancellationPolicy &&
        id == other.id &&
        student == other.student &&
        createdAt == other.createdAt &&
        receipt == other.receipt;
  }
}
