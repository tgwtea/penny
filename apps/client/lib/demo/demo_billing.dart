import 'dart:math';
import 'dart:typed_data';

import '../core/capability.dart';
import '../core/failure.dart';
import '../core/team_time.dart';
import '../features/family/domain/family.dart';
import '../features/lessons/domain/lesson.dart';
import '../features/payments/domain/payment.dart';
import '../features/payments/domain/payment_repository.dart';
import '../features/payments/domain/paynow.dart';
import 'demo_actor.dart';
import 'demo_receipt_pdf.dart';
import 'demo_repositories.dart';
import 'demo_schedule.dart';
import 'demo_store.dart';

/// The demo's PayNow accounts, payment requests, links, payments and
/// receipts, in memory, under the server's rules
/// (services/api/internal/billing; ADR 024).
class DemoBilling {
  /// PayNow accounts by membership ID.
  final accounts = <String, DemoPayeeAccount>{};

  /// Requests by ID.
  final requests = <String, DemoRequest>{};

  /// Live payment links: token to request ID.
  final links = <String, String>{};

  /// Receipts by ID.
  final receipts = <String, DemoReceipt>{};

  /// Each team's last receipt number.
  final _lastNumber = <String, int>{};

  /// Idempotency keys: "team user key" to what they made.
  final keys = <String, ({String operation, String id})>{};

  int _seq = 0;
  final _random = Random();

  /// A fresh ID.
  String nextId(String prefix) =>
      '019a8f00-0000-7000-9000-${'$prefix${++_seq}'.padLeft(12, '0')}';

  /// A fresh "PNY-" reference in Crockford base32.
  String newReference() {
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    return 'PNY-${List.generate(6, (_) => alphabet[_random.nextInt(32)]).join()}';
  }

  /// A fresh link token.
  String newToken() => List.generate(
    22,
    (_) =>
        'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'[_random
            .nextInt(56)],
  ).join();

  /// The next receipt number in [teamId]: gapless.
  int nextNumber(String teamId) =>
      _lastNumber[teamId] = (_lastNumber[teamId] ?? 0) + 1;

  /// Whether a live request covers [lessonId].
  bool isBilled(String lessonId) => requests.values.any(
    (r) =>
        r.status != PaymentStatus.cancelled &&
        r.lines.any((l) => l.lessonId == lessonId),
  );
}

/// A PayNow account in the demo.
class DemoPayeeAccount {
  /// Creates one.
  DemoPayeeAccount({
    required this.membershipId,
    required this.proxyType,
    required this.proxyValue,
    required this.displayName,
    this.sendAutomatically = false,
    this.verifiedAt,
  });

  /// Whose.
  final String membershipId;

  /// Mobile or UEN.
  PayNowProxy proxyType;

  /// The number or UEN.
  String proxyValue;

  /// The name payers see.
  String displayName;

  /// Sends new requests at once.
  bool sendAutomatically;

  /// When the test scan was confirmed.
  DateTime? verifiedAt;
}

/// A payment request in the demo.
class DemoRequest {
  /// Creates one.
  DemoRequest({
    required this.id,
    required this.teamId,
    required this.reference,
    required this.studentId,
    required this.payeeId,
    required this.dueOn,
    required this.lines,
    required this.createdAt,
    required this.createdBy,
    this.note = '',
    this.coTaught = false,
  });

  /// Its ID.
  final String id;

  /// The team.
  final String teamId;

  /// "PNY-7K3Q9X".
  final String reference;

  /// Whose lessons.
  final String studentId;

  /// Who is paid.
  final String payeeId;

  /// When it is due.
  final DateTime dueOn;

  /// What it covers.
  final List<PaymentLine> lines;

  /// A note for the payer.
  final String note;

  /// A lesson here was co-taught.
  final bool coTaught;

  /// When it was made.
  final DateTime createdAt;

  /// The user who made it.
  final String createdBy;

  /// Where it stands.
  PaymentStatus status = PaymentStatus.draft;

  /// When it was first sent.
  DateTime? sentAt;

  /// When the payer said they paid.
  DateTime? payerConfirmedAt;

  /// The live payment record.
  DemoPayment? payment;

  /// Its receipts, oldest first.
  final receiptIds = <String>[];

  /// The total, in cents.
  int get amountCents => lines.fold(0, (sum, l) => sum + l.amountCents);
}

/// The payee's record that money arrived.
class DemoPayment {
  /// Creates one.
  DemoPayment({
    required this.amountCents,
    required this.paidOn,
    required this.method,
    required this.recordedBy,
    required this.recordedAt,
  });

  /// What arrived.
  final int amountCents;

  /// When.
  final DateTime paidOn;

  /// How.
  final PaymentMethod method;

  /// Who recorded it, by name.
  final String recordedBy;

  /// When it was recorded.
  final DateTime recordedAt;
}

