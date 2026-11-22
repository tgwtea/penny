/// Payments in Penny's words (build plan, Phase 8; ADR 024). Penny never
/// moves money: a payment request asks for it with a PayNow code, the
/// payee records that it arrived, the payer says they paid, and when both
/// have, the request is paid and a receipt issued.
///
/// Days (due, paid on) are team dates, held as UTC midnight.
library;

import 'package:flutter/foundation.dart';

import '../../lessons/domain/lesson.dart';
import 'paynow.dart';

/// Where a payment request stands.
enum PaymentStatus {
  /// Made but not sent yet.
  draft,

  /// Sent and not paid.
  open,

  /// Both sides confirmed; a receipt was issued.
  paid,

  /// Taken back before it was paid.
  cancelled,
}

/// Who an open request still waits for before it is paid (ADR 024).
enum WaitingFor {
  /// Neither the payee nor the payer has confirmed.
  both,

  /// The payer says they paid; the payee has not recorded it.
  payee,

  /// The payee recorded the money; the payer has not said they paid.
  payer,
}

/// How money arrived.
enum PaymentMethod {
  /// PayNow.
  paynow,

  /// A bank transfer.
  bankTransfer,

  /// Cash.
  cash,

  /// Anything else.
  other;

  /// The word shown.
  String get label => switch (this) {
    PaymentMethod.paynow => 'PayNow',
    PaymentMethod.bankTransfer => 'Bank transfer',
    PaymentMethod.cash => 'Cash',
    PaymentMethod.other => 'Other',
  };
}

/// Where a tutor receives PayNow.
@immutable
class PayeeAccount {
  /// Creates one.
  const PayeeAccount({
    required this.membershipId,
    required this.proxyType,
    required this.proxyValue,
    required this.displayName,
    required this.sendAutomatically,
    required this.verified,
    required this.testPayload,
    this.verifiedAt,
  });

  /// Whose account it is.
  final String membershipId;

  /// A mobile number or a UEN.
  final PayNowProxy proxyType;

  /// "+6591234567" or "201234567N".
  final String proxyValue;

  /// The name payers see, at most 25 characters.
  final String displayName;

  /// Whether new requests go out at once rather than wait as drafts.
  final bool sendAutomatically;

  /// Whether the tutor scanned the test code and saw their own name.
  final bool verified;

  /// When they did.
  final DateTime? verifiedAt;

  /// A PayNow code with no amount, for the tutor to scan themselves.
  final String testPayload;
}

/// What it takes to set up or change a PayNow account.
@immutable
class PayeeAccountDraft {
  /// Creates one.
  const PayeeAccountDraft({
    required this.proxyType,
    required this.proxyValue,
    required this.displayName,
    this.sendAutomatically = false,
  });

  /// A mobile number or a UEN.
  final PayNowProxy proxyType;

  /// As typed; spaces are dropped.
  final String proxyValue;

  /// The name payers see.
  final String displayName;

  /// Whether new requests go out at once.
  final bool sendAutomatically;
}

/// A lesson that can be billed and no live request covers yet: done, or a
/// no-show or late cancellation the lead's policy charges.
@immutable
class BillableLesson {
  /// Creates one.
  const BillableLesson({
    required this.lessonId,
    required this.startsAt,
    required this.status,
    required this.studentIds,
    required this.studentNames,
    required this.feeCents,
    required this.payeeId,
    required this.payeeName,
    this.title = '',
    this.currency = 'SGD',
    this.coTaught = false,
  });

  /// The lesson.
  final String lessonId;

  /// When it started.
  final DateTime startsAt;

  /// Done, a no-show, or cancelled late.
  final LessonStatus status;

  /// Who was in it.
  final List<String> studentIds;

  /// Their names, in the same order.
  final List<String> studentNames;

  /// Its fee in cents.
  final int feeCents;

  /// ISO 4217.
  final String currency;

  /// Its title, if any.
  final String title;

  /// The lead tutor, who bills it (ADR 018).
  final String payeeId;

  /// Their name.
  final String payeeName;

  /// Several tutors taught it; the split is arranged outside Penny.
  final bool coTaught;
}

/// One thing a request covers.
@immutable
class PaymentLine {
  /// Creates one.
  const PaymentLine({
    required this.description,
    required this.amountCents,
    this.lessonId,
  });

  /// "Guitar lesson, Thu 19 Nov".
  final String description;

