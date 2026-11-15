import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny_ui/penny_ui.dart';
import 'package:penny_ui/testing.dart';

void main() {
  testWidgets('a small control still has a 48 px hit area', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      pennyTestApp(
        Center(
          child: PennyIconButton(
            icon: PennyIcons.check,
            tooltip: 'Mark done',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(PennyPressable));
    expect(size.width, greaterThanOrEqualTo(PennySize.touchTarget));
    expect(size.height, greaterThanOrEqualTo(PennySize.touchTarget));

    // A tap in the margin, outside the 44 px visual, still counts.
    final rect = tester.getRect(find.byType(PennyPressable));
    await tester.tapAt(rect.topLeft + const Offset(1, 1));
    expect(taps, 1);
  });

  testWidgets('the hit area does not loosen the parent constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      pennyTestApp(
        SizedBox(
          width: 200,
          height: 100,
          child: PennyPressable(
            onPressed: () {},
            contentColor: Colors.black,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    // A tight parent stays tight: the child fills it instead of shrinking.
    expect(tester.getSize(find.byType(SizedBox).last), const Size(200, 100));
  });

  testWidgets('Enter and Space activate a focused control', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      pennyTestApp(
        PennyPressable(
          onPressed: () => taps++,
          contentColor: Colors.black,
          focusNode: focus,
          child: const Text('Go'),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 2);
  });

  testWidgets('a disabled control ignores taps and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      pennyTestApp(const PennyButton(label: 'Save', onPressed: null)),
    );
    await tester.tap(find.text('Save'), warnIfMissed: false);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Save')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    semantics.dispose();
  });

  testWidgets('icon buttons are labelled for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      pennyTestApp(
        PennyIconButton(
          icon: PennyIcons.check,
          tooltip: 'Mark done',
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Mark done'), findsOneWidget);
    semantics.dispose();
  });
}
