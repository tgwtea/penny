import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What time it is, as an instant in UTC. Screens and controllers read the
/// time from here, never from DateTime.now, so tests and the demo can fix
/// "now" (the designs assume Thursday 19 November 2026, 16:20 SGT).
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
