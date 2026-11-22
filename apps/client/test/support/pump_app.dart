import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/app.dart';
import 'package:penny/demo/demo_backend.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny_ui/penny_ui.dart';

/// A phone, as the designs draw it.
const phone = Size(390, 844);

/// A laptop, as the designs draw it.
const laptop = Size(1440, 900);

/// The moment the designs show: Thursday 19 November 2026, 16:20 in
/// Singapore. Demo data is placed around this week in tests.
final designsNow = DateTime.utc(2026, 11, 19, 8, 20);

/// Starts the whole app on demo data as [persona] at [size], with every
/// demo repository the composition root would use, at [now] (the designs'
/// moment unless given), and returns its provider container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  DemoPersona? persona = DemoPersona.owner,
  Size size = phone,
  DateTime? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: demoOverrides(persona: persona, clock: () => now ?? designsNow),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const In24Hours()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The app with times in 24-hour form ("16:00", as the designs show them),
/// whatever the machine running the tests is set to.
class In24Hours extends StatelessWidget {
  /// Wraps the app.
  const In24Hours({super.key});

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQueryData.fromView(
      View.of(context),
    ).copyWith(alwaysUse24HourFormat: true),
    child: const PennyApp(),
  );
}

/// The labels of the navigation shown, bottom bar or sidebar.
List<String> navLabels(WidgetTester tester) => [
  for (final nav in tester.widgetList<PennyBottomNav>(
    find.byType(PennyBottomNav),
  ))
    for (final d in nav.destinations) d.label,
  for (final bar in tester.widgetList<PennySidebar>(find.byType(PennySidebar)))
    for (final d in bar.destinations) d.label,
];
