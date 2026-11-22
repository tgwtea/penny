// End to end in a browser: the real app, the real API and database, and
// the Firebase Auth emulator. Run with `task test:e2e` (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';
import 'support/auth_emulator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final emulator = AuthEmulator();

  testWidgets('a new person signs up, verifies, signs out and back in', (
    tester,
  ) async {
    final email = uniqueEmail('hana');
    const password = 'correct horse battery';

    await startApp(tester);
    await waitFor(tester, find.text('Sign in to Penny'));

    await press(tester, 'New to Penny? Create an account');
    await waitFor(tester, find.text('Create your Penny account'));
    await fill(tester, 'Your name', 'Hana Lim');
    await fill(tester, 'Email', email);
    await fill(tester, 'Password', password);
    await press(tester, 'Create account');

    await waitFor(tester, find.text('Check your email'));
    await emulator.clickVerificationLink(email);
    await press(tester, 'I have verified my email');

    // Signed in: the shell, with the account reachable from the avatar.
    await waitFor(tester, inTheApp);
    expect(find.text('Today'), findsWidgets);

    // Penny knows them by the name they gave.
    await tester.tap(find.bySemanticsLabel(RegExp('^Account: Hana Lim')));
    await waitFor(tester, find.text('Delete account'));
    expect(find.text(email), findsOneWidget);

    await press(tester, 'Sign out');
    await waitFor(tester, find.text('Sign in to Penny'));

    await fill(tester, 'Email', email);
    await fill(tester, 'Password', password);
    await press(tester, 'Sign in');
    await waitFor(tester, inTheApp);
  });
}