/// An issued receipt in the demo: a snapshot of what it says.
class DemoReceipt {
  /// Creates one.
  DemoReceipt({
    required this.id,
    required this.teamId,
    required this.number,
    required this.requestId,
    required this.issuedAt,
    required this.teamName,
    required this.payeeName,
    required this.studentName,
    required this.reference,
    required this.lines,
    required this.amountCents,
    required this.paidOn,
    required this.method,
    this.replacesId,
  });

  /// Its ID.
  final String id;

  /// The team.
  final String teamId;

  /// Its number, gapless within the team.
  final int number;

  /// The request it closes.
  final String requestId;

  /// When.
  final DateTime issuedAt;

  /// What it says.
  final String teamName;

  /// Who was paid.
  final String payeeName;

  /// Whose lessons.
  final String studentName;

  /// The request's reference.
  final String reference;

  /// What it covers.
  final List<PaymentLine> lines;

  /// What was paid.
  final int amountCents;

  /// When.
  final DateTime paidOn;

  /// How.
  final PaymentMethod method;

  /// The receipt it corrects.
  final String? replacesId;

  /// Who voided it.
  Voided? voided;

  /// "R-0042".
  String get label => 'R-${number.toString().padLeft(4, '0')}';
}

String _money(int cents) =>
    'S\$ ${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// Shared reads and rules for the demo's billing repositories.