  /// Its amount in cents.
  final int amountCents;

  /// The lesson it bills, if any.
  final String? lessonId;
}

/// A line that is not a lesson: a book, an exam fee.
@immutable
class ExtraLine {
  /// Creates one.
  const ExtraLine({required this.description, required this.amountCents});

  /// What it is, at most 200 characters.
  final String description;

  /// More than zero cents.
  final int amountCents;
}

/// The payee's record that money arrived.
@immutable
class PaymentRecord {
  /// Creates one.
  const PaymentRecord({
    required this.amountCents,
    required this.paidOn,
    required this.method,
    required this.recordedBy,
    required this.recordedAt,
  });

  /// What arrived.
  final int amountCents;

  /// The day it arrived.
  final DateTime paidOn;

  /// How.
  final PaymentMethod method;

  /// Who recorded it.
  final String recordedBy;

  /// When.
  final DateTime recordedAt;
}

/// What the payee records: what their bank shows.
@immutable
class PaymentInput {
  /// Creates one.
  const PaymentInput({
    required this.amountCents,
    required this.paidOn,
    this.method = PaymentMethod.paynow,
  });

  /// What arrived, in cents.
  final int amountCents;

  /// The day it arrived; not after today.
  final DateTime paidOn;

  /// How.
  final PaymentMethod method;
}

/// A request's receipt.
@immutable
class ReceiptRef {
  /// Creates one.
  const ReceiptRef({
    required this.id,
    required this.number,
    this.voided = false,
  });

  /// The receipt.
  final String id;

  /// "R-0042".
  final String number;

  /// Whether it was voided.
  final bool voided;
}

/// A payment request in a list.
@immutable
class PaymentRequestSummary {
  /// Creates one.
  const PaymentRequestSummary({
    required this.id,
    required this.reference,
    required this.studentId,
    required this.studentName,
    required this.payeeId,
    required this.payeeName,
    required this.amountCents,
    required this.dueOn,
    required this.status,
    required this.createdAt,
    this.currency = 'SGD',
    this.waitingFor,
    this.overdue = false,
  });

  /// The request.
  final String id;

  /// "PNY-7K3Q9X", which the payer quotes.
  final String reference;

  /// Whose lessons it bills.
  final String studentId;

  /// Their name.
  final String studentName;

  /// Who is paid.
  final String payeeId;

  /// Their name.
  final String payeeName;

  /// The total, in cents.
  final int amountCents;

  /// ISO 4217.
  final String currency;

  /// The day it is due.
  final DateTime dueOn;

  /// Draft, open, paid or withdrawn.
  final PaymentStatus status;

  /// Who an open request waits for.
  final WaitingFor? waitingFor;

  /// Open and past its due day.
  final bool overdue;

  /// When it was made.
  final DateTime createdAt;
}

/// One payment request with everything about it.
@immutable
class PaymentRequest extends PaymentRequestSummary {
  /// Creates one.
  const PaymentRequest({
    required super.id,
    required super.reference,
    required super.studentId,
    required super.studentName,
    required super.payeeId,
    required super.payeeName,
    required super.amountCents,
    required super.dueOn,
    required super.status,
    required super.createdAt,
    required this.lines,
    super.currency,
    super.waitingFor,
    super.overdue,
    this.coTaught = false,
    this.note = '',
    this.sentAt,
    this.payerConfirmedAt,
    this.payment,
    this.receipt,
  });

  /// What it covers.
  final List<PaymentLine> lines;

  /// A lesson here was taught by several tutors.
  final bool coTaught;

  /// A note for the payer.
  final String note;

  /// When it was first sent.
  final DateTime? sentAt;

  /// When the payer said they paid.
  final DateTime? payerConfirmedAt;

  /// The payee's record that the money arrived.
  final PaymentRecord? payment;

  /// Its receipt, once paid.
  final ReceiptRef? receipt;
}

/// What it takes to ask for payment.
@immutable
class PaymentRequestDraft {
  /// Creates one.
  const PaymentRequestDraft({
    required this.studentId,
    required this.payeeId,
    required this.dueOn,
    this.lessonIds = const [],
    this.extraLines = const [],
    this.note = '',
  });

  /// Whose lessons.
  final String studentId;

  /// Who is paid: the lead tutor of every lesson.
  final String payeeId;

  /// The day it is due; not in the past.
  final DateTime dueOn;

