import 'package:penny_api/api.dart' as api;

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../../data/api_connection.dart';
import '../domain/team_member.dart';
import '../domain/team_repository.dart';

/// Teams against the real API (`/v1/workspaces`).
class HttpTeamRepository implements TeamRepository {
  /// Creates a repository calling the API through [_api].
  HttpTeamRepository(this._api);

  final ApiConnection _api;

  @override
  Future<List<TeamMember>> members(String teamId) => _api.call((client) async {
    final list = await api.TeamsApi(client).listMembers(teamId);
    return [for (final m in list.items) _member(m)];
  });

  @override
  Future<TeamMember> addTeacher(
    String teamId, {
    required String name,
    required String email,
  }) async {
    final trimmed = name.trim();
    // The generated request refuses an empty name before sending it.
    if (trimmed.isEmpty) {
      throw const ValidationFailure(
        'blank name',
        detail: 'Enter the teacher\'s name.',
      );
    }
    return _api.call((client) async {
      final m = await api.TeamsApi(client).addMember(
        teamId,
        api.AddMemberRequest(
          displayName: trimmed,
          email: email.trim(),
          role: api.MembershipRole.teacher,
        ),
      );
      return _member(m);
    });
  }

  @override
  Future<TeamMember> changeRole(
    String teamId,
    String memberId,
    TeamRole role,
  ) => _api.call((client) async {
    final m = await api.TeamsApi(client).updateMember(
      teamId,
      memberId,
      api.UpdateMemberRequest(role: _role(role)),
    );
    return _member(m);
  });

  @override
  Future<void> remove(String teamId, String memberId) => _api.call(
    (client) => api.TeamsApi(client).removeMember(teamId, memberId),
  );

  @override
  Future<String> createTeam({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure(
        'blank name',
        detail: 'Enter a name for your team.',
      );
    }
    return _api.call((client) async {
      final m = await api.TeamsApi(
        client,
      ).createWorkspace(api.CreateWorkspaceRequest(name: trimmed));
      return m.workspace.id;
    });
  }

  static TeamMember _member(api.Member m) => TeamMember(
    id: m.id,
    name: m.displayName,
    email: m.email,
    role: switch (m.role) {
      api.MembershipRole.owner => TeamRole.owner,
      api.MembershipRole.teacher => TeamRole.teacher,
      api.MembershipRole.student => TeamRole.student,
      api.MembershipRole.parent => TeamRole.parent,
    },
    status: switch (m.status) {
      api.MemberStatus.active => MemberStatus.active,
      api.MemberStatus.invited => MemberStatus.invited,
    },
    joinedAt: m.joinedAt,
  );

  static api.MembershipRole _role(TeamRole r) => switch (r) {
    TeamRole.owner => api.MembershipRole.owner,
    TeamRole.teacher => api.MembershipRole.teacher,
    TeamRole.student => api.MembershipRole.student,
    TeamRole.parent => api.MembershipRole.parent,
  };
}
