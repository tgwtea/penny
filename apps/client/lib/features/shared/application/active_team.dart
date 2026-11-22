import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/capability.dart';
import '../../../core/team_time.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';

/// The team the app is showing, as features need it: which team, the
/// person's membership in it, its clock, and what they may do there.
@immutable
class ActiveTeam {
  /// Creates one.
  const ActiveTeam({
    required this.teamId,
    required this.membershipId,
    required this.time,
    required this.capabilities,
    required this.isTeamOfOne,
  });

  /// The workspace ID.
  final String teamId;

  /// The person's membership in it.
  final String membershipId;

  /// The team's timezone.
  final TeamTime time;

  /// What the person may do in it (for showing controls only).
  final Set<Capability> capabilities;

  /// Whether the team has one member, which hides team features.
  final bool isTeamOfOne;

  /// Whether the person may do [c].
  bool can(Capability c) => capabilities.contains(c);

  @override
  bool operator ==(Object other) =>
      other is ActiveTeam &&
      other.teamId == teamId &&
      other.membershipId == membershipId &&
      other.time.timezone == time.timezone &&
      setEquals(other.capabilities, capabilities) &&
      other.isTeamOfOne == isTeamOfOne;

  @override
  int get hashCode =>
      Object.hash(teamId, membershipId, time.timezone, isTeamOfOne);
}

/// The active team, or null when nobody is signed in to one.
final activeTeamProvider = Provider<ActiveTeam?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is! SignedIn) return null;
  final m = session.activeMembership;
  if (m == null) return null;
  return ActiveTeam(
    teamId: m.team.id,
    membershipId: m.id,
    time: TeamTime(m.team.timezone),
    capabilities: m.capabilities,
    isTeamOfOne: session.isTeamOfOne,
  );
});
