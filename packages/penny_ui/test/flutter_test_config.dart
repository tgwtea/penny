import 'dart:async';

import 'package:penny_ui/testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadPennyFonts();
  await testMain();
}
