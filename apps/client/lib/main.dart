import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/backend_overrides.dart';
import 'app/config.dart';

/// Reads the build configuration, picks the backend, and starts the app.
///
///     flutter run                                      demo data, no server
///     flutter run --dart-define=PENNY_BACKEND=http     the API on localhost:8080
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await loadAppConfig();
  runApp(
    ProviderScope(overrides: backendOverrides(config), child: const PennyApp()),
  );
}
