import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/lessons/domain/lesson.dart';
import 'package:penny/features/lessons/domain/lesson_repository.dart';
import 'package:penny/features/payments/domain/payment.dart';
import 'package:penny/features/payments/domain/payment_repository.dart';
import 'package:penny/features/payments/domain/paynow.dart';
import 'package:penny/features/students/domain/student.dart';
import 'package:penny/features/students/domain/student_repository.dart';

/// Repositories signed in as a team's owner, who teaches, and another
/// member of the team with no PayNow account.
typedef PaymentFixture = ({
  PayeeAccountRepository accounts,
  PaymentRepository payments,
  PublicPaymentRepository public,
  LessonRepository lessons,
  StudentRepository students,
  String teamId,
  String payeeId,
  String otherMemberId,
});

/// The behaviour every payment repository keeps (build plan, Phase 8;
/// ADR 024). The rules are the server's: services/api/internal/billing.
void paymentRepositoryContract(
  String implementation,
  Future<PaymentFixture> Function() create,
) {
  final due = DateTime.utc(2030, 1, 31);
  var keys = 0;
  String key() => 'contract-key-${++keys}';

  /// The owner's checked PayNow account, a student and a done lesson the
  /// owner led, with a fee of S$ 60.
  Future<({String studentId, String lessonId})> billable(
    PaymentFixture f,
  ) async {
    await f.accounts.save(
      f.teamId,
      f.payeeId,
      const PayeeAccountDraft(
        proxyType: PayNowProxy.mobile,
        proxyValue: '+65 9123 4567',
        displayName: 'Daniel Koh',
      ),
    );
    await f.accounts.verify(f.teamId, f.payeeId);
    final student = await f.students.create(
      f.teamId,
      const StudentDraft(name: 'Zara Lim'),
    );
    final start = DateTime.now().toUtc().subtract(const Duration(days: 2));
    final lesson = await f.lessons.create(
      f.teamId,
      LessonDraft(
        startsAt: start,
        endsAt: start.add(const Duration(minutes: 45)),
        tutors: [(membershipId: f.payeeId, role: TutorRole.lead)],
        studentIds: [student.id],
        feeCents: 6000,
        title: 'Guitar',
      ),
    );
    await f.lessons.complete(f.teamId, lesson);
    return (studentId: student.id, lessonId: lesson.id);
  }

  Future<SentPaymentRequest> request(
    PaymentFixture f,
    ({String studentId, String lessonId}) b,
  ) => f.payments.create(
    f.teamId,
    PaymentRequestDraft(
      studentId: b.studentId,
      payeeId: f.payeeId,
      dueOn: due,
      lessonIds: [b.lessonId],
      extraLines: const [
        ExtraLine(description: 'Grade 5 theory book', amountCents: 1890),
      ],
    ),
    idempotencyKey: key(),
  );

  String token(String link) => Uri.parse(link).pathSegments.last;

  group('$implementation honours the payment contracts', () {
    test('a member without PayNow has no account', () async {
      final f = await create();
      expect(await f.accounts.account(f.teamId, f.otherMemberId), isNull);
    });

    test('an account is checked once, and again after a new number', () async {
      final f = await create();
      final saved = await f.accounts.save(
        f.teamId,
        f.payeeId,
        const PayeeAccountDraft(
          proxyType: PayNowProxy.mobile,
          proxyValue: '+65 8123 4567',
          displayName: 'Daniel Koh',
        ),
      );
      expect(saved.proxyValue, '+6581234567');
      expect(saved.verified, isFalse);
      expect(saved.testPayload, startsWith('000201'));
      expect((await f.accounts.verify(f.teamId, f.payeeId)).verified, isTrue);
      final moved = await f.accounts.save(
        f.teamId,
        f.payeeId,
        const PayeeAccountDraft(
          proxyType: PayNowProxy.mobile,
          proxyValue: '+6598765432',
          displayName: 'Daniel Koh',
        ),
      );
      expect(moved.verified, isFalse);
      await expectLater(
        f.accounts.save(
          f.teamId,
          f.payeeId,
          const PayeeAccountDraft(
            proxyType: PayNowProxy.mobile,
            proxyValue: '91234567',
            displayName: 'Daniel Koh',
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('a request is paid once both sides confirm, with a receipt', () async {
      final f = await create();
      final b = await billable(f);
      expect(
        (await f.payments.billableLessons(
          f.teamId,
          studentId: b.studentId,
        )).map((l) => l.lessonId),
        contains(b.lessonId),
      );
      final made = await request(f, b);
      expect(made.link, isNull);
      expect(made.request.status, PaymentStatus.draft);
      expect(made.request.amountCents, 6000 + 1890);
      expect(made.request.reference, matches(RegExp(r'^PNY-[0-9A-Z]{6}$')));
      expect(
        (await f.payments.billableLessons(
          f.teamId,
          studentId: b.studentId,
        )).map((l) => l.lessonId),
        isNot(contains(b.lessonId)),
      );

      final sent = await f.payments.send(f.teamId, made.request.id);
      expect(sent.request.status, PaymentStatus.open);
      expect(sent.request.waitingFor, WaitingFor.both);
      final page = await f.public.page(token(sent.link!));
      expect(page.amountCents, 7890);
      expect(page.studentFirstName, 'Zara');
      expect(page.paynowPayload, contains(made.request.reference));

      final recorded = await f.payments.recordPayment(
        f.teamId,
        made.request.id,
        PaymentInput(amountCents: 7890, paidOn: DateTime.utc(2026, 11, 19)),
        idempotencyKey: key(),
      );
      expect(recorded.status, PaymentStatus.open);
      expect(recorded.waitingFor, WaitingFor.payer);
      expect(recorded.payment?.amountCents, 7890);

      final paid = await f.public.confirmPaid(token(sent.link!));
      expect(paid.status, PaymentStatus.paid);
      expect(paid.payerConfirmed, isTrue);
      expect(paid.paynowPayload, isNull);

      final closed = await f.payments.request(f.teamId, made.request.id);
      final number = closed.receipt!.number;
      expect(number, matches(RegExp(r'^R-[0-9]{4}$')));
      final receipts = await f.payments.receipts(f.teamId);
      expect(receipts.first.number, number, reason: 'newest first');
      final pdf = await f.payments.receiptPdf(f.teamId, closed.receipt!.id);
      expect(String.fromCharCodes(pdf.bytes.take(4)), '%PDF');
      expect(pdf.filename, 'Receipt $number.pdf');
    });

    test('the payer may confirm first, and twice is harmless', () async {
      final f = await create();
      final made = await request(f, await billable(f));
      final sent = await f.payments.send(f.teamId, made.request.id);
      await f.public.confirmPaid(token(sent.link!));
      final again = await f.public.confirmPaid(token(sent.link!));
      expect(again.status, PaymentStatus.open);
      final waiting = await f.payments.request(f.teamId, made.request.id);
      expect(waiting.waitingFor, WaitingFor.payee);
    });

    test('creating with the same key twice makes one request', () async {
      final f = await create();
      final b = await billable(f);
      final draft = PaymentRequestDraft(
        studentId: b.studentId,
        payeeId: f.payeeId,
        dueOn: due,
        lessonIds: [b.lessonId],
      );
      final first = await f.payments.create(
        f.teamId,
        draft,
        idempotencyKey: 'same-key-12345',
      );
      final second = await f.payments.create(
        f.teamId,
        draft,
        idempotencyKey: 'same-key-12345',
      );
      expect(second.request.id, first.request.id);
    });

    test('withdrawing frees the lessons and closes the page', () async {
      final f = await create();
      final b = await billable(f);
      final made = await request(f, b);
      final sent = await f.payments.send(f.teamId, made.request.id);
      final withdrawn = await f.payments.cancel(f.teamId, made.request.id);
      expect(withdrawn.status, PaymentStatus.cancelled);
      expect(
        (await f.payments.billableLessons(
          f.teamId,
          studentId: b.studentId,
        )).map((l) => l.lessonId),
        contains(b.lessonId),
      );
      final page = await f.public.page(token(sent.link!));
      expect(page.status, PaymentStatus.cancelled);
      expect(page.paynowPayload, isNull);
      await expectLater(
        f.public.confirmPaid(token(sent.link!)),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('a void receipt is corrected, or reopens the request', () async {
      final f = await create();
      final made = await request(f, await billable(f));
      final sent = await f.payments.send(f.teamId, made.request.id);
      await f.public.confirmPaid(token(sent.link!));
      final paid = await f.payments.recordPayment(
        f.teamId,
        made.request.id,
        PaymentInput(amountCents: 5000, paidOn: DateTime.utc(2026, 11, 19)),
        idempotencyKey: key(),
      );
      final corrected = await f.payments.voidReceipt(
        f.teamId,
        paid.receipt!.id,
        reason: 'Recorded S\$ 50 by mistake.',
        correction: PaymentInput(
          amountCents: 7890,
          paidOn: DateTime.utc(2026, 11, 19),
        ),
        idempotencyKey: key(),
      );
      expect(corrected.voided, isTrue);
      expect(corrected.replacedByReceiptId, isNotNull);
      final replacement = await f.payments.receipt(
        f.teamId,
        corrected.replacedByReceiptId!,
      );
      expect(replacement.amountCents, 7890);
      expect(replacement.replacesReceiptId, corrected.id);
      int n(String number) => int.parse(number.substring(2));
      expect(n(replacement.number), n(corrected.number) + 1, reason: 'gapless');

      await f.payments.voidReceipt(
        f.teamId,
        replacement.id,
        reason: 'The transfer bounced.',
        idempotencyKey: key(),
      );
      final reopened = await f.payments.request(f.teamId, made.request.id);
      expect(reopened.status, PaymentStatus.open);
      expect(reopened.waitingFor, WaitingFor.both);
    });

    test('a request needs a checked account and billable lessons', () async {
      final f = await create();
      final b = await billable(f);
      await expectLater(
        f.payments.create(
          f.teamId,
          PaymentRequestDraft(
            studentId: b.studentId,
            payeeId: f.otherMemberId,
            dueOn: due,
            extraLines: const [
              ExtraLine(description: 'Book', amountCents: 100),
            ],
          ),
          idempotencyKey: key(),
        ),
        throwsA(isA<ConflictFailure>()),
      );
      await expectLater(
        f.payments.create(
          f.teamId,
          PaymentRequestDraft(
            studentId: b.studentId,
            payeeId: f.payeeId,
            dueOn: due,
          ),
          idempotencyKey: key(),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('an unknown link is not found', () async {
      final f = await create();
      await expectLater(
        f.public.page('no-such-link-at-all'),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });
}
