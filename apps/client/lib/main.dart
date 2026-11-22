import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/backend_overrides.dart';
import 'app/config.dart';
import 'core/env.dart';
import 'features/auth/data/firebase_identity_provider.dart';

/// Reads the build configuration, picks the backend, and starts the app.
///
///     flutter run                                      demo data, no server
///     flutter run --dart-define=PENNY_BACKEND=http     the API on localhost:8080,
///                                                      signing in through the
///                                                      local Auth emulator
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await loadAppConfig();
  final identity = config.backend == BackendKind.http
      ? await FirebaseIdentityProvider.start(config.firebase)
      : null;
  runApp(
    ProviderScope(
      overrides: backendOverrides(config, identity: identity),
      child: const PennyApp(),
    ),
  );
}