mixin _DemoBillingRules {
  DemoSessionRepository get session;

  DemoStore get store => session.store;
  DemoBilling get billing => store.billing;
  DemoSchedule get schedule => store.schedule;

  TeamTime timeOf(String teamId) => TeamTime(store.team(teamId).timezone);

  DateTime today(String teamId) => timeOf(teamId).dateOf(store.now());

  /// authz.ManagePaymentsFor: owners for anyone, teachers for themselves;
  /// another payee's request is hidden from a teacher.
  void requireManageFor(DemoActor a, String payeeId) {
    if (a.can(Capability.managePayments)) return;
    if (a.can(Capability.manageOwnPayments) && a.membershipId == payeeId) {
      return;
    }
    if (a.can(Capability.manageOwnPayments)) {
      throw const NotFoundFailure('not your request');
    }
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the team owner can do this.',
    );
  }

  DemoRequest requestIn(String teamId, String id) {
    final r = billing.requests[id];
    if (r == null || r.teamId != teamId) {
      throw const NotFoundFailure('no such request');
    }
    return r;
  }

  String studentName(String id) => schedule.students[id]?.name ?? '';

  WaitingFor? waitingFor(DemoRequest r) {
    if (r.status != PaymentStatus.open) return null;
    final payee = r.payment != null;
    final payer = r.payerConfirmedAt != null;
    if (payee && payer) return null;
    if (payee) return WaitingFor.payer;
    if (payer) return WaitingFor.payee;
    return WaitingFor.both;
  }

  PaymentRequest requestOf(DemoRequest r) {
    final receipt = r.receiptIds.isEmpty
        ? null
        : billing.receipts[r.receiptIds.last];
    return PaymentRequest(
      id: r.id,
      reference: r.reference,
      studentId: r.studentId,
      studentName: studentName(r.studentId),
      payeeId: r.payeeId,
      payeeName: store.nameOf(r.payeeId),
      amountCents: r.amountCents,
      dueOn: r.dueOn,
      status: r.status,
      waitingFor: waitingFor(r),
      overdue:
          r.status == PaymentStatus.open && r.dueOn.isBefore(today(r.teamId)),
      createdAt: r.createdAt,
      lines: List.unmodifiable(r.lines),
      coTaught: r.coTaught,
      note: r.note,
      sentAt: r.sentAt,
      payerConfirmedAt: r.payerConfirmedAt,
      payment: switch (r.payment) {
        null => null,
        final p => PaymentRecord(
          amountCents: p.amountCents,
          paidOn: p.paidOn,
          method: p.method,
          recordedBy: p.recordedBy,
          recordedAt: p.recordedAt,
        ),
      },
      receipt: receipt == null
          ? null
          : ReceiptRef(
              id: receipt.id,
              number: receipt.label,
              voided: receipt.voided != null,
            ),
    );
  }

  /// Makes a link to [r] and returns its address.
  String link(DemoRequest r) {
    final token = billing.newToken();
    billing.links[token] = r.id;
    return 'https://app.penny.example/pay/$token';
  }

  /// Marks [r] paid and issues its receipt from its payment record, [at]
  /// now unless given.
  void close(DemoRequest r, {DemoReceipt? replaces, DateTime? at}) {
    final p = r.payment!;
    r.status = PaymentStatus.paid;
    final receipt = DemoReceipt(
      id: billing.nextId('r'),
      teamId: r.teamId,
      number: billing.nextNumber(r.teamId),
      requestId: r.id,
      issuedAt: at ?? store.now(),
      teamName: store.team(r.teamId).name,
      payeeName:
          billing.accounts[r.payeeId]?.displayName ?? store.nameOf(r.payeeId),
      studentName: studentName(r.studentId),
      reference: r.reference,
      lines: List.unmodifiable(r.lines),
      amountCents: p.amountCents,
      paidOn: p.paidOn,
      method: p.method,
      replacesId: replaces?.id,
    );
    billing.receipts[receipt.id] = receipt;
    r.receiptIds.add(receipt.id);
  }

  /// The payer says they paid; closes [r] if the payee has recorded it.
  void payerConfirms(DemoRequest r) {
    if (r.status == PaymentStatus.cancelled) {
      throw const ConflictFailure(
        'withdrawn',
        detail: 'This payment request was withdrawn.',
      );
    }
    if (r.status != PaymentStatus.open || r.payerConfirmedAt != null) return;
    r.payerConfirmedAt = store.now();
    if (r.payment != null) close(r);
  }

  /// What [r]'s payment page shows.
  PublicPayment publicPage(DemoRequest r) {
    final account = billing.accounts[r.payeeId];
    final policy = schedule.policyOf(r.payeeId);
    return PublicPayment(
      teamName: store.team(r.teamId).name,
      payeeName: account?.displayName ?? store.nameOf(r.payeeId),
      studentFirstName: studentName(r.studentId).split(' ').first,
      amountCents: r.amountCents,
      reference: r.reference,
      dueOn: r.dueOn,
      lines: [
        for (final l in r.lines)
          PaymentLine(description: l.description, amountCents: l.amountCents),
      ],
      status: r.status,
      payerConfirmed: r.payerConfirmedAt != null,
      coTaught: r.coTaught,
      cancellationPolicy: policy.summary.isEmpty ? null : policy.summary,
      paynowPayload: r.status == PaymentStatus.open && account != null
          ? PayNowPayload(
              type: account.proxyType,
              proxy: account.proxyValue,
              merchantName: account.displayName,
              amountCents: r.amountCents,
              expiry: r.dueOn.add(const Duration(days: 90)),
              reference: r.reference,
            ).encode()
          : null,
    );
  }

  Uint8List pdfOf(DemoReceipt r) => demoReceiptPdf([
    'Receipt ${r.label}',
    r.teamName,
    '',
    'Received from: ${r.studentName}\'s family',
    'Paid to: ${r.payeeName}',
    'Reference: ${r.reference}',
    'Paid on: ${r.paidOn.year}-${r.paidOn.month.toString().padLeft(2, '0')}-${r.paidOn.day.toString().padLeft(2, '0')} by ${r.method.label}',
    '',
    for (final l in r.lines) '${l.description}: ${_money(l.amountCents)}',
    '',
    'Total paid: ${_money(r.amountCents)}',
    if (r.replacesId != null)
      'Replaces ${billing.receipts[r.replacesId]!.label}, which was voided.',
    'Demo receipt: issued by Penny\'s demo, not a real payment.',
  ]);

  Receipt receiptOf(DemoReceipt r) {
    final req = billing.requests[r.requestId]!;
    final replacedBy = billing.receipts.values
        .where((x) => x.replacesId == r.id)
        .firstOrNull;
    return Receipt(
      id: r.id,
      number: r.label,
      issuedAt: r.issuedAt,
      amountCents: r.amountCents,
      studentId: req.studentId,
      studentName: r.studentName,
      payeeId: req.payeeId,
      payeeName: r.payeeName,
      paidOn: r.paidOn,
      method: r.method,
      requestId: r.requestId,
      reference: r.reference,
      lines: r.lines,
      contentSha256: sha256Hex(pdfOf(r)),
      voidedBy: r.voided,
      replacesReceiptId: r.replacesId,
      replacedByReceiptId: replacedBy?.id,
    );
  }

  /// Replays an idempotency key: what it made, or null if unused. The same
  /// key for another change is a conflict.
  String? replayed(DemoActor a, String teamId, String key, String op) {
    if (key.trim().length < 8 || key.trim().length > 100) {
      throw const ValidationFailure(
        'key',
        detail: 'Send an Idempotency-Key of 8 to 100 characters.',
      );
    }
    final used = billing.keys['$teamId ${a.userId} ${key.trim()}'];
    if (used == null) return null;
    if (used.operation != op) {
      throw const ConflictFailure(
        'key reused',
        detail:
            'This Idempotency-Key was used for something else. Use a new one.',
      );
    }
    return used.id;
  }

  void saveKey(DemoActor a, String teamId, String key, String op, String id) {
    billing.keys['$teamId ${a.userId} ${key.trim()}'] = (operation: op, id: id);
  }

  void validPayment(PaymentInput p, String teamId) {
    if (p.amountCents <= 0) {
      throw const ValidationFailure(
        'amount',
        detail: 'Enter the amount that arrived.',
      );
    }
    if (p.paidOn.isAfter(today(teamId))) {
      throw const ValidationFailure(
        'paid on',
        detail: 'The money cannot have arrived after today.',
      );
    }
  }
}

