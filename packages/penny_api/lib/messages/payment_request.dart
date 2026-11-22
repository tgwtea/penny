import 'package:meta/meta.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/member_ref.dart';
import 'package:penny_api/models/payment_record.dart';
import 'package:penny_api/models/payment_request_line.dart';
import 'package:penny_api/models/payment_request_status.dart';
import 'package:penny_api/models/receipt_ref.dart';
import 'package:penny_api/models/student_ref.dart';
import 'package:penny_api/models/waiting_for.dart';

@immutable
class PaymentRequest {
  const PaymentRequest({
    required this.id,
    required this.reference,
    required this.student,
    required this.payee,
    required this.amountCents,
    required this.currency,
    required this.dueOn,
    required this.status,
    required this.overdue,
    required this.createdAt,
    required this.lines,
    required this.coTaught,
    this.waitingFor,
    this.note,
    this.sentAt,
    this.payerConfirmedAt,
    this.payment,
    this.receipt,
  });

  /// Converts a `Map<String, dynamic>` to a [PaymentRequest].
  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'PaymentRequest',
      json,
      () => PaymentRequest(
        id: json['id'] as String,
        reference: json['reference'] as String,
        student: StudentRef.fromJson(json['student'] as Map<String, dynamic>),
        payee: MemberRef.fromJson(json['payee'] as Map<String, dynamic>),
        amountCents: json['amountCents'] as int,
        currency: json['currency'] as String,
        dueOn: Date.fromJson(json['dueOn'] as String),
        status: PaymentRequestStatus.fromJson(json['status'] as String),
        waitingFor: WaitingFor.maybeFromJson(json['waitingFor'] as String?),
        overdue: json['overdue'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lines: (json['lines'] as List)
            .map<PaymentRequestLine>(
              (e) => PaymentRequestLine.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        note: json['note'] as String?,
        sentAt: maybeParseDateTime(json['sentAt'] as String?),
        payerConfirmedAt: maybeParseDateTime(
          json['payerConfirmedAt'] as String?,
        ),
        payment: PaymentRecord.maybeFromJson(
          json['payment'] as Map<String, dynamic>?,
        ),
        receipt: ReceiptRef.maybeFromJson(
          json['receipt'] as Map<String, dynamic>?,
        ),
        coTaught: json['coTaught'] as bool,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static PaymentRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return PaymentRequest.fromJson(json);
  }

  final String id;

  /// Example: `'PNY-7K3Q9X'`
  final String reference;
  final StudentRef student;

  /// A team member, as other records mention them.
  final MemberRef payee;
  final int amountCents;
  final String currency;
  final Date dueOn;
  final PaymentRequestStatus status;

  /// Who still has to confirm before an open request is paid.
  final WaitingFor? waitingFor;

  /// Open and past its due day in the team's timezone.
  final bool overdue;
  final DateTime createdAt;
  final List<PaymentRequestLine> lines;
  final String? note;
  final DateTime? sentAt;
  final DateTime? payerConfirmedAt;
  final PaymentRecord? payment;
  final ReceiptRef? receipt;

  /// A line is a lesson several tutors taught; the payee bills it whole (ADR
  /// 018).
  final bool coTaught;

  /// Converts a [PaymentRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'student': student.toJson(),
      'payee': payee.toJson(),
      'amountCents': amountCents,
      'currency': currency,
      'dueOn': dueOn.toJson(),
      'status': status.toJson(),
      'waitingFor': ?waitingFor?.toJson(),
      'overdue': overdue,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lines': lines.map((e) => e.toJson()).toList(),
      'note': ?note,
      'sentAt': ?sentAt?.toUtc().toIso8601String(),
      'payerConfirmedAt': ?payerConfirmedAt?.toUtc().toIso8601String(),
      'payment': ?payment?.toJson(),
      'receipt': ?receipt?.toJson(),
      'coTaught': coTaught,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    reference,
    student,
    payee,
    amountCents,
    currency,
    dueOn,
    status,
    waitingFor,
    overdue,
    createdAt,
    listHash(lines),
    note,
    sentAt,
    payerConfirmedAt,
    payment,
    receipt,
    coTaught,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentRequest &&
        id == other.id &&
        reference == other.reference &&
        student == other.student &&
        payee == other.payee &&
        amountCents == other.amountCents &&
        currency == other.currency &&
        dueOn == other.dueOn &&
        status == other.status &&
        waitingFor == other.waitingFor &&
        overdue == other.overdue &&
        createdAt == other.createdAt &&
        listsEqual(lines, other.lines) &&
        note == other.note &&
        sentAt == other.sentAt &&
        payerConfirmedAt == other.payerConfirmedAt &&
        payment == other.payment &&
        receipt == other.receipt &&
        coTaught == other.coTaught;
  }
}
