import 'package:flutter_test/flutter_test.dart';
import 'package:penny/main.dart' as app;
import 'package:penny_ui/penny_ui.dart';

/// Starts the real app, as `task run:client:web` builds it.
Future<void> startApp(WidgetTester tester) async {
  await app.main();
  await settle(tester);
}

/// Waits for network round trips, which pumpAndSettle alone does not.
Future<void> settle(WidgetTester tester, {int rounds = 20}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.pumpAndSettle();
}

/// Waits until [finder] finds something, or fails after [timeout].
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// Types [text] into the PennyTextField labelled [label].
Future<void> fill(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(PennyTextField, label), text);
  await tester.pump();
}

/// Taps the PennyButton labelled [label].
Future<void> press(WidgetTester tester, String label) async {
  final button = find.widgetWithText(PennyButton, label);
  await tester.ensureVisible(button.first);
  await tester.tap(button.first);
  await tester.pump();
}

/// The signed-in shell: bottom navigation on phone, the sidebar from 600 px.
final inTheApp = find.byWidgetPredicate(
  (w) => w is PennyBottomNav || w is PennySidebar,
  description: 'the signed-in navigation',
);
