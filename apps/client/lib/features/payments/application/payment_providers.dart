import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/application/active_team.dart';
import '../../shared/application/file_saver_provider.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';

/// The PayNow account repository in use, set by the composition root.
final payeeAccountRepositoryProvider = Provider<PayeeAccountRepository>(
  (ref) => throw UnimplementedError(
    'payeeAccountRepositoryProvider is set by backendOverrides()',
  ),
);

/// The payment repository in use, set by the composition root.
final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => throw UnimplementedError(
    'paymentRepositoryProvider is set by backendOverrides()',
  ),
);

/// The public payment page's repository, set by the composition root.
final publicPaymentRepositoryProvider = Provider<PublicPaymentRepository>(
  (ref) => throw UnimplementedError(
    'publicPaymentRepositoryProvider is set by backendOverrides()',
  ),
);

String _teamOf(Ref ref) =>
    ref.watch(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

/// [membershipId]'s PayNow account in the active team, or null.
final payeeAccountProvider = FutureProvider.autoDispose
    .family<PayeeAccount?, String>(
      (ref, membershipId) => ref
          .watch(payeeAccountRepositoryProvider)
          .account(_teamOf(ref), membershipId),
      retry: (_, _) => null,
    );

/// Which billable lessons to list.
typedef BillableQuery = ({String? studentId, String? payeeId});

/// Billable lessons no live request covers.
final billableLessonsProvider = FutureProvider.autoDispose
    .family<List<BillableLesson>, BillableQuery>(
      (ref, q) => ref
          .watch(paymentRepositoryProvider)
          .billableLessons(
            _teamOf(ref),
            studentId: q.studentId,
            payeeId: q.payeeId,
          ),
      retry: (_, _) => null,
    );

/// The active team's requests, newest first.
final paymentRequestsProvider =
    FutureProvider.autoDispose<List<PaymentRequestSummary>>(
      (ref) => ref.watch(paymentRepositoryProvider).requests(_teamOf(ref)),
      retry: (_, _) => null,
    );

/// One request.
final paymentRequestProvider = FutureProvider.autoDispose
    .family<PaymentRequest, String>(
      (ref, id) =>
          ref.watch(paymentRepositoryProvider).request(_teamOf(ref), id),
      retry: (_, _) => null,
    );

/// The active team's receipts, newest first.
final receiptsProvider = FutureProvider.autoDispose<List<ReceiptSummary>>(
  (ref) => ref.watch(paymentRepositoryProvider).receipts(_teamOf(ref)),
  retry: (_, _) => null,
);

/// One receipt.
final receiptProvider = FutureProvider.autoDispose.family<Receipt, String>(
  (ref, id) => ref.watch(paymentRepositoryProvider).receipt(_teamOf(ref), id),
  retry: (_, _) => null,
);

/// The payer's page for a link's token.
final publicPaymentProvider = FutureProvider.autoDispose
    .family<PublicPayment, String>(
      (ref, token) => ref.watch(publicPaymentRepositoryProvider).page(token),
      retry: (_, _) => null,
    );

/// A fresh Idempotency-Key, one per opened form: a retry from the same
/// form repeats the same key, and the server does the change once.
String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// The payment use cases staff screens call. Every change reloads the
/// lists and details it touches.
final paymentActionsProvider = Provider<PaymentActions>(PaymentActions.new);

/// Changes to PayNow accounts, requests and receipts.
class PaymentActions {
  /// Creates the actions.
  PaymentActions(this._ref);

  final Ref _ref;

  String get _team =>
      _ref.read(activeTeamProvider)?.teamId ?? (throw StateError('no team'));

  PaymentRepository get _payments => _ref.read(paymentRepositoryProvider);

  PayeeAccountRepository get _accounts =>
      _ref.read(payeeAccountRepositoryProvider);

  /// Sets up or changes [membershipId]'s PayNow account.
  Future<PayeeAccount> saveAccount(String membershipId, PayeeAccountDraft d) =>
      _account(membershipId, _accounts.save(_team, membershipId, d));

  /// Records that the test code showed the right name.
  Future<PayeeAccount> verifyAccount(String membershipId) =>
      _account(membershipId, _accounts.verify(_team, membershipId));

  /// Asks for payment.
  Future<SentPaymentRequest> create(
    PaymentRequestDraft d, {
    required String idempotencyKey,
  }) => _changed(_payments.create(_team, d, idempotencyKey: idempotencyKey));

  /// Sends a draft, or sends an open request again.
  Future<SentPaymentRequest> send(String requestId) =>
      _changed(_payments.send(_team, requestId));

  /// Withdraws a request.
  Future<PaymentRequest> cancel(String requestId) =>
      _changed(_payments.cancel(_team, requestId));

  /// Records that the money arrived.
  Future<PaymentRequest> recordPayment(
    String requestId,
    PaymentInput p, {
    required String idempotencyKey,
  }) => _changed(
    _payments.recordPayment(
      _team,
      requestId,
      p,
      idempotencyKey: idempotencyKey,
    ),
  );

  /// Voids a receipt, with or without a correction.
  Future<Receipt> voidReceipt(
    String receiptId, {
    required String reason,
    PaymentInput? correction,
    required String idempotencyKey,
  }) => _changed(
    _payments.voidReceipt(
      _team,
      receiptId,
      reason: reason,
      correction: correction,
      idempotencyKey: idempotencyKey,
    ),
  );

  /// Downloads a receipt's PDF.
  Future<void> downloadReceipt(String receiptId) async {
    final pdf = await _payments.receiptPdf(_team, receiptId);
    await _ref
        .read(fileSaverProvider)
        .save(pdf.filename, 'application/pdf', pdf.bytes);
  }

  Future<PayeeAccount> _account(
    String membershipId,
    Future<PayeeAccount> change,
  ) async {
    final result = await change;
    _ref.invalidate(payeeAccountProvider(membershipId));
    return result;
  }

  Future<T> _changed<T>(Future<T> change) async {
    final result = await change;
    _ref
      ..invalidate(paymentRequestsProvider)
      ..invalidate(paymentRequestProvider)
      ..invalidate(billableLessonsProvider)
      ..invalidate(receiptsProvider)
      ..invalidate(receiptProvider);
    return result;
  }
}