/// PayNow accounts in the demo.
class DemoPayeeAccountRepository
    with _DemoBillingRules
    implements PayeeAccountRepository {
  /// Creates the repository over [session]'s store.
  DemoPayeeAccountRepository(this.session);

  @override
  final DemoSessionRepository session;

  static final _mobile = RegExp(r'^\+65[89][0-9]{7}$');
  static final _uen = RegExp(r'^[0-9A-Z]{9,10}$');

  void _requireOwnOrOwner(DemoActor a, String membershipId) {
    if (a.can(Capability.managePayments)) return;
    if (a.can(Capability.manageOwnPayments) && a.membershipId == membershipId) {
      return;
    }
    throw const ForbiddenFailure(
      'forbidden',
      detail: 'Only the tutor or the team owner can change this account.',
    );
  }

  PayeeAccount _of(DemoPayeeAccount a) => PayeeAccount(
    membershipId: a.membershipId,
    proxyType: a.proxyType,
    proxyValue: a.proxyValue,
    displayName: a.displayName,
    sendAutomatically: a.sendAutomatically,
    verified: a.verifiedAt != null,
    verifiedAt: a.verifiedAt,
    testPayload: PayNowPayload(
      type: a.proxyType,
      proxy: a.proxyValue,
      merchantName: a.displayName,
      editable: true,
    ).encode(),
  );

  @override
  Future<PayeeAccount?> account(String teamId, String membershipId) async {
    _requireOwnOrOwner(DemoActor.of(session, teamId), membershipId);
    final a = billing.accounts[membershipId];
    return a == null ? null : _of(a);
  }

  @override
  Future<PayeeAccount> save(
    String teamId,
    String membershipId,
    PayeeAccountDraft d,
  ) async {
    final actor = DemoActor.of(session, teamId);
    _requireOwnOrOwner(actor, membershipId);
    final proxy = d.proxyValue.replaceAll(' ', '').trim().toUpperCase();
    final ok = switch (d.proxyType) {
      PayNowProxy.mobile => _mobile.hasMatch(proxy),
      PayNowProxy.uen => _uen.hasMatch(proxy),
    };
    if (!ok) {
      throw ValidationFailure(
        'proxy',
        detail: d.proxyType == PayNowProxy.mobile
            ? 'Enter the PayNow mobile number as +65 and 8 digits.'
            : 'Enter the UEN: 9 or 10 letters and digits.',
      );
    }
    final name = d.displayName.trim();
    if (name.isEmpty || name.length > 25) {
      throw const ValidationFailure(
        'name',
        detail: 'Give a name of up to 25 characters, as payers should see it.',
      );
    }
    final member = store.memberIn(teamId, membershipId);
    if (member == null) throw const NotFoundFailure('no such member');
    final existing = billing.accounts[membershipId];
    final changed =
        existing == null ||
        existing.proxyValue != proxy ||
        existing.proxyType != d.proxyType;
    final account =
        (existing ??
              DemoPayeeAccount(
                membershipId: membershipId,
                proxyType: d.proxyType,
                proxyValue: proxy,
                displayName: name,
              ))
          ..proxyType = d.proxyType
          ..proxyValue = proxy
          ..displayName = name
          ..sendAutomatically = d.sendAutomatically;
    if (changed) account.verifiedAt = null;
    billing.accounts[membershipId] = account;
    return _of(account);
  }

  @override
  Future<PayeeAccount> verify(String teamId, String membershipId) async {
    _requireOwnOrOwner(DemoActor.of(session, teamId), membershipId);
    final a = billing.accounts[membershipId];
    if (a == null) throw const NotFoundFailure('no account');
    a.verifiedAt = store.now();
    return _of(a);
  }
}

