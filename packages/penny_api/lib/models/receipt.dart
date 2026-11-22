import 'package:meta/meta.dart';
import 'package:penny_api/date.dart';
import 'package:penny_api/messages/receipt_request.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/member_ref.dart';
import 'package:penny_api/models/payment_method.dart';
import 'package:penny_api/models/payment_request_line.dart';
import 'package:penny_api/models/student_ref.dart';
import 'package:penny_api/models/voided.dart';

@immutable
class Receipt {
  const Receipt({
    required this.id,
    required this.number,
    required this.issuedAt,
    required this.amountCents,
    required this.currency,
    required this.paidOn,
    required this.method,
    required this.payee,
    required this.student,
    required this.request,
    required this.lines,
    required this.contentSha256,
    this.voided,
    this.replacesReceiptId,
    this.replacedByReceiptId,
  });

  /// Converts a `Map<String, dynamic>` to a [Receipt].
  factory Receipt.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Receipt',
      json,
      () => Receipt(
        id: json['id'] as String,
        number: json['number'] as String,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        amountCents: json['amountCents'] as int,
        currency: json['currency'] as String,
        paidOn: Date.fromJson(json['paidOn'] as String),
        method: PaymentMethod.fromJson(json['method'] as String),
        payee: MemberRef.fromJson(json['payee'] as Map<String, dynamic>),
        student: StudentRef.fromJson(json['student'] as Map<String, dynamic>),
        request: ReceiptRequest.fromJson(
          json['request'] as Map<String, dynamic>,
        ),
        lines: (json['lines'] as List)
            .map<PaymentRequestLine>(
              (e) => PaymentRequestLine.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        contentSha256: json['contentSha256'] as String,
        voided: Voided.maybeFromJson(json['voided'] as Map<String, dynamic>?),
        replacesReceiptId: json['replacesReceiptId'] as String?,
        replacedByReceiptId: json['replacedByReceiptId'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Receipt? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Receipt.fromJson(json);
  }

  final String id;

  /// Sequential and gapless within the team.
  /// Example: `'R-0042'`
  final String number;
  final DateTime issuedAt;
  final int amountCents;
  final String currency;
  final Date paidOn;
  final PaymentMethod method;

  /// A team member, as other records mention them.
  final MemberRef payee;
  final StudentRef student;
  final ReceiptRequest request;
  final List<PaymentRequestLine> lines;

  /// Hex SHA-256 of the receipt's PDF.
  final String contentSha256;
  final Voided? voided;
  final String? replacesReceiptId;
  final String? replacedByReceiptId;

  /// Converts a [Receipt] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'amountCents': amountCents,
      'currency': currency,
      'paidOn': paidOn.toJson(),
      'method': method.toJson(),
      'payee': payee.toJson(),
      'student': student.toJson(),
      'request': request.toJson(),
      'lines': lines.map((e) => e.toJson()).toList(),
      'contentSha256': contentSha256,
      'voided': ?voided?.toJson(),
      'replacesReceiptId': ?replacesReceiptId,
      'replacedByReceiptId': ?replacedByReceiptId,
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    number,
    issuedAt,
    amountCents,
    currency,
    paidOn,
    method,
    payee,
    student,
    request,
    listHash(lines),
    contentSha256,
    voided,
    replacesReceiptId,
    replacedByReceiptId,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receipt &&
        id == other.id &&
        number == other.number &&
        issuedAt == other.issuedAt &&
        amountCents == other.amountCents &&
        currency == other.currency &&
        paidOn == other.paidOn &&
        method == other.method &&
        payee == other.payee &&
        student == other.student &&
        request == other.request &&
        listsEqual(lines, other.lines) &&
        contentSha256 == other.contentSha256 &&
        voided == other.voided &&
        replacesReceiptId == other.replacesReceiptId &&
        replacedByReceiptId == other.replacedByReceiptId;
  }
}
