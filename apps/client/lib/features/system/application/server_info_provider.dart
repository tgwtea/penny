import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/server_info.dart';

/// The server info repository in use, set by the composition root.
final serverInfoRepositoryProvider = Provider<ServerInfoRepository>(
  (ref) => throw UnimplementedError(
    'serverInfoRepositoryProvider is set by backendOverrides()',
  ),
);

/// The API build the app is connected to. Invalidate it to ask again.
///
/// Riverpod's automatic retry is off: a failure is shown with a Retry
/// button, so the person decides when to try again.
final serverInfoProvider = FutureProvider<ServerInfo>(
  (ref) => ref.watch(serverInfoRepositoryProvider).fetch(),
  retry: (_, _) => null,
);