/// Payment requests and receipts in the demo.
class DemoPaymentRepository
    with _DemoBillingRules
    implements PaymentRepository {
  /// Creates the repository over [session]'s store.
  DemoPaymentRepository(this.session);

  @override
  final DemoSessionRepository session;

  DemoActor _staff(String teamId) {
    final a = DemoActor.of(session, teamId);
    if (!a.can(Capability.managePayments) &&
        !a.can(Capability.manageOwnPayments)) {
      throw const ForbiddenFailure(
        'forbidden',
        detail: 'Only the team owner can see payments.',
      );
    }
    return a;
  }

  bool _billable(DemoLesson l) =>
      l.billable &&
      (l.status == LessonStatus.completed ||
          l.status == LessonStatus.noShow ||
          l.status == LessonStatus.cancelled) &&
      !billing.isBilled(l.id);

  String _describe(DemoLesson l, String teamId) {
    final day = timeOf(teamId).wallClock(l.startsAt);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final what = l.title.isEmpty ? 'Lesson' : l.title;
    final suffix = switch (l.status) {
      LessonStatus.noShow => ' (missed)',
      LessonStatus.cancelled => ' (late cancellation)',
      _ => '',
    };
    return '$what, ${days[day.weekday - 1]} ${day.day} '
        '${months[day.month - 1]} ${day.year}$suffix';
  }

  @override
  Future<List<BillableLesson>> billableLessons(
    String teamId, {
    String? studentId,
    String? payeeId,
  }) async {
    final a = _staff(teamId);
    final payee = a.can(Capability.managePayments) ? payeeId : a.membershipId;
    final lessons =
        schedule
            .lessonsOf(teamId)
            .where(_billable)
            .where((l) => payee == null || l.leadId == payee)
            .where((l) => studentId == null || l.studentIds.contains(studentId))
            .toList()
          ..sort((x, y) => x.startsAt.compareTo(y.startsAt));
    return [
      for (final l in lessons.take(500))
        BillableLesson(
          lessonId: l.id,
          startsAt: l.startsAt,
          title: l.title,
          status: l.status,
          studentIds: [...l.studentIds],
          studentNames: [for (final s in l.studentIds) studentName(s)],
          feeCents: l.feeCents,
          payeeId: l.leadId,
          payeeName: store.nameOf(l.leadId),
          coTaught: l.tutors.length > 1,
        ),
    ];
  }

  @override
  Future<List<PaymentRequestSummary>> requests(
    String teamId, {
    PaymentStatus? status,
  }) async {
    final a = _staff(teamId);
    final mine = !a.can(Capability.managePayments);
    final list =
        billing.requests.values
            .where((r) => r.teamId == teamId)
            .where((r) => !mine || r.payeeId == a.membershipId)
            .where((r) => status == null || r.status == status)
            .toList()
          ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return [for (final r in list) requestOf(r)];
  }

  @override
  Future<PaymentRequest> request(String teamId, String requestId) async {
    final a = _staff(teamId);
    final r = requestIn(teamId, requestId);
    requireManageFor(a, r.payeeId);
    return requestOf(r);
  }

  DemoPayeeAccount _verifiedAccount(String payeeId) {
    final account = billing.accounts[payeeId];
    if (account == null || account.verifiedAt == null) {
      throw const ConflictFailure(
        'no account',
        detail: 'Set up and check the payee\'s PayNow account first.',
      );
    }
    return account;
  }

  @override
  Future<SentPaymentRequest> create(
    String teamId,
    PaymentRequestDraft d, {
    required String idempotencyKey,
  }) async {
    final a = _staff(teamId);
    final again = replayed(a, teamId, idempotencyKey, 'payment_request.create');
    if (again != null) {
      return SentPaymentRequest(request: requestOf(billing.requests[again]!));
    }
    if (d.note.trim().length > 500) {
      throw const ValidationFailure(
        'note',
        detail: 'Shorten the note to at most 500 characters.',
      );
    }
    for (final l in d.extraLines) {
      if (l.description.trim().isEmpty ||
          l.description.trim().length > 200 ||
          l.amountCents <= 0) {
        throw const ValidationFailure(
          'line',
          detail:
              'Each extra line needs a description of up to 200 characters '
              'and an amount.',
        );
      }
    }
    if (d.lessonIds.isEmpty && d.extraLines.isEmpty) {
      throw const ValidationFailure(
        'empty',
        detail: 'Add at least one lesson or line to the request.',
      );
    }
    requireManageFor(a, d.payeeId);
    final account = _verifiedAccount(d.payeeId);
    final student = schedule.students[d.studentId];
    if (student == null || student.teamId != teamId) {
      throw const ValidationFailure(
        'student',
        detail: 'The student is not in the team.',
      );
    }
    if (d.dueOn.isBefore(today(teamId))) {
      throw const ValidationFailure(
        'due',
        detail: 'The due day cannot be in the past.',
      );
    }
    final lines = <PaymentLine>[];
    var coTaught = false;
    for (final id in d.lessonIds) {
      final l = schedule.lessons[id];
      if (l == null || l.teamId != teamId) {
        throw const ValidationFailure(
          'lesson',
          detail:
              'Every lesson must be done, or a no-show or late cancellation '
              'the policy bills.',
        );
      }
      if (billing.isBilled(id)) {
        throw const ConflictFailure(
          'billed',
          detail: 'A lesson here is already on another payment request.',
        );
      }
      if (!_billable(l)) {
        throw const ValidationFailure(
          'lesson',
          detail:
              'Every lesson must be done, or a no-show or late cancellation '
              'the policy bills.',
        );
      }
      if (l.leadId != d.payeeId) {
        throw const ValidationFailure(
          'lead',
          detail:
              'The lead tutor bills each lesson: choose lessons the payee '
              'leads.',
        );
      }
      if (!l.studentIds.contains(d.studentId)) {
        throw const ValidationFailure(
          'student',
          detail: 'Every lesson must include the student.',
        );
      }
      if (l.feeCents <= 0) {
        throw const ValidationFailure(
          'fee',
          detail: 'A lesson here has no fee. Set its fee first.',
        );
      }
      coTaught = coTaught || l.tutors.length > 1;
      lines.add(
        PaymentLine(
          description: _describe(l, teamId),
          amountCents: l.feeCents,
          lessonId: l.id,
        ),
      );
    }
    for (final l in d.extraLines) {
      lines.add(
        PaymentLine(
          description: l.description.trim(),
          amountCents: l.amountCents,
        ),
      );
    }
    final r = DemoRequest(
      id: billing.nextId('q'),
      teamId: teamId,
      reference: billing.newReference(),
      studentId: d.studentId,
      payeeId: d.payeeId,
      dueOn: d.dueOn,
      lines: lines,
      note: d.note.trim(),
      coTaught: coTaught,
      createdAt: store.now(),
      createdBy: a.userId,
    );
    billing.requests[r.id] = r;
    saveKey(a, teamId, idempotencyKey, 'payment_request.create', r.id);
    String? sent;
    if (account.sendAutomatically) {
      r
        ..status = PaymentStatus.open
        ..sentAt = store.now();
      sent = link(r);
    }
    return SentPaymentRequest(request: requestOf(r), link: sent);
  }

  @override
  Future<SentPaymentRequest> send(String teamId, String requestId) async {
    final a = _staff(teamId);
    final r = requestIn(teamId, requestId);
    requireManageFor(a, r.payeeId);
    if (r.status != PaymentStatus.draft && r.status != PaymentStatus.open) {
      throw const ConflictFailure(
        'not sendable',
        detail: 'Only drafts and open requests can be sent.',
      );
    }
    _verifiedAccount(r.payeeId);
    if (r.status == PaymentStatus.draft) {
      r
        ..status = PaymentStatus.open
        ..sentAt = store.now();
    }
    return SentPaymentRequest(request: requestOf(r), link: link(r));
  }

  @override
  Future<PaymentRequest> cancel(String teamId, String requestId) async {
    final a = _staff(teamId);
    final r = requestIn(teamId, requestId);
    requireManageFor(a, r.payeeId);
    switch (r.status) {
      case PaymentStatus.paid:
        throw const ConflictFailure(
          'paid',
          detail: 'This request is paid. Void its receipt instead.',
        );
      case PaymentStatus.cancelled:
        throw const ConflictFailure(
          'withdrawn',
          detail: 'This request is already withdrawn.',
        );
      case PaymentStatus.draft || PaymentStatus.open:
        r.status = PaymentStatus.cancelled;
    }
    return requestOf(r);
  }

  @override
  Future<PaymentRequest> recordPayment(
    String teamId,
    String requestId,
    PaymentInput p, {
    required String idempotencyKey,
  }) async {
    final a = _staff(teamId);
    if (replayed(a, teamId, idempotencyKey, 'payment.record') != null) {
      return requestOf(requestIn(teamId, requestId));
    }
    final r = requestIn(teamId, requestId);
    requireManageFor(a, r.payeeId);
    if (r.status != PaymentStatus.open) {
      throw const ConflictFailure(
        'not open',
        detail: 'Only an open request can be paid. Send it first.',
      );
    }
    if (r.payment != null) {
      throw const ConflictFailure(
        'recorded',
        detail: 'The payment is already recorded.',
      );
    }
    validPayment(p, teamId);
    r.payment = DemoPayment(
      amountCents: p.amountCents,
      paidOn: p.paidOn,
      method: p.method,
      recordedBy: store.nameOf(a.membershipId),
      recordedAt: store.now(),
    );
    saveKey(a, teamId, idempotencyKey, 'payment.record', r.id);
    if (r.payerConfirmedAt != null) close(r);
    return requestOf(r);
  }

  @override
  Future<List<ReceiptSummary>> receipts(String teamId) async {
    final a = _staff(teamId);
    final mine = !a.can(Capability.managePayments);
    final list =
        billing.receipts.values
            .where((r) => r.teamId == teamId)
            .where(
              (r) =>
                  !mine ||
                  billing.requests[r.requestId]!.payeeId == a.membershipId,
            )
            .toList()
          ..sort((x, y) => y.number.compareTo(x.number));
    return [for (final r in list) receiptOf(r)];
  }

  DemoReceipt _receiptIn(String teamId, String id) {
    final r = billing.receipts[id];
    if (r == null || r.teamId != teamId) {
      throw const NotFoundFailure('no such receipt');
    }
    return r;
  }

  @override
  Future<Receipt> receipt(String teamId, String receiptId) async {
    final a = _staff(teamId);
    final r = _receiptIn(teamId, receiptId);
    requireManageFor(a, billing.requests[r.requestId]!.payeeId);
    return receiptOf(r);
  }

  @override
  Future<ReceiptPdf> receiptPdf(String teamId, String receiptId) async {
    final a = _staff(teamId);
    final r = _receiptIn(teamId, receiptId);
    requireManageFor(a, billing.requests[r.requestId]!.payeeId);
    return ReceiptPdf(filename: 'Receipt ${r.label}.pdf', bytes: pdfOf(r));
  }

  @override
  Future<Receipt> voidReceipt(
    String teamId,
    String receiptId, {
    required String reason,
    PaymentInput? correction,
    required String idempotencyKey,
  }) async {
    final a = _staff(teamId);
    if (reason.trim().isEmpty || reason.trim().length > 500) {
      throw const ValidationFailure(
        'reason',
        detail: 'Say why the receipt is wrong, in up to 500 characters.',
      );
    }
    if (replayed(a, teamId, idempotencyKey, 'receipt.void') != null) {
      return receiptOf(_receiptIn(teamId, receiptId));
    }
    final old = _receiptIn(teamId, receiptId);
    final r = billing.requests[old.requestId]!;
    requireManageFor(a, r.payeeId);
    if (old.voided != null) {
      throw const ConflictFailure(
        'void',
        detail: 'This receipt is already void.',
      );
    }
    if (correction != null) validPayment(correction, teamId);
    old.voided = Voided(
      at: store.now(),
      reason: reason.trim(),
      by: store.nameOf(a.membershipId),
    );
    r.payment = null;
    saveKey(a, teamId, idempotencyKey, 'receipt.void', old.id);
    if (correction == null) {
      r
        ..status = PaymentStatus.open
        ..payerConfirmedAt = null;
    } else {
      r.payment = DemoPayment(
        amountCents: correction.amountCents,
        paidOn: correction.paidOn,
        method: correction.method,
        recordedBy: store.nameOf(a.membershipId),
        recordedAt: store.now(),
      );
      close(r, replaces: old);
    }
    return receiptOf(old);
  }
}

