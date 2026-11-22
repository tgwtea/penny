import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/capability.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../domain/team_member.dart';
import '../domain/team_repository.dart';

/// The team repository in use, set by the composition root.
final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => throw UnimplementedError(
    'teamRepositoryProvider is set by backendOverrides()',
  ),
);

/// The active team's members. Reloads when the person switches team.
///
/// Riverpod's automatic retry is off: a failure is shown with a Retry
/// button, so the person decides when to try again.
final teamMembersProvider =
    AsyncNotifierProvider<TeamMembersController, List<TeamMember>>(
      TeamMembersController.new,
      retry: (_, _) => null,
    );

/// Loads the active team's members and changes them. After every change
/// the session is reloaded too, because the team's size decides whether
/// team features show.
class TeamMembersController extends AsyncNotifier<List<TeamMember>> {
  @override
  Future<List<TeamMember>> build() async {
    final teamId = ref.watch(_activeTeamId);
    if (teamId == null) return const [];
    return ref.watch(teamRepositoryProvider).members(teamId);
  }

  TeamRepository get _repository => ref.read(teamRepositoryProvider);

  String get _teamId =>
      ref.read(_activeTeamId) ?? (throw StateError('no team'));

  /// Adds a teacher by email.
  Future<TeamMember> addTeacher({
    required String name,
    required String email,
  }) async {
    final added = await _repository.addTeacher(
      _teamId,
      name: name,
      email: email,
    );
    await _reload();
    return added;
  }

  /// Makes [member] an owner or a teacher.
  Future<void> changeRole(TeamMember member, TeamRole role) async {
    await _repository.changeRole(_teamId, member.id, role);
    await _reload();
  }

  /// Removes [member] from the team.
  Future<void> remove(TeamMember member) async {
    await _repository.remove(_teamId, member.id);
    await _reload();
  }

  Future<void> _reload() async {
    final teamId = _teamId;
    state = AsyncData(await _repository.members(teamId));
    await ref.read(sessionProvider.notifier).refresh();
  }
}

final _activeTeamId = Provider<String?>((ref) {
  final session = ref.watch(sessionProvider);
  return session is SignedIn ? session.activeTeamId : null;
});
