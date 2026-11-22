import 'payment.dart';

/// Where tutors receive PayNow (build plan, Phase 8).
///
/// Methods throw Failures. Both implementations keep the server's rules
/// (services/api/internal/billing): a tutor sets their own account and an
/// owner anyone's; a mobile number is +65 and eight digits starting 8 or
/// 9, a UEN nine or ten letters and digits; a changed number must be
/// checked again.
abstract interface class PayeeAccountRepository {
  /// [membershipId]'s account, or null when they have none yet.
  Future<PayeeAccount?> account(String teamId, String membershipId);

  /// Sets up or changes the account.
  Future<PayeeAccount> save(
    String teamId,
    String membershipId,
    PayeeAccountDraft draft,
  );

  /// Records that the test code showed the right name.
  Future<PayeeAccount> verify(String teamId, String membershipId);
}

/// Payment requests and receipts for a team's staff (ADR 024).
///
/// Owners see and manage every request; teachers only those where they
/// are the payee, and another payee's request is not found. Writes that
/// create something take an idempotency key, one per opened form: a
/// retry with the same key returns what the first try made.
abstract interface class PaymentRepository {
  /// Billable lessons no live request covers, oldest first: every payee's
  /// for owners, their own for teachers.
  Future<List<BillableLesson>> billableLessons(
    String teamId, {
    String? studentId,
    String? payeeId,
  });

  /// Requests, newest first.
  Future<List<PaymentRequestSummary>> requests(
    String teamId, {
    PaymentStatus? status,
  });

  /// One request.
  Future<PaymentRequest> request(String teamId, String requestId);

  /// Asks for payment. A payee who sends automatically sends it at once.
  Future<SentPaymentRequest> create(
    String teamId,
    PaymentRequestDraft draft, {
    required String idempotencyKey,
  });

  /// Sends a draft, or an open request again, with a fresh link.
  Future<SentPaymentRequest> send(String teamId, String requestId);

  /// Withdraws a request that is not paid; its lessons can be billed again.
  Future<PaymentRequest> cancel(String teamId, String requestId);

  /// The payee's record that the money arrived. The request is paid once
  /// the payer has said they paid too.
  Future<PaymentRequest> recordPayment(
    String teamId,
    String requestId,
    PaymentInput payment, {
    required String idempotencyKey,
  });

  /// Receipts, newest first.
  Future<List<ReceiptSummary>> receipts(String teamId);

  /// One receipt.
  Future<Receipt> receipt(String teamId, String receiptId);

  /// The receipt's PDF.
  Future<ReceiptPdf> receiptPdf(String teamId, String receiptId);

  /// Voids a wrong receipt. With [correction], a new receipt replaces it
  /// and the request stays paid; without, the request reopens for both
  /// sides to confirm again.
  Future<Receipt> voidReceipt(
    String teamId,
    String receiptId, {
    required String reason,
    PaymentInput? correction,
    required String idempotencyKey,
  });
}

/// The payer's page, opened from a link without signing in. An unknown,
/// expired or draft request's link is not found.
abstract interface class PublicPaymentRepository {
  /// What the page shows.
  Future<PublicPayment> page(String token);

  /// "I've paid": the payer's confirmation. Saying it twice is harmless;
  /// a withdrawn request is a ConflictFailure.
  Future<PublicPayment> confirmPaid(String token);
}
