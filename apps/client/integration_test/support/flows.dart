import 'package:flutter_test/flutter_test.dart';

import 'app.dart';
import 'auth_emulator.dart';

/// Creates an account from the sign-in page and verifies its email as the
/// link in the email would, leaving the app on whatever comes next
/// (onboarding, or Today for someone already invited to a team).
Future<void> signUp(
  WidgetTester tester,
  AuthEmulator emulator, {
  required String name,
  required String email,
  required String password,
}) async {
  await waitFor(tester, find.text('Sign in to Penny'));
  await press(tester, 'New to Penny? Create an account');
  await waitFor(tester, find.text('Create your Penny account'));
  await fill(tester, 'Your name', name);
  await fill(tester, 'Email', email);
  await fill(tester, 'Password', password);
  await press(tester, 'Create account');

  await waitFor(tester, find.text('Check your email'));
  await emulator.clickVerificationLink(email);
  await press(tester, 'I have verified my email');
}

/// Opens the Account page from the avatar of the person called [name].
Future<void> openAccount(WidgetTester tester, String name) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Account: $name')));
  await waitFor(tester, find.text('Delete account'));
}

/// Signs out from the Account page of [name].
Future<void> signOut(WidgetTester tester, String name) async {
  await openAccount(tester, name);
  await press(tester, 'Sign out');
  await waitFor(tester, find.text('Sign in to Penny'));
}
