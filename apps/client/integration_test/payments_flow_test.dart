// End to end in a browser: an owner sets up PayNow and checks the test
// code, bills a done lesson, sends the request, says "I've paid" on the
// payer's page, records the payment, and opens the receipt it issues
// (ADR 024). Run with `task test:e2e` (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:penny/features/payments/presentation/public_payment_screen.dart';
import 'package:penny_ui/penny_ui.dart';

import 'support/app.dart';
import 'support/auth_emulator.dart';
import 'support/flows.dart';

/// [finder] inside the sheet on top.
Finder inSheet(Finder finder) =>
    find.descendant(of: find.byType(PennySheet).last, matching: finder);

/// Taps [label]'s button inside the sheet on top.
Future<void> pressInSheet(WidgetTester tester, String label) async {
  final button = inSheet(find.widgetWithText(PennyButton, label));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

/// Waits until the snackbar saying [message] has gone, so it covers no
/// button at the foot of a small window.
Future<void> snackbarGone(WidgetTester tester, String message) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (find.text(message).evaluate().isNotEmpty &&
      DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final emulator = AuthEmulator();

  testWidgets('a lesson is billed, paid by both sides and receipted', (
    tester,
  ) async {
    await startApp(tester);
    await signUp(
      tester,
      emulator,
      name: 'Daniel Koh',
      email: uniqueEmail('daniel-payments'),
      password: 'correct horse battery',
    );
    await waitFor(
      tester,
      find.text('Do you teach on your own, or run a team?'),
    );
    await tester.tap(find.text('I run a team'));
    await settle(tester, rounds: 2);
    await fill(tester, 'Team name', 'E2E Payments');
    await press(tester, 'Continue');
    await waitFor(tester, inTheApp);

    // A student with a parent to bill, and a lesson marked done.
    await tester.tap(find.text('Students').first);
    await waitFor(tester, find.text('No students yet'));
    await press(tester, 'Add student');
    await waitFor(tester, find.byType(PennySheet));
    await fill(tester, 'Student\'s name', 'Arjun Nair');
    await fill(tester, 'Contact\'s name', 'Priya Nair');
    await fill(tester, 'Email', uniqueEmail('priya-payments'));
    await pressInSheet(tester, 'Add student');
    await waitFor(tester, find.text('Arjun Nair added'));
    await settle(tester, rounds: 4);

    await tester.tap(find.text('Today').first);
    await waitFor(tester, find.text('No lessons today'));
    await press(tester, 'Add lesson');
    await waitFor(tester, find.byType(PennySheet));
    await tester.tap(find.widgetWithText(PennySelectField, 'Students'));
    await waitFor(tester, inSheet(find.text('Arjun Nair')));
    await tester.tap(inSheet(find.text('Arjun Nair')));
    await tester.pump();
    await pressInSheet(tester, 'Done');
    await settle(tester, rounds: 2);
    await fill(tester, 'Fee (S\$)', '60');
    await pressInSheet(tester, 'Add lesson');
    await waitFor(tester, find.text('Lesson added'));
    final done = find.byTooltip('Mark done');
    if (done.evaluate().isEmpty) {
      markTestSkipped('the next hour is tomorrow in the team\'s timezone');
      return;
    }
    await tester.tap(done);
    await waitFor(tester, find.text('Lesson marked done'));
    await settle(tester, rounds: 4);

    // PayNow, checked against the test code.
    await openAccount(tester, 'Daniel Koh');
    await press(tester, 'Set up PayNow');
    await waitFor(tester, find.byType(PennySheet));
    await fill(tester, 'PayNow mobile number', '+65 9123 4567');
    await fill(tester, 'Name payers see', 'Daniel Koh');
    await pressInSheet(tester, 'Save PayNow');
    await waitFor(tester, find.text('Check the name before anyone pays.'));
    expect(find.byType(PennyQrCode), findsOneWidget);
    await press(tester, 'It shows my name');
    await waitFor(tester, find.text('PayNow checked'));
    await snackbarGone(tester, 'PayNow checked');

    // A request for the done lesson, kept as a draft, then sent.
    await tester.tap(find.text('Payments').first);
    await waitFor(tester, find.text('No payment requests yet'));
    await press(tester, 'New payment request');
    await waitFor(tester, find.byType(PennySheet));
    await tester.tap(inSheet(find.text('Choose a student')));
    await waitFor(tester, inSheet(find.text('Arjun Nair')));
    await tester.tap(inSheet(find.text('Arjun Nair')).last);
    await settle(tester, rounds: 4);
    await waitFor(tester, inSheet(find.byType(PennyCheckRow)));
    await pressInSheet(tester, 'Save draft');
    await waitFor(tester, find.text('Draft saved'));
    await waitFor(tester, find.widgetWithText(StatusBadge, 'Draft'));
    await snackbarGone(tester, 'Draft saved');
    await press(tester, 'Send request');
    await waitFor(tester, find.text('Request sent'));
    await waitFor(tester, find.textContaining('/pay/'));
    await snackbarGone(tester, 'Request sent');

    // The payer's page, as the family sees it: they say they paid.
    await press(tester, 'Open payment page');
    await waitFor(tester, find.byType(PennyQrCode));
    expect(find.text('Payment request for Arjun\'s lessons'), findsOneWidget);
    expect(find.textContaining('Nair'), findsNothing);
    await press(tester, 'I\'ve paid');
    await waitFor(tester, find.text('Thanks. You said you paid.'));
    GoRouter.of(tester.element(find.byType(PublicPaymentScreen))).pop();
    await settle(tester);

    // The payee records the money; the request is paid and receipted.
    await waitFor(tester, find.text('Arjun\'s family says they paid.'));
    await press(tester, 'Record payment');
    await waitFor(tester, find.byType(PennySheet));
    await pressInSheet(tester, 'Record payment');
    await waitFor(tester, find.text('Paid. Receipt R-0001 sent'));
    await waitFor(tester, find.text('Receipt R-0001'));
    expect(find.widgetWithText(StatusBadge, 'Paid'), findsOneWidget);
    await tester.tap(find.text('Receipt R-0001'));
    await waitFor(tester, find.text('Proof it is unaltered'));
    expect(find.text('S\$ 60.00'), findsWidgets);
  });
}
