import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/features/auth/application/session_controller.dart';
import 'package:penny/features/auth/domain/session.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

void main() {
  group('an unsubscribe link', () {
    testWidgets('says what it stops and stops it only when confirmed', (
      tester,
    ) async {
      final c = await pumpApp(tester, persona: null);
      c.read(routerProvider).go('/unsubscribe/demo-lesson-reminders');
      await tester.pumpAndSettle();
      expect(find.text('Stop lesson reminders?'), findsOneWidget);
      expect(find.textContaining('p***@example.com'), findsOneWidget);
      expect(find.text('Koh Guitar Studio'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(PennyButton, 'Stop lesson reminders'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lesson reminders stopped'), findsOneWidget);
      expect(
        find.textContaining('Payment requests and receipts'),
        findsOneWidget,
      );
    });

    testWidgets('opens for a signed-in person too, outside the app', (
      tester,
    ) async {
      final c = await pumpApp(tester);
      c.read(routerProvider).go('/unsubscribe/demo-payment-reminders');
      await tester.pumpAndSettle();
      expect(find.text('Stop payment reminders?'), findsOneWidget);
      expect(find.byType(PennyBottomNav), findsNothing);
    });

    testWidgets('an unknown link says so and offers nothing to press', (
      tester,
    ) async {
      final c = await pumpApp(tester, persona: null);
      c.read(routerProvider).go('/unsubscribe/forged');
      await tester.pumpAndSettle();
      expect(find.text('This link doesn\'t work'), findsOneWidget);
      expect(find.byType(PennyButton), findsNothing);
    });
  });

  group('lesson reminders', () {
    testWidgets('an owner chooses how far ahead the team reminds', (
      tester,
    ) async {
      final c = await pumpApp(tester, size: const Size(390, 2400));
      c.read(routerProvider).go('/account');
      await tester.pumpAndSettle();
      expect(find.text('Lesson reminders'), findsOneWidget);
      expect(find.text('24 hours before'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(PennySelectField, 'Remind contacts'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 hours before').last);
      await tester.pumpAndSettle();
      expect(find.text('Reminders now go 2 hours before'), findsOneWidget);
      final session = c.read(sessionProvider) as SignedIn;
      expect(session.activeMembership!.team.reminderHours, 2);
    });

    testWidgets('a teacher does not see the team setting', (tester) async {
      final c = await pumpApp(
        tester,
        persona: DemoPersona.teacher,
        size: const Size(390, 2400),
      );
      c.read(routerProvider).go('/account');
      await tester.pumpAndSettle();
      expect(find.text('Lesson reminders'), findsNothing);
    });
  });

  testWidgets('a contact can keep payment requests but stop the reminders', (
    tester,
  ) async {
    final c = await pumpApp(tester, size: const Size(390, 2400));
    c.read(routerProvider).go('/students');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PennyListRow).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(RegExp('Actions for')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change').last);
    await tester.pumpAndSettle();
    expect(find.text('Payment reminders'), findsOneWidget);
    await tester.tap(find.text('Payment requests and receipts'));
    await tester.pumpAndSettle();
    expect(
      find.text('Payment reminders'),
      findsNothing,
      reason: 'no billing emails, so nothing to remind about',
    );
  });
}
