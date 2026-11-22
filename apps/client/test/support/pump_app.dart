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

/// Starts the whole app on demo data as [persona] at [size], with every
/// demo repository the composition root would use, and returns its
/// provider container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  DemoPersona? persona = DemoPersona.owner,
  Size size = phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: demoOverrides(persona: persona),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const PennyApp()),
  );
  await tester.pumpAndSettle();
  return container;
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