  /// Billable lessons it covers.
  final List<String> lessonIds;

  /// Other lines.
  final List<ExtraLine> extraLines;

  /// A note for the payer, at most 500 characters.
  final String note;
}

/// A request just made or sent, with its link when one was made: Penny
/// keeps only a hash of it, so it is shown once.
@immutable
class SentPaymentRequest {
  /// Creates one.
  const SentPaymentRequest({required this.request, this.link});

  /// The request.
  final PaymentRequest request;

  /// The payment page, for the caller to share.
  final String? link;
}

/// Who voided a receipt, when and why.
@immutable
class Voided {
  /// Creates one.
  const Voided({required this.at, required this.reason, required this.by});

  /// When.
  final DateTime at;

  /// Why.
  final String reason;

  /// Who.
  final String by;
}

/// A receipt in a list.
@immutable
class ReceiptSummary {
  /// Creates one.
  const ReceiptSummary({
    required this.id,
    required this.number,
    required this.issuedAt,
    required this.amountCents,
    required this.studentName,
    required this.payeeName,
    this.currency = 'SGD',
    this.voided = false,
  });

  /// The receipt.
  final String id;

  /// "R-0042", gapless within the team.
  final String number;

  /// When it was issued.
  final DateTime issuedAt;

  /// What was paid.
  final int amountCents;

  /// ISO 4217.
  final String currency;

  /// Whose lessons.
  final String studentName;

  /// Who was paid.
  final String payeeName;

  /// Whether it was voided.
  final bool voided;
}

/// An issued receipt and everything it traces back to.
@immutable
class Receipt extends ReceiptSummary {
  /// Creates one.
  const Receipt({
    required super.id,
    required super.number,
    required super.issuedAt,
    required super.amountCents,
    required super.studentName,
    required super.payeeName,
    required this.studentId,
    required this.payeeId,
    required this.paidOn,
    required this.method,
    required this.requestId,
    required this.reference,
    required this.lines,
    required this.contentSha256,
    super.currency,
    this.voidedBy,
    this.replacesReceiptId,
    this.replacedByReceiptId,
  }) : super(voided: voidedBy != null);

  /// Whose lessons.
  final String studentId;

  /// Who was paid.
  final String payeeId;

  /// The day the money arrived.
  final DateTime paidOn;

  /// How.
  final PaymentMethod method;

  /// The request it closes.
  final String requestId;

  /// That request's reference.
  final String reference;

  /// What it covers.
  final List<PaymentLine> lines;

  /// The SHA-256 of its PDF, to show a copy is unaltered.
  final String contentSha256;

  /// Who voided it, when and why.
  final Voided? voidedBy;

  /// The receipt this one corrects.
  final String? replacesReceiptId;

  /// The receipt that corrects this one.
  final String? replacedByReceiptId;
}

/// A receipt's PDF, as the team's copy.
@immutable
class ReceiptPdf {
  /// Creates one.
  const ReceiptPdf({required this.filename, required this.bytes});

  /// "Receipt R-0042.pdf".
  final String filename;

  /// The document.
  final Uint8List bytes;
}

/// What the payer's page shows: no more about the student than a first
/// name.
@immutable
class PublicPayment {
  /// Creates one.
  const PublicPayment({
    required this.teamName,
    required this.payeeName,
    required this.studentFirstName,
    required this.amountCents,
    required this.reference,
    required this.dueOn,
    required this.lines,
    required this.status,
    required this.payerConfirmed,
    this.currency = 'SGD',
    this.paynowPayload,
    this.coTaught = false,
    this.cancellationPolicy,
  });

  /// The team that asks.
  final String teamName;

  /// Who is paid, as PayNow shows them.
  final String payeeName;

  /// "Arjun".
  final String studentFirstName;

  /// The total, in cents.
  final int amountCents;

  /// ISO 4217.
  final String currency;

  /// The reference to quote.
  final String reference;

  /// The day it is due.
  final DateTime dueOn;

  /// What it covers.
  final List<PaymentLine> lines;

  /// Open, paid or withdrawn.
  final PaymentStatus status;

  /// Whether the payer said they paid.
  final bool payerConfirmed;

  /// The PayNow code's content, while open.
  final String? paynowPayload;

  /// A lesson here was shared by several tutors.
  final bool coTaught;

  /// The payee's cancellation policy, in their words.
  final String? cancellationPolicy;
}
