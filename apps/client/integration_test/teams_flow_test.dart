// End to end in a browser: an owner sets up a team and adds a teacher, who
// then signs up and joins it. Run with `task test:e2e` (README.md).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:penny_ui/penny_ui.dart';

import 'support/app.dart';
import 'support/auth_emulator.dart';
import 'support/flows.dart';

/// The labels of the navigation shown, bottom bar or sidebar.
List<String> navLabels(WidgetTester tester) => [
  for (final nav in tester.widgetList<PennyBottomNav>(
    find.byType(PennyBottomNav),
  ))
    for (final d in nav.destinations) d.label,
  for (final bar in tester.widgetList<PennySidebar>(find.byType(PennySidebar)))
    for (final d in bar.destinations) d.label,
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final emulator = AuthEmulator();

  testWidgets('an owner adds a teacher, who joins on signing up', (
    tester,
  ) async {
    final ownerEmail = uniqueEmail('daniel');
    final teacherEmail = uniqueEmail('meilin');
    const password = 'correct horse battery';

    await startApp(tester);
    await signUp(
      tester,
      emulator,
      name: 'Daniel Koh',
      email: ownerEmail,
      password: password,
    );

    // Onboarding: run a team.
    await waitFor(
      tester,
      find.text('Do you teach on your own, or run a team?'),
    );
    await tester.tap(find.text('I run a team'));
    await settle(tester, rounds: 2);
    await fill(tester, 'Team name', 'E2E Studio');
    await press(tester, 'Continue');
    await waitFor(tester, inTheApp);
    expect(find.text('E2E Studio'), findsWidgets);

    // A team of one shows no Team destination; the Account page leads there.
    expect(navLabels(tester), isNot(contains('Team')));
    await openAccount(tester, 'Daniel Koh');
    await press(tester, 'Add a teacher');
    await waitFor(tester, find.widgetWithText(PennyButton, 'Add teacher'));

    await press(tester, 'Add teacher');
    await waitFor(tester, find.byType(PennySheet));
    await fill(tester, 'Name', 'Mei Lin');
    await fill(tester, 'Email', teacherEmail);
    final submit = find.widgetWithText(PennyButton, 'Add teacher').last;
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await waitFor(tester, find.text('Invited'));
    // The list can show the teacher a moment before the form clears the
    // email typed into it (on laptop the form stays open for the next one).
    await settle(tester, rounds: 4);
    expect(find.text(teacherEmail), findsOneWidget);

    await signOut(tester, 'Daniel Koh');

    // The teacher signs up with the invited email and is in the team at
    // once, without onboarding, and without the owner's Team destination.
    await signUp(
      tester,
      emulator,
      name: 'Mei Lin Tan',
      email: teacherEmail,
      password: password,
    );
    await waitFor(tester, inTheApp);
    expect(find.text('E2E Studio'), findsWidgets);
    expect(find.text('Do you teach on your own, or run a team?'), findsNothing);
    expect(navLabels(tester), ['Today', 'Calendar', 'Students', 'Payments']);
  });
}
