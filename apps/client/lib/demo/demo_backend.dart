import 'package:flutter_riverpod/misc.dart' show Override;

import '../features/auth/application/session_controller.dart';
import '../features/system/application/server_info_provider.dart';
import '../features/team/application/team_controller.dart';
import 'demo_personas.dart';
import 'demo_repositories.dart';

/// Every repository, backed by in-memory demo data, starting as [persona].
///
/// Only app/backend_overrides.dart (and tests) reference this file.
/// Deleting `lib/demo/` and that one call removes the demo with no other
/// change.
List<Override> demoOverrides({DemoPersona? persona = DemoPersona.owner}) {
  final session = DemoSessionRepository(persona: persona);
  return [
    sessionRepositoryProvider.overrideWithValue(session),
    authRepositoryProvider.overrideWithValue(session),
    serverInfoRepositoryProvider.overrideWithValue(DemoServerInfoRepository()),
    teamRepositoryProvider.overrideWithValue(DemoTeamRepository(session)),
  ];
}
