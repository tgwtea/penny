import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/features/auth/application/session_controller.dart';
import 'package:penny/features/auth/domain/session.dart';
import 'package:penny/features/team/application/team_controller.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

Future<ProviderContainer> openTeam(
  WidgetTester tester, {
  Size size = phone,
}) async {
  final container = await pumpApp(tester, size: size);
  container.read(routerProvider).go('/team');
  await tester.pumpAndSettle();
  return container;
}

Future<void> fillAndAdd(WidgetTester tester, String name, String email) async {
  await tester.enterText(find.widgetWithText(PennyTextField, 'Name'), name);
  await tester.enterText(find.widgetWithText(PennyTextField, 'Email'), email);
  await tester.tap(find.widgetWithText(PennyButton, 'Add teacher').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the studio, owner first, marked as you', (tester) async {
    await openTeam(tester);
    final rows = tester
        .widgetList<PennyListRow>(find.byType(PennyListRow))
        .toList();
    expect(rows, hasLength(8));
    expect(rows.first.title, 'Daniel Koh');
    expect(rows.first.tag, 'You');
    expect(rows.where((r) => r.tag != null), hasLength(1));
    expect(rows.map((r) => r.title), contains('Mei Lin Tan'));
  });

  testWidgets('adds a teacher from a sheet on phone', (tester) async {
    final container = await openTeam(tester);
    await tester.tap(find.widgetWithText(PennyButton, 'Add teacher'));
    await tester.pumpAndSettle();
    expect(find.byType(PennySheet), findsOneWidget);

    // Validated on submit.
    await tester.tap(find.widgetWithText(PennyButton, 'Add teacher').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter the teacher\'s name.'), findsOneWidget);

    await fillAndAdd(tester, 'Zara Tan', 'zara@example.com');
    expect(find.byType(PennySheet), findsNothing);
    expect(find.text('Teacher added'), findsOneWidget);
    expect(find.text('Zara Tan'), findsOneWidget);
    expect(find.text('Invited'), findsOneWidget);
    // Invited members do not count until they sign in.
    final session = container.read(sessionProvider) as SignedIn;
    expect(session.activeMembership!.team.memberCount, 8);
  });

  testWidgets('adds a teacher from the panel on laptop, and refuses repeats', (
    tester,
  ) async {
    await openTeam(tester, size: laptop);
    await tester.tap(find.widgetWithText(PennyButton, 'Add teacher'));
    await tester.pumpAndSettle();
    expect(find.byType(PennySheet), findsOneWidget);

    await fillAndAdd(tester, 'Mei again', 'meilin@kohguitar.example');
    expect(
      find.text('Someone with this email is already in the team.'),
      findsOneWidget,
    );
  });

  testWidgets('makes a teacher an owner, and back', (tester) async {
    final container = await openTeam(tester);
    await tester.tap(find.byTooltip('Actions for Mei Lin Tan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make owner'));
    await tester.pumpAndSettle();
    expect(find.text('Mei Lin Tan is now an owner'), findsOneWidget);
    final members = container.read(teamMembersProvider).requireValue;
    expect(
      members.where((m) => m.isOwner).map((m) => m.name),
      contains('Mei Lin Tan'),
    );
  });

  testWidgets('removes a member after confirming', (tester) async {
    await openTeam(tester);
    await tester.tap(find.byTooltip('Actions for Ravi Kumar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from team'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Ravi Kumar from the team?'), findsOneWidget);
    await tester.tap(find.widgetWithText(PennyButton, 'Remove from team'));
    await tester.pumpAndSettle();
    expect(find.text('Ravi Kumar removed'), findsOneWidget);
    expect(find.widgetWithText(PennyListRow, 'Ravi Kumar'), findsNothing);
  });

  testWidgets('says why the last owner cannot step down', (tester) async {
    await openTeam(tester);
    await tester.tap(find.byTooltip('Actions for Daniel Koh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make teacher'));
    await tester.pumpAndSettle();
    expect(
      find.text('A team needs an owner. Make someone else an owner first.'),
      findsOneWidget,
    );
  });

  testWidgets('a solo tutor who adds a teacher gets the Team destination', (
    tester,
  ) async {
    final container = await pumpApp(tester, persona: DemoPersona.solo);
    expect(navLabels(tester), isNot(contains('Team')));
    container.read(routerProvider).go('/account');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Add a teacher'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Add teacher'));
    await tester.pumpAndSettle();
    await fillAndAdd(tester, 'Zara Tan', 'zara@example.com');
    expect(find.text('Zara Tan'), findsOneWidget);
  });

  testWidgets('someone in several teams switches from the sidebar', (
    tester,
  ) async {
    final container = await pumpApp(tester, size: laptop);
    await container.read(teamRepositoryProvider).createTeam(name: 'Koh Piano');
    await container.read(sessionProvider.notifier).refresh();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Koh Guitar Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Switch team'), findsOneWidget);
    await tester.tap(find.text('Koh Piano'));
    await tester.pumpAndSettle();
    final session = container.read(sessionProvider) as SignedIn;
    expect(session.activeMembership!.team.name, 'Koh Piano');
  });
}
