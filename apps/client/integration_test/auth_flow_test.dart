// End to end in a browser: the real app, the real API and database, and
// the Firebase Auth emulator. Run with `task test:e2e` (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';
import 'support/auth_emulator.dart';
import 'support/flows.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final emulator = AuthEmulator();

  testWidgets(
    'a new person signs up, verifies, sets up, signs out and back in',
    (tester) async {
      final email = uniqueEmail('hana');
      const password = 'correct horse battery';

      await startApp(tester);
      await signUp(
        tester,
        emulator,
        name: 'Hana Lim',
        email: email,
        password: password,
      );

      // No team yet: onboarding, solo by default and named after them.
      await waitFor(
        tester,
        find.text('Do you teach on your own, or run a team?'),
      );
      await press(tester, 'Continue');

      // Signed in: the shell, with the account reachable from the avatar.
      await waitFor(tester, inTheApp);
      expect(find.text('Today'), findsWidgets);

      // Penny knows them by the name they gave.
      await openAccount(tester, 'Hana Lim');
      expect(find.text(email), findsOneWidget);

      await press(tester, 'Sign out');
      await waitFor(tester, find.text('Sign in to Penny'));

      await fill(tester, 'Email', email);
      await fill(tester, 'Password', password);
      await press(tester, 'Sign in');
      await waitFor(tester, inTheApp);
    },
  );
}
