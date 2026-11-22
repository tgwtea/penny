import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny/core/capability.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/demo/demo_backend.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_store.dart';
import 'package:penny/features/auth/application/session_controller.dart';
import 'package:penny/features/auth/domain/session.dart';
import 'package:penny/features/auth/domain/session_repository.dart';
import 'package:penny/features/payments/application/payment_providers.dart';
import 'package:penny/features/payments/domain/payment_repository.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../support/pump_app.dart';

/// The app on demo data with [overrides] in place of the demo's own.
Future<ProviderContainer> pumpWith(
  WidgetTester tester,
  List<Override> overrides, {
  Size size = phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final replaced = {for (final o in overrides) o.origin};
  final container = ProviderContainer(
    overrides: [
      for (final o in demoOverrides(clock: () => designsNow))
        if (!replaced.contains(o.origin)) o,
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const In24Hours()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> openPayments(ProviderContainer c, WidgetTester tester) async {
  c.read(routerProvider).go('/payments');
  await tester.pumpAndSettle();
}

class _FailingPayments implements PaymentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(const NetworkFailure('offline'));
}

class _ParentSession implements SessionRepository {
  static final team = Team(
    id: DemoStore.studioId,
    name: DemoStore.studioName,
    timezone: 'Asia/Singapore',
    memberCount: 8,
  );

  @override
  final Session current = SignedIn(
    user: const SessionUser(
      id: 'parent',
      displayName: 'Priya Nair',
      email: 'parent.arjun@example.com',
    ),
    memberships: [
      TeamMembership(
        id: 'parent-membership',
        team: team,
        role: TeamRole.parent,
        capabilities: const {
          Capability.viewLinkedLessons,
          Capability.viewLinkedPayments,
        },
      ),
    ],
    activeTeamId: DemoStore.studioId,
  );

  @override
  Stream<Session> get changes => const Stream.empty();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> rename(String displayName) async {}

  @override
  Future<void> switchTeam(String teamId) async {}
}

void main() {
  group('the payments list', () {
    testWidgets('shows owners every request with its status', (tester) async {
      final c = await pumpApp(tester);
      await openPayments(c, tester);
      for (final name in ['Bella Kwok', 'Arjun Nair', 'Ben Ong', 'Chloe Tan']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      for (final word in ['Draft', 'Open', 'Paid']) {
        expect(find.widgetWithText(StatusBadge, word), findsOneWidget);
      }
      expect(find.widgetWithText(StatusBadge, 'Overdue'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate((w) => w is PennySegmented),
          matching: find.text('Overdue'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ben Ong'), findsOneWidget);
      expect(find.text('Arjun Nair'), findsNothing);
    });

    testWidgets('shows a teacher only the requests that pay them', (
      tester,
    ) async {
      final c = await pumpApp(tester, persona: DemoPersona.teacher);
      await openPayments(c, tester);
      expect(find.text('Arjun Nair'), findsOneWidget);
      expect(find.text('Bella Kwok'), findsNothing, reason: 'Daniel\'s draft');
    });

    testWidgets('is a table on laptop', (tester) async {
      final c = await pumpApp(tester, size: laptop);
      await openPayments(c, tester);
      expect(find.text('Reference'), findsOneWidget);
      expect(find.text('Pays'), findsOneWidget);
      expect(find.byType(PennyBottomNav), findsNothing);
    });

    testWidgets('is empty for a new tutor, who is asked to set up PayNow', (
      tester,
    ) async {
      final c = await pumpApp(tester, persona: DemoPersona.solo);
      await openPayments(c, tester);
      expect(find.text('No payment requests yet'), findsOneWidget);
      expect(find.text('Set up PayNow to ask for payment.'), findsOneWidget);
    });

    testWidgets('says when it could not load, with Retry', (tester) async {
      final c = await pumpWith(tester, [
        paymentRepositoryProvider.overrideWithValue(_FailingPayments()),
      ]);
      c.read(routerProvider).go('/payments');
      await tester.pump();
      expect(find.byType(PennySkeletonRow), findsWidgets, reason: 'loading');
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t load payment requests.'), findsOneWidget);
      expect(find.widgetWithText(PennyButton, 'Retry'), findsOneWidget);
    });

    testWidgets('is closed to a parent, whose Payments are their own', (
      tester,
    ) async {
      final c = await pumpWith(tester, [
        sessionRepositoryProvider.overrideWithValue(_ParentSession()),
      ]);
      await openPayments(c, tester);
      expect(find.text('Only the team owner can see this.'), findsOneWidget);
      // Their navigation's Payments is the family page (ADR 025).
      expect(navLabels(tester), ['Lessons', 'Payments']);
    });
  });

  testWidgets('a draft is sent, paid on the payer\'s page and recorded', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: const Size(390, 2400));
    await openPayments(c, tester);
    await tester.tap(find.text('Bella Kwok'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Not sent yet. Sending emails the family a link to a '
        'page with the PayNow code.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(PennyButton, 'Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Request sent'), findsOneWidget);
    expect(find.textContaining('/pay/'), findsOneWidget);

    await tester.tap(find.widgetWithText(PennyButton, 'Open payment page'));
    await tester.pumpAndSettle();
    expect(find.byType(PennyQrCode), findsOneWidget);
    expect(find.text('Payment request for Bella\'s lessons'), findsOneWidget);
    await tester.tap(find.widgetWithText(PennyButton, 'I\'ve paid'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks. You said you paid.'), findsOneWidget);

    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.text('Bella\'s family says they paid.'), findsOneWidget);
    await tester.tap(find.widgetWithText(PennyButton, 'Record payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Record payment').last);
    await tester.pumpAndSettle();
    expect(find.text('Paid. Receipt R-0002 sent'), findsOneWidget);
    expect(find.text('Receipt R-0002'), findsOneWidget);
    expect(find.widgetWithText(StatusBadge, 'Paid'), findsOneWidget);
  });

  testWidgets('a new request bills a student\'s done lessons', (tester) async {
    final c = await pumpApp(tester, size: const Size(390, 2400));
    final billable = await c
        .read(paymentRepositoryProvider)
        .billableLessons(DemoStore.studioId);
    final lesson = billable.firstWhere((l) => l.payeeId == demoId('b2'));
    await openPayments(c, tester);
    await tester.tap(find.text('New payment request').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a student'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(lesson.studentNames.first).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennySelectField, 'Pays'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mei Lin Tan').last);
    await tester.pumpAndSettle();
    expect(find.byType(PennyCheckRow), findsWidgets);
    expect(find.text('S\$ 0.00'), findsNothing);

    await tester.tap(find.widgetWithText(PennyButton, 'Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsOneWidget);
    expect(find.text(lesson.studentNames.first), findsWidgets);
    expect(find.widgetWithText(StatusBadge, 'Draft'), findsOneWidget);
    // Each lesson line opens its lesson: a request traces to what it bills.
    await tester.tap(find.bySemanticsLabel(RegExp('^Open the lesson: ')).first);
    await tester.pumpAndSettle();
    expect(find.text('Lesson'), findsWidgets);
    final left = await c
        .read(paymentRepositoryProvider)
        .billableLessons(DemoStore.studioId);
    expect(left.map((l) => l.lessonId), isNot(contains(lesson.lessonId)));
  });

  testWidgets('a tutor sets up PayNow and checks the test code', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      persona: DemoPersona.solo,
      size: const Size(390, 2400),
    );
    c.read(routerProvider).go('/account');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Set up PayNow'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(PennyTextField, 'PayNow mobile number'),
      '9123 4567',
    );
    await tester.enterText(
      find.widgetWithText(PennyTextField, 'Name payers see'),
      'Priya Shah',
    );
    await tester.tap(find.widgetWithText(PennyButton, 'Save PayNow'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the mobile number as +65 and 8 digits.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(PennyTextField, 'PayNow mobile number'),
      '+65 9123 4567',
    );
    await tester.tap(find.widgetWithText(PennyButton, 'Save PayNow'));
    await tester.pumpAndSettle();
    expect(find.text('Check the name before anyone pays.'), findsOneWidget);
    expect(find.byType(PennyQrCode), findsOneWidget);
    await tester.tap(find.widgetWithText(PennyButton, 'It shows my name'));
    await tester.pumpAndSettle();
    expect(find.text('PayNow checked'), findsOneWidget);
    expect(
      find.text('PayNow to +6591234567, shown to payers as Priya Shah.'),
      findsOneWidget,
    );
  });

  testWidgets('a voided receipt is replaced by a corrected one', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: const Size(390, 2400));
    c.read(routerProvider).go('/receipts');
    await tester.pumpAndSettle();
    expect(navLabels(tester), contains('Payments'));
    await tester.tap(find.text('R-0001'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Void receipt'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PennyButton, 'Void and issue a corrected receipt'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Say why the receipt is wrong.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(PennyTextField, 'Why it is wrong'),
      'S\$ 200 arrived, not S\$ 240.',
    );
    await tester.enterText(
      find.widgetWithText(PennyTextField, 'Amount that arrived (S\$)'),
      '200',
    );
    await tester.tap(
      find.widgetWithText(PennyButton, 'Void and issue a corrected receipt'),
    );
    await tester.pumpAndSettle();
    expect(find.text('R-0001 voided and replaced'), findsOneWidget);
    expect(find.widgetWithText(StatusBadge, 'Void'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(PennyButton, 'Open the corrected receipt'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Receipt R-0002'), findsOneWidget);
    expect(find.text('S\$ 200.00'), findsWidgets);
  });

  group('the payer\'s page', () {
    testWidgets('an unknown link says so', (tester) async {
      final c = await pumpApp(tester, persona: null);
      c.read(routerProvider).go('/pay/not-a-link');
      await tester.pumpAndSettle();
      expect(find.text('This payment link doesn\'t work'), findsOneWidget);
    });

    testWidgets('shows only a first name, and the payee\'s policy', (
      tester,
    ) async {
      final c = await pumpApp(tester, persona: null, size: laptop);
      c.read(routerProvider).go('/pay/demo-open-request');
      await tester.pumpAndSettle();
      expect(find.text('Payment request for Arjun\'s lessons'), findsOneWidget);
      expect(find.textContaining('Nair'), findsNothing);
      expect(find.text('Cancellation policy'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('PayNow code for S\\\$ 240.00')),
        findsOneWidget,
      );
    });
  });
}
