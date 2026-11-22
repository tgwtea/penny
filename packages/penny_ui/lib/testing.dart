/// Test helpers for code built on penny_ui. Import from tests only.
///
/// Call [loadPennyFonts] once per test run (from `flutter_test_config.dart`)
/// so text renders in IBM Plex Sans and icons in Phosphor instead of the
/// test font's boxes, then use [pennyTestApp] and [pennyGoldens].
library;

import 'dart:convert';
import 'dart:io' show Platform;

// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'penny_ui.dart';

/// Loads every font in the app's font manifest, including penny_ui's own
/// IBM Plex Sans and the Phosphor icon fonts.
Future<void> loadPennyFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final assets = [
      for (final font
          in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>())
        font['asset'] as String,
    ];
    // In penny_ui's own tests its fonts (IBM Plex Sans and the Phosphor
    // icon fonts) are registered without the package prefix that PennyText
    // and PennyIcons ask for; register both names. In an app's tests the
    // manifest already carries the prefix.
    final names = {
      family,
      if (!family.startsWith('packages/'))
        'packages/${PennyText.fontPackage}/$family',
    };
    for (final name in names) {
      final loader = FontLoader(name);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  }
}

/// [child] inside a MaterialApp with Penny's theme, on a Scaffold.
///
/// Times render in 24-hour form unless [use24HourTime] is false, so
/// expectations and goldens do not depend on the machine's settings.
Widget pennyTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool use24HourTime = true,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light
        ? PennyTheme.light()
        : PennyTheme.dark(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(alwaysUse24HourFormat: use24HourTime),
      child: app!,
    ),
    home: Scaffold(body: child),
  );
}

/// Whether golden images can be compared on this machine.
///
/// Goldens are rendered on Linux, where CI runs. Other operating systems
/// rasterise text slightly differently, so there the golden tests are
/// skipped; `task test:goldens` runs them on Linux in Docker from any machine.
bool get goldensSupported => Platform.isLinux;

/// Registers a light and a dark golden test for [build], compared against
/// `goldens/<name>_light.png` and `goldens/<name>_dark.png`.
void pennyGoldens(
  String name,
  WidgetBuilder build, {
  Size size = const Size(390, 240),
}) {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light ? 'light' : 'dark';
    testWidgets(
      '$name ($theme)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          pennyTestApp(Builder(builder: build), brightness: brightness),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/${name}_$theme.png'),
        );
      },
      skip: !goldensSupported,
      tags: const ['golden'],
    );
  }
}
