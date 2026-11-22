import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/auth/application/session_controller.dart';
import '../features/system/application/server_info_provider.dart';
import 'demo_repositories.dart';

/// Every repository, backed by in-memory demo data.
///
/// Only app/backend_overrides.dart references this file. Deleting `lib/demo/`
/// and that one call removes the demo with no other change.
List<Override> demoOverrides() {
  final session = DemoSessionRepository();
  return [
    sessionRepositoryProvider.overrideWithValue(session),
    authRepositoryProvider.overrideWithValue(session),
    serverInfoRepositoryProvider.overrideWithValue(DemoServerInfoRepository()),
  ];
}
