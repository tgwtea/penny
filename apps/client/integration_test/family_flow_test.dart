// End to end in a browser: an owner gives a parent a sign-in from the
// student's page; the parent signs up with that email and sees their
// child's lessons and payments, and nothing of the staff's (ADR 025). Run
// with `task test:e2e` (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

/// Waits until the snackbar saying [message] has gone.
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

  testWidgets('a parent given a sign-in sees their child\'s lessons', (
    tester,
  ) async {
    final parentEmail = uniqueEmail('priya-family');
    await startApp(tester);
    await signUp(
      tester,
      emulator,
      name: 'Daniel Koh',
      email: uniqueEmail('daniel-family'),
      password: 'correct horse battery',
    );
    await waitFor(
      tester,
      find.text('Do you teach on your own, or run a team?'),
    );
    await tester.tap(find.text('I run a team'));
    await settle(tester, rounds: 2);
    await fill(tester, 'Team name', 'E2E Family');
    await press(tester, 'Continue');
    await waitFor(tester, inTheApp);

    // A student with a parent, and a lesson booked for them.
    await tester.tap(find.text('Students').first);
    await waitFor(tester, find.text('No students yet'));
    await press(tester, 'Add student');
    await waitFor(tester, find.byType(PennySheet));
    await fill(tester, 'Student\'s name', 'Arjun Nair');
    await fill(tester, 'Contact\'s name', 'Priya Nair');
    await fill(tester, 'Email', parentEmail);
    await pressInSheet(tester, 'Add student');
    await waitFor(tester, find.text('Arjun Nair added'));
    await snackbarGone(tester, 'Arjun Nair added');

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
    await pressInSheet(tester, 'Add lesson');
    await waitFor(tester, find.text('Lesson added'));
    await snackbarGone(tester, 'Lesson added');

    // The owner lets the parent sign in, from the student's page.
    await tester.tap(find.text('Students').first);
    await waitFor(tester, find.text('Arjun Nair'));
    await tester.tap(find.text('Arjun Nair'));
    await waitFor(tester, find.byTooltip('Actions for Priya Nair'));
    await tester.tap(find.byTooltip('Actions for Priya Nair'));
    await settle(tester, rounds: 2);
    await tester.tap(find.text('Let them sign in'));
    await settle(tester, rounds: 2);
    await press(tester, 'Send invitation');
    await waitFor(tester, find.text('Invitation sent to $parentEmail'));
    await waitFor(tester, find.textContaining('Invited to sign in at'));
    await snackbarGone(tester, 'Invitation sent to $parentEmail');
    await signOut(tester, 'Daniel Koh');

    // The parent signs up with that email; their navigation is their
    // child's Lessons and Payments. (They return to Account, where the
    // owner signed out.)
    await signUp(
      tester,
      emulator,
      name: 'Priya Nair',
      email: parentEmail,
      password: 'correct horse battery',
    );
    await waitFor(tester, inTheApp);
    await settle(tester, rounds: 4);
    await tester.tap(find.text('Lessons').first);
    await waitFor(tester, find.text('Arjun Nair\'s lessons'));
    expect(find.text('Coming up'), findsOneWidget);
    await waitFor(tester, find.textContaining('with Daniel Koh'));
    expect(find.text('Students'), findsNothing);
    expect(find.text('Today'), findsNothing);

    await tester.tap(find.text('Payments').first);
    await waitFor(tester, find.text('Nothing to pay.'));
    expect(find.text('Receipts'), findsOneWidget);
  });
}