/// The payer's page in the demo.
class DemoPublicPaymentRepository
    with _DemoBillingRules
    implements PublicPaymentRepository {
  /// Creates the repository over [session]'s store.
  DemoPublicPaymentRepository(this.session);

  @override
  final DemoSessionRepository session;

  DemoRequest _byToken(String token) {
    final id = billing.links[token];
    final r = id == null ? null : billing.requests[id];
    if (r == null || r.status == PaymentStatus.draft) {
      throw const NotFoundFailure('no such link');
    }
    return r;
  }

  @override
  Future<PublicPayment> page(String token) async => publicPage(_byToken(token));

  @override
  Future<PublicPayment> confirmPaid(String token) async {
    final r = _byToken(token);
    payerConfirms(r);
    return publicPage(r);
  }
}

/// Billing as a signed-in parent sees it (ADR 025), for the demo's family
/// repository: their children's open and paid requests, "I've paid" and
/// receipts. [studentIds] are the parent's linked students.
class DemoFamilyBilling with _DemoBillingRules {
  /// Creates the desk over [session]'s store.
  DemoFamilyBilling(this.session);

  @override
  final DemoSessionRepository session;

  /// Open and paid requests for [studentIds], newest first.
  List<FamilyPayment> payments(String teamId, Set<String> studentIds) {
    final rows =
        billing.requests.values
            .where(
              (r) =>
                  r.teamId == teamId &&
                  studentIds.contains(r.studentId) &&
                  (r.status == PaymentStatus.open ||
                      r.status == PaymentStatus.paid),
            )
            .toList()
          ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return [for (final r in rows) _payment(r)];
  }

