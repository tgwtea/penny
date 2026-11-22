import 'package:penny_api/api.dart' as api;

import '../../../core/failure.dart';
import '../../../data/api_connection.dart';
import '../../../data/api_failures.dart';
import '../../lessons/domain/lesson.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import '../domain/paynow.dart';

/// PayNow accounts against the real API
/// (`/v1/workspaces/{id}/members/{id}/payee-account`).
class HttpPayeeAccountRepository implements PayeeAccountRepository {
  /// Creates a repository calling the API through [_api].
  HttpPayeeAccountRepository(this._api);

  final ApiConnection _api;

  @override
  Future<PayeeAccount?> account(String teamId, String membershipId) async {
    try {
      return await _api.call(
        (client) async => PaymentMapper.account(
          await api.PaymentsApi(client).getPayeeAccount(teamId, membershipId),
        ),
      );
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<PayeeAccount> save(
    String teamId,
    String membershipId,
    PayeeAccountDraft d,
  ) async {
    final input = buildRequest(
      () => api.PayeeAccountInput(
        proxyType: switch (d.proxyType) {
          PayNowProxy.mobile => api.ProxyType.mobile,
          PayNowProxy.uen => api.ProxyType.uen,
        },
        proxyValue: d.proxyValue.trim(),
        displayName: d.displayName.trim(),
        sendAutomatically: d.sendAutomatically,
      ),
      detail: 'Give a name of up to 25 characters, as payers should see it.',
    );
    return _api.call(
      (client) async => PaymentMapper.account(
        await api.PaymentsApi(
          client,
        ).setPayeeAccount(teamId, membershipId, input),
      ),
    );
  }

  @override
  Future<PayeeAccount> verify(String teamId, String membershipId) => _api.call(
    (client) async => PaymentMapper.account(
      await api.PaymentsApi(client).verifyPayeeAccount(teamId, membershipId),
    ),
  );
}

/// Payment requests and receipts against the real API.
class HttpPaymentRepository implements PaymentRepository {
  /// Creates a repository calling the API through [_api].
  HttpPaymentRepository(this._api);

  final ApiConnection _api;

  static const _pageSize = 500;

  @override
  Future<List<BillableLesson>> billableLessons(
    String teamId, {
    String? studentId,
    String? payeeId,
  }) => _api.call((client) async {
    final list = await api.PaymentsApi(
      client,
    ).listBillableLessons(teamId, studentId: studentId, payeeId: payeeId);
    return [for (final l in list.items) PaymentMapper.billable(l)];
  });

  @override
  Future<List<PaymentRequestSummary>> requests(
    String teamId, {
    PaymentStatus? status,
  }) => _api.call((client) async {
    final out = <PaymentRequestSummary>[];
    String? cursor;
    do {
      final page = await api.PaymentsApi(client).listPaymentRequests(
        teamId,
        status: status == null ? null : PaymentMapper.toStatus(status),
        cursor: cursor,
        limit: _pageSize,
      );
      out.addAll(page.items.map(PaymentMapper.summary));
      cursor = page.nextCursor;
    } while (cursor != null);
    return out;
  });

  @override
  Future<PaymentRequest> request(String teamId, String requestId) => _api.call(
    (client) async => PaymentMapper.request(
      await api.PaymentsApi(client).getPaymentRequest(teamId, requestId),
    ),
  );

  @override
  Future<SentPaymentRequest> create(
    String teamId,
    PaymentRequestDraft d, {
    required String idempotencyKey,
  }) async {
    final input = buildRequest(
      () => api.PaymentRequestInput(
        studentId: d.studentId,
        payeeId: d.payeeId,
        dueOn: api.Date(d.dueOn.year, d.dueOn.month, d.dueOn.day),
        lessonIds: d.lessonIds.isEmpty ? null : d.lessonIds,
        extraLines: d.extraLines.isEmpty
            ? null
            : [
                for (final l in d.extraLines)
                  api.ExtraLine(
                    description: l.description.trim(),
                    amountCents: l.amountCents,
                  ),
              ],
        note: d.note.trim().isEmpty ? null : d.note.trim(),
      ),
      detail: 'Check the lines and the note, then try again.',
    );
    return _api.call(
      (client) async => PaymentMapper.sent(
        await api.PaymentsApi(
          client,
        ).createPaymentRequest(teamId, idempotencyKey, input),
      ),
    );
  }

  @override
  Future<SentPaymentRequest> send(String teamId, String requestId) => _api.call(
    (client) async => PaymentMapper.sent(
      await api.PaymentsApi(client).sendPaymentRequest(teamId, requestId),
    ),
  );

  @override
  Future<PaymentRequest> cancel(String teamId, String requestId) => _api.call(
    (client) async => PaymentMapper.request(
      await api.PaymentsApi(client).cancelPaymentRequest(teamId, requestId),
    ),
  );

  @override
  Future<PaymentRequest> recordPayment(
    String teamId,
    String requestId,
    PaymentInput p, {
    required String idempotencyKey,
  }) => _api.call(
    (client) async => PaymentMapper.request(
      await api.PaymentsApi(client).recordPayment(
        teamId,
        requestId,
        idempotencyKey,
        PaymentMapper.input(p),
      ),
    ),
  );

  @override
  Future<List<ReceiptSummary>> receipts(String teamId) =>
      _api.call((client) async {
        final out = <ReceiptSummary>[];
        String? cursor;
        do {
          final page = await api.PaymentsApi(
            client,
          ).listReceipts(teamId, cursor: cursor, limit: _pageSize);
          out.addAll(page.items.map(PaymentMapper.receiptSummary));
          cursor = page.nextCursor;
        } while (cursor != null);
        return out;
      });

  @override
  Future<Receipt> receipt(String teamId, String receiptId) => _api.call(
    (client) async => PaymentMapper.receipt(
      await api.PaymentsApi(client).getReceipt(teamId, receiptId),
    ),
  );

  @override
  Future<ReceiptPdf> receiptPdf(String teamId, String receiptId) =>
      _api.call((client) async {
        final payments = api.PaymentsApi(client);
        final r = await payments.getReceipt(teamId, receiptId);
        final bytes = await payments.getReceiptPdf(teamId, receiptId);
        return ReceiptPdf(filename: 'Receipt ${r.number}.pdf', bytes: bytes);
      });

  @override
  Future<Receipt> voidReceipt(
    String teamId,
    String receiptId, {
    required String reason,
    PaymentInput? correction,
    required String idempotencyKey,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ValidationFailure(
        'reason',
        detail: 'Say why the receipt is wrong.',
      );
    }
    final input = buildRequest(
      () => api.VoidReceiptInput(
        reason: reason.trim(),
        correction: correction == null ? null : PaymentMapper.input(correction),
      ),
      detail: 'Say why the receipt is wrong, in up to 500 characters.',
    );
    return _api.call(
      (client) async => PaymentMapper.receipt(
        await api.PaymentsApi(
          client,
        ).voidReceipt(teamId, receiptId, idempotencyKey, input),
      ),
    );
  }
}

/// The payer's page against the real API (`/v1/pay/{token}`). Public: no
/// one signs in.
class HttpPublicPaymentRepository implements PublicPaymentRepository {
  /// Creates a repository calling the API through [_api].
  HttpPublicPaymentRepository(this._api);

  final ApiConnection _api;

  @override
  Future<PublicPayment> page(String token) => _api.call(
    (client) async => PaymentMapper.public(
      await api.PaymentsApi(client).getPublicPaymentRequest(token),
    ),
  );

  @override
  Future<PublicPayment> confirmPaid(String token) => _api.call(
    (client) async => PaymentMapper.public(
      await api.PaymentsApi(client).confirmPaidByPayer(token),
    ),
  );
}

/// Between the contract's payment types and the domain's.
abstract final class PaymentMapper {
  static DateTime _day(api.Date d) => DateTime.utc(d.year, d.month, d.day);

  /// A PayNow account.
  static PayeeAccount account(api.PayeeAccount a) => PayeeAccount(
    membershipId: a.membershipId,
    proxyType: switch (a.proxyType) {
      api.ProxyType.mobile => PayNowProxy.mobile,
      api.ProxyType.uen => PayNowProxy.uen,
    },
    proxyValue: a.proxyValue,
    displayName: a.displayName,
    sendAutomatically: a.sendAutomatically,
    verified: a.verified,
    verifiedAt: a.verifiedAt?.toUtc(),
    testPayload: a.testPayload,
  );

  /// A billable lesson.
  static BillableLesson billable(api.BillableLesson l) => BillableLesson(
    lessonId: l.lessonId,
    startsAt: l.startsAt.toUtc(),
    title: l.title ?? '',
    status: switch (l.status) {
      api.LessonStatus.scheduled => LessonStatus.scheduled,
      api.LessonStatus.completed => LessonStatus.completed,
      api.LessonStatus.cancelled => LessonStatus.cancelled,
      api.LessonStatus.noShow => LessonStatus.noShow,
    },
    studentIds: [for (final s in l.students) s.studentId],
    studentNames: [for (final s in l.students) s.name],
    feeCents: l.feeCents,
    currency: l.currency,
    payeeId: l.payee.membershipId,
    payeeName: l.payee.displayName,
    coTaught: l.coTaught ?? false,
  );

  /// A status for a query.
  static api.PaymentRequestStatus toStatus(PaymentStatus s) => switch (s) {
    PaymentStatus.draft => api.PaymentRequestStatus.draft,
    PaymentStatus.open => api.PaymentRequestStatus.open,
    PaymentStatus.paid => api.PaymentRequestStatus.paid,
    PaymentStatus.cancelled => api.PaymentRequestStatus.cancelled,
  };

  static PaymentStatus _status(api.PaymentRequestStatus s) => switch (s) {
    api.PaymentRequestStatus.draft => PaymentStatus.draft,
    api.PaymentRequestStatus.open => PaymentStatus.open,
    api.PaymentRequestStatus.paid => PaymentStatus.paid,
    api.PaymentRequestStatus.cancelled => PaymentStatus.cancelled,
  };

  static WaitingFor? _waiting(api.WaitingFor? w) => switch (w) {
    null => null,
    api.WaitingFor.both => WaitingFor.both,
    api.WaitingFor.payee => WaitingFor.payee,
    api.WaitingFor.payer => WaitingFor.payer,
  };

  static PaymentMethod _method(api.PaymentMethod m) => switch (m) {
    api.PaymentMethod.paynow => PaymentMethod.paynow,
    api.PaymentMethod.bankTransfer => PaymentMethod.bankTransfer,
    api.PaymentMethod.cash => PaymentMethod.cash,
    api.PaymentMethod.other => PaymentMethod.other,
  };

  /// A payment for the API.
  static api.PaymentInput input(PaymentInput p) => api.PaymentInput(
    amountCents: p.amountCents,
    paidOn: api.Date(p.paidOn.year, p.paidOn.month, p.paidOn.day),
    method: switch (p.method) {
      PaymentMethod.paynow => api.PaymentMethod.paynow,
      PaymentMethod.bankTransfer => api.PaymentMethod.bankTransfer,
      PaymentMethod.cash => api.PaymentMethod.cash,
      PaymentMethod.other => api.PaymentMethod.other,
    },
  );

  /// A request in a list.
  static PaymentRequestSummary summary(api.PaymentRequestSummary r) =>
      PaymentRequestSummary(
        id: r.id,
        reference: r.reference,
        studentId: r.student.id,
        studentName: r.student.name,
        payeeId: r.payee.membershipId,
        payeeName: r.payee.displayName,
        amountCents: r.amountCents,
        currency: r.currency,
        dueOn: _day(r.dueOn),
        status: _status(r.status),
        waitingFor: _waiting(r.waitingFor),
        overdue: r.overdue,
        createdAt: r.createdAt.toUtc(),
      );

  /// One request.
  static PaymentRequest request(api.PaymentRequest r) => PaymentRequest(
    id: r.id,
    reference: r.reference,
    studentId: r.student.id,
    studentName: r.student.name,
    payeeId: r.payee.membershipId,
    payeeName: r.payee.displayName,
    amountCents: r.amountCents,
    currency: r.currency,
    dueOn: _day(r.dueOn),
    status: _status(r.status),
    waitingFor: _waiting(r.waitingFor),
    overdue: r.overdue,
    createdAt: r.createdAt.toUtc(),
    lines: [for (final l in r.lines) _line(l)],
    coTaught: r.coTaught,
    note: r.note ?? '',
    sentAt: r.sentAt?.toUtc(),
    payerConfirmedAt: r.payerConfirmedAt?.toUtc(),
    payment: switch (r.payment) {
      null => null,
      final p => PaymentRecord(
        amountCents: p.amountCents,
        paidOn: _day(p.paidOn),
        method: _method(p.method),
        recordedBy: p.recordedBy,
        recordedAt: p.recordedAt.toUtc(),
      ),
    },
    receipt: switch (r.receipt) {
      null => null,
      final rc => ReceiptRef(id: rc.id, number: rc.number, voided: rc.voided),
    },
  );

  static PaymentLine _line(api.PaymentRequestLine l) => PaymentLine(
    description: l.description,
    amountCents: l.amountCents,
    lessonId: l.lessonId,
  );

  /// A request with its link.
  static SentPaymentRequest sent(api.PaymentRequestWithLink r) =>
      SentPaymentRequest(request: request(r.request), link: r.link);

  /// A receipt in a list.
  static ReceiptSummary receiptSummary(api.ReceiptSummary r) => ReceiptSummary(
    id: r.id,
    number: r.number,
    issuedAt: r.issuedAt.toUtc(),
    amountCents: r.amountCents,
    currency: r.currency,
    studentName: r.student.name,
    payeeName: r.payee.displayName,
    voided: r.voided,
  );

  /// One receipt.
  static Receipt receipt(api.Receipt r) => Receipt(
    id: r.id,
    number: r.number,
    issuedAt: r.issuedAt.toUtc(),
    amountCents: r.amountCents,
    currency: r.currency,
    studentId: r.student.id,
    studentName: r.student.name,
    payeeId: r.payee.membershipId,
    payeeName: r.payee.displayName,
    paidOn: _day(r.paidOn),
    method: _method(r.method),
    requestId: r.request.id,
    reference: r.request.reference,
    lines: [for (final l in r.lines) _line(l)],
    contentSha256: r.contentSha256,
    voidedBy: switch (r.voided) {
      null => null,
      final v => Voided(at: v.at.toUtc(), reason: v.reason, by: v.by),
    },
    replacesReceiptId: r.replacesReceiptId,
    replacedByReceiptId: r.replacedByReceiptId,
  );

  /// The payer's page.
  static PublicPayment public(api.PublicPaymentRequest p) => PublicPayment(
    teamName: p.teamName,
    payeeName: p.payeeName,
    studentFirstName: p.studentFirstName,
    amountCents: p.amountCents,
    currency: p.currency,
    reference: p.reference,
    dueOn: _day(p.dueOn),
    lines: [
      for (final l in p.lines)
        PaymentLine(description: l.description, amountCents: l.amountCents),
    ],
    status: _status(p.status),
    payerConfirmed: p.payerConfirmed,
    paynowPayload: p.paynowPayload,
    coTaught: p.coTaught,
    cancellationPolicy: p.cancellationPolicy,
  );
}
