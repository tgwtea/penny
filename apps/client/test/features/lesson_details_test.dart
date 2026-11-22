import 'package:flutter_test/flutter_test.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

Future<void> _open(WidgetTester tester, String studentName) async {
  final row = find.text(studentName).first;
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(PennyButton, label);

void main() {
  group('Lesson details', () {
    testWidgets('a teacher may mark her lesson done but not cancel it', (
      tester,
    ) async {
      await pumpApp(tester, persona: DemoPersona.teacher);
      await _open(tester, 'Sofia Lim');
      expect(find.text('Thursday 19 November, 16:00 to 16:45'), findsOneWidget);
      expect(
        find.text('This lesson overlaps Mei\'s 16:30 lesson.'),
        findsOneWidget,
      );
      expect(_button('Mark done'), findsOneWidget);
      expect(_button('No-show'), findsOneWidget);
      expect(_button('Cancel lesson'), findsNothing);
      expect(_button('Reschedule'), findsNothing);
      expect(find.text('Mei\'s cancellation policy'), findsOneWidget);
    });

    testWidgets('the owner cancels a lesson and books a make-up', (
      tester,
    ) async {
      await pumpApp(tester);
      await _open(tester, 'Sofia Lim');
      await tester.ensureVisible(_button('Cancel lesson'));
      await tester.tap(_button('Cancel lesson'));
      await tester.pumpAndSettle();
      // Mei asks for two days' notice and charges late cancellations.
      expect(
        find.text('This is a late cancellation under Mei\'s policy.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Book a make-up lesson'));
      await tester.pumpAndSettle();
      final confirm = _button('Cancel lesson').last;
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Lesson cancelled, make-up booked'), findsOneWidget);
      expect(find.text('Cancelled late by the family.'), findsOneWidget);
      expect(find.text('Open the make-up lesson'), findsOneWidget);
    });

    testWidgets('a co-taught lesson says who bills it', (tester) async {
      await pumpApp(tester);
      await _open(tester, 'Hana Ito, Kai Wong, Maya Rahman +1');
      expect(find.text('Mei bills this lesson.'), findsOneWidget);
      expect(find.text('Assisting'), findsOneWidget);
    });

    testWidgets('a done lesson shows its ticked task and its history', (
      tester,
    ) async {
      await pumpApp(tester, persona: DemoPersona.teacher);
      await _open(tester, 'Arjun Nair');
      expect(
        find.text('Practise the tremolo, 10 minutes a day'),
        findsOneWidget,
      );
      expect(_button('Reopen'), findsOneWidget);
      expect(find.textContaining('Marked done by Mei Lin Tan'), findsOneWidget);
    });
  });
}