  /// "I've paid" for one of [studentIds]' requests.
  FamilyPayment confirm(
    String teamId,
    String requestId,
    Set<String> studentIds,
  ) {
    final r = billing.requests[requestId];
    if (r == null ||
        r.teamId != teamId ||
        !studentIds.contains(r.studentId) ||
        r.status == PaymentStatus.draft) {
      throw const NotFoundFailure('no such request');
    }
    payerConfirms(r);
    return _payment(r);
  }

  /// Receipts for [studentIds], newest first.
  List<ReceiptSummary> receipts(String teamId, Set<String> studentIds) {
    final list =
        billing.receipts.values
            .where(
              (r) =>
                  r.teamId == teamId &&
                  studentIds.contains(billing.requests[r.requestId]!.studentId),
            )
            .toList()
          ..sort((x, y) => y.number.compareTo(x.number));
    return [for (final r in list) receiptOf(r)];
  }

  /// One of [studentIds]' receipts as a PDF.
  ReceiptPdf pdf(String teamId, String receiptId, Set<String> studentIds) {
    final r = billing.receipts[receiptId];
    if (r == null ||
        r.teamId != teamId ||
        !studentIds.contains(billing.requests[r.requestId]!.studentId)) {
      throw const NotFoundFailure('no such receipt');
    }
    return ReceiptPdf(filename: 'Receipt ${r.label}.pdf', bytes: pdfOf(r));
  }

