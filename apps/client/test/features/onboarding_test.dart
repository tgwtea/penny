import 'package:flutter_test/flutter_test.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a solo tutor keeps their own name and gets no team features', (
    tester,
  ) async {
    await pumpApp(tester, persona: DemoPersona.newcomer);
    expect(
      find.text('Do you teach on your own, or run a team?'),
      findsOneWidget,
    );
    // Solo is the default, named after the person.
    expect(
      find.widgetWithText(PennyTextField, 'Your teaching name'),
      findsOneWidget,
    );
    expect(find.text('Hana Lim'), findsOneWidget);

    await tester.tap(find.widgetWithText(PennyButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('No lessons today'), findsOneWidget);
    expect(navLabels(tester), ['Today', 'Calendar', 'Students', 'Payments']);
  });

  testWidgets('someone running a team names it', (tester) async {
    await pumpApp(tester, persona: DemoPersona.newcomer, size: laptop);
    await tester.tap(find.text('I run a team'));
    await tester.pumpAndSettle();

    // The person's name is cleared: a team needs its own.
    await tester.tap(find.widgetWithText(PennyButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your team\'s name.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(PennyTextField, 'Team name'),
      'Lim Music School',
    );
    await tester.tap(find.widgetWithText(PennyButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Lim Music School'), findsWidgets);
    // A team of one until a teacher joins: no Team destination yet.
    expect(navLabels(tester), isNot(contains('Team')));
  });
}
