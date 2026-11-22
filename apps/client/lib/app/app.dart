// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import 'router.dart';

/// The Penny app: Penny's light and dark themes, following the device.
class PennyApp extends ConsumerWidget {
  /// Creates the app.
  const PennyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Penny',
      debugShowCheckedModeBanner: false,
      theme: PennyTheme.light(),
      darkTheme: PennyTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
