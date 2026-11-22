import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app/router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('a calendar link is shown once, copied and stopped', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final c = await pumpApp(tester, size: const Size(390, 2000));
    c.read(routerProvider).go('/account');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make a calendar link'));
    await tester.pumpAndSettle();
    expect(find.text('Your new calendar link'), findsOneWidget);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, contains('/v1/calendar/'));
    expect(find.text('Link copied'), findsOneWidget);

    await tester.tap(find.widgetWithText(PennyButton, 'Stop the link'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PennyButton, 'Stop the link').last);
    await tester.pumpAndSettle();
    expect(find.text('Calendar link stopped'), findsOneWidget);
    expect(find.text('Your new calendar link'), findsNothing);
  });
}
