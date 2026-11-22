import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../team/application/team_controller.dart';

/// Onboarding's one use case: create the person's first team, solo or not,
/// and load the session again so the app opens on it.
final createTeamProvider = Provider<Future<void> Function(String name)>((ref) {
  return (name) async {
    await ref.read(teamRepositoryProvider).createTeam(name: name);
    await ref.read(sessionProvider.notifier).refresh();
  };
});
