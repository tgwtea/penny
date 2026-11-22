import 'package:flutter_test/flutter_test.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('booking over another lesson warns and still saves', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.widgetWithText(PennyButton, 'Add lesson').first);
    await tester.pumpAndSettle();
    expect(find.byType(PennySheet), findsOneWidget);

    // Daniel at 17:00 for 45 minutes overlaps his 17:30 lesson with Tessa.
    await tester.tap(find.widgetWithText(PennySelectField, 'Students'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(PennyTextField, 'Search'),
      'victor',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Victor Lam'));
    await tester.tap(find.widgetWithText(PennyButton, 'Done'));
    await tester.pumpAndSettle();

    final add = find.widgetWithText(PennyButton, 'Add lesson').last;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(
      find.text('This lesson overlaps Daniel\'s 17:30 lesson.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(PennyButton, 'Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Lesson added'), findsOneWidget);
    expect(find.text('Victor Lam'), findsOneWidget);
  });
}
