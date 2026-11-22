import 'package:flutter_test/flutter_test.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

Future<void> _students(WidgetTester tester) async {
  await tester.tap(find.text('Students').last);
  await tester.pumpAndSettle();
}

void main() {
  group('Students', () {
    testWidgets('an owner sees every student, and searches by any word', (
      tester,
    ) async {
      await pumpApp(tester);
      await _students(tester);
      expect(find.text('Aaliyah Yusof'), findsOneWidget);
      expect(find.text('Add student'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Search'),
        'lim',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sofia Lim'), findsOneWidget);
      expect(find.text('Sarah Lim'), findsOneWidget);
      expect(find.text('Ben Ong'), findsNothing);
    });

    testWidgets('a teacher sees the students she teaches only', (tester) async {
      await pumpApp(tester, persona: DemoPersona.teacher);
      await _students(tester);
      expect(find.text('Sofia Lim'), findsOneWidget);
      expect(find.text('Maya Rahman'), findsOneWidget, reason: 'group lesson');
      expect(find.text('Lucas Goh'), findsNothing);
      expect(find.text('Add student'), findsNothing);
      expect(find.text('Archived'), findsNothing);
    });

    testWidgets('an owner adds a student, then archives them', (tester) async {
      await pumpApp(tester);
      await _students(tester);
      await tester.tap(find.widgetWithText(PennyButton, 'Add student').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Student\'s name'),
        'Quinn Rivera',
      );
      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Contact\'s name'),
        'Rosa Rivera',
      );
      final add = find.widgetWithText(PennyButton, 'Add student').last;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Quinn Rivera added'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(PennyTextField, 'Search'),
        'quinn',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quinn Rivera'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rosa Rivera'), findsOneWidget);

      final archive = find.widgetWithText(PennyButton, 'Archive student');
      await tester.ensureVisible(archive);
      await tester.tap(archive);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PennyButton, 'Archive student').last,
      );
      await tester.pumpAndSettle();
      expect(find.text('This student is archived.'), findsOneWidget);
    });
  });
}
