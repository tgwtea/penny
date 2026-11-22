import 'package:flutter/foundation.dart';

import '../../../core/capability.dart';

/// Where a member stands. Removed members are not listed.
enum MemberStatus {
  /// Signed in and part of the team.
  active,

  /// Added by email; becomes active when they first sign in with it.
  invited,
}

/// A person in a team, as the team list shows them.
@immutable
class TeamMember {
  /// Creates a member.
  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.joinedAt,
  });

  /// The membership ID. Lessons point at memberships.
  final String id;

  /// Their name as the team sees it.
  final String name;

  /// Their email address.
  final String email;

  /// Their role, shown as a word.
  final TeamRole role;

  /// Active or invited.
  final MemberStatus status;

  /// When they became active; null while invited.
  final DateTime? joinedAt;

  /// Whether they own the team.
  bool get isOwner => role == TeamRole.owner;
}
