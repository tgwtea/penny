import '../../../core/capability.dart';
import 'team_member.dart';

/// Teams and their members (PRD R5, build plan Phase 4).
///
/// Methods throw Failures (core/failure.dart). The rules are the server's
/// and both implementations keep them: members are listed owners first,
/// then by name; an email already in the team is a ConflictFailure; and a
/// change that would leave the team without an owner is a ConflictFailure.
abstract interface class TeamRepository {
  /// The team's active members and invitations.
  Future<List<TeamMember>> members(String teamId);

  /// Adds a teacher by email. They are invited until they sign in with it.
  Future<TeamMember> addTeacher(
    String teamId, {
    required String name,
    required String email,
  });

  /// Makes a member an owner or a teacher.
  Future<TeamMember> changeRole(String teamId, String memberId, TeamRole role);

  /// Removes a member, or withdraws an invitation.
  Future<void> remove(String teamId, String memberId);

  /// Creates a team owned by the signed-in person and returns its ID.
  Future<String> createTeam({required String name});

  /// Sets how many hours before a lesson its contacts are reminded, 0 to
  /// 168 (0 sends none). Owners only.
  Future<void> setReminderHours(String teamId, int hours);
}