  FamilyPayment _payment(DemoRequest r) {
    final last = r.receiptIds.isEmpty
        ? null
        : billing.receipts[r.receiptIds.last];
    return FamilyPayment(
      id: r.id,
      studentId: r.studentId,
      studentName: studentName(r.studentId),
      createdAt: r.createdAt,
      page: publicPage(r),
      receipt: last == null
          ? null
          : ReceiptRef(
              id: last.id,
              number: last.label,
              voided: last.voided != null,
            ),
    );
  }
}

/// Seeds the studio's payments so the Payments page has something to show:
/// accounts for Daniel and Mei Lin, and one request in each state. The
/// requests bill extra lines rather than lessons, so the week's lessons
/// stay billable for trying a request out.
void seedBilling(DemoStore store) {
  final billing = store.billing;
  final now = store.now();
  final teamId = DemoStore.studioId;
  final time = TeamTime(store.team(teamId).timezone);
  final today = time.dateOf(now);
  final owner = demoId('b1');
  final mei = demoId('b2');
  billing.accounts[owner] = DemoPayeeAccount(
    membershipId: owner,
    proxyType: PayNowProxy.mobile,
    proxyValue: '+6591234567',
    displayName: 'Daniel Koh',
    verifiedAt: now.subtract(const Duration(days: 40)),
  );
  billing.accounts[mei] = DemoPayeeAccount(
    membershipId: mei,
    proxyType: PayNowProxy.mobile,
    proxyValue: '+6598765432',
    displayName: 'Mei Lin Tan',
    verifiedAt: now.subtract(const Duration(days: 30)),
  );

  final students = store.schedule.studentsOf(teamId).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  List<DemoStudent> taughtBy(String id) => [
    for (final s in students)
      if (s.primaryTeacherId == id) s,
  ];
  final meis = taughtBy(mei);
  final owners = taughtBy(owner);
  if (meis.length < 3 || owners.isEmpty) return;

  DemoRequest request(
    DemoStudent student,
    String payee, {
    required int daysAgo,
    required int dueIn,
    required int lessons,
  }) {
    final r = DemoRequest(
      id: billing.nextId('q'),
      teamId: teamId,
      reference: billing.newReference(),
      studentId: student.id,
      payeeId: payee,
      dueOn: today.add(Duration(days: dueIn)),
      lines: [
        PaymentLine(
          description: 'Guitar lessons in October ($lessons)',
          amountCents: lessons * 6000,
        ),
      ],
      createdAt: now.subtract(Duration(days: daysAgo)),
      createdBy: demoId(payee == owner ? 'a1' : 'a2'),
    );
    billing.requests[r.id] = r;
    return r;
  }

  final open = request(meis[0], mei, daysAgo: 3, dueIn: 11, lessons: 4)
    ..status = PaymentStatus.open
    ..sentAt = now.subtract(const Duration(days: 3));
  billing.links['demo-open-request'] = open.id;

  final overdue = request(meis[1], mei, daysAgo: 20, dueIn: -6, lessons: 3)
    ..status = PaymentStatus.open
    ..sentAt = now.subtract(const Duration(days: 20));
  billing.links['demo-overdue-request'] = overdue.id;

  final paid = request(meis[2], mei, daysAgo: 30, dueIn: -16, lessons: 4)
    ..status = PaymentStatus.open
    ..sentAt = now.subtract(const Duration(days: 30))
    ..payerConfirmedAt = now.subtract(const Duration(days: 22))
    ..payment = DemoPayment(
      amountCents: 24000,
      paidOn: today.subtract(const Duration(days: 22)),
      method: PaymentMethod.paynow,
      recordedBy: 'Mei Lin Tan',
      recordedAt: now.subtract(const Duration(days: 21)),
    );
  _SeedCloser(store).close(paid, at: paid.payment!.recordedAt);

  request(owners[0], owner, daysAgo: 1, dueIn: 14, lessons: 2);
}

class _SeedCloser with _DemoBillingRules {
  _SeedCloser(this._store);

  final DemoStore _store;

  @override
  DemoSessionRepository get session => throw UnsupportedError('seeding');

  @override
  DemoStore get store => _store;
}
