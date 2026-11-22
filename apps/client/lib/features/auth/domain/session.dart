import 'package:flutter/foundation.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';

/// A team, as the session needs it. The UI says "Team"; the API says
/// workspace.
@immutable
class Team {
  /// Creates a team.
  const Team({
    required this.id,
    required this.name,
    required this.timezone,
    required this.memberCount,
    this.reminderHours = 24,
  });

  /// The workspace ID.
  final String id;

  /// The team's name: "Koh Guitar Studio".
  final String name;

  /// IANA timezone; every time in the team is shown in it.
  final String timezone;

  /// Active members. A team of one hides every team feature.
  final int memberCount;

  /// How many hours before a lesson its contacts are reminded by email;
  /// 0 sends no reminders.
  final int reminderHours;
}

/// A person's place in one team: their role and what it lets them do.
@immutable
class TeamMembership {
  /// Creates a membership.
  const TeamMembership({
    required this.id,
    required this.team,
    required this.role,
    required this.capabilities,
  });

  /// The membership ID. Lessons point at memberships, not users, because one
  /// person can teach in several teams.
  final String id;

  /// The team.
  final Team team;

  /// The role, for display only.
  final TeamRole role;

  /// What the person may do in this team, from the server's matrix.
  final Set<Capability> capabilities;
}

/// The signed-in person.
@immutable
class SessionUser {
  /// Creates a user.
  const SessionUser({
    required this.id,
    required this.displayName,
    required this.email,
  });

  /// Penny's user ID.
  final String id;

  /// Their name as shown in the app.
  final String displayName;

  /// Their email address.
  final String email;
}

/// Who is using the app, and in which team.
///
/// The router reads it on every change (app/routes.dart): each state has
/// one place the person belongs.
@immutable
sealed class Session {
  const Session();
}

/// The app is finding out whether someone is signed in, such as while the
/// identity provider restores a saved sign-in on start.
final class SessionStarting extends Session {
  /// Creates a starting session.
  const SessionStarting();
}

/// Nobody is signed in.
final class SignedOut extends Session {
  /// Creates a signed-out session.
  const SignedOut();
}

/// Someone signed in, but has not verified their email address yet. Penny
/// needs a verified address before it lets them in (ADR 004).
final class AwaitingVerification extends Session {
  /// Creates the session for [email].
  const AwaitingVerification({required this.email});

  /// The address the verification link was sent to.
  final String email;
}

/// Someone signed in, but Penny could not load who they are: the server is
/// unreachable or failed. Retrying (SessionRepository.refresh) may fix it.
final class SessionUnavailable extends Session {
  /// Creates the session for [failure].
  const SessionUnavailable(this.failure);

  /// Why loading failed.
  final Failure failure;
}

/// Someone is signed in.
final class SignedIn extends Session {
  /// Creates a signed-in session. [activeTeamId] must name one of
  /// [memberships], or be null before onboarding creates a team.
  SignedIn({
    required this.user,
    required this.memberships,
    required this.activeTeamId,
  }) : assert(
         activeTeamId == null ||
             memberships.any((m) => m.team.id == activeTeamId),
         'activeTeamId must be one of the memberships',
       );

  /// The person.
  final SessionUser user;

  /// Every team they belong to.
  final List<TeamMembership> memberships;

  /// The team the app is showing.
  final String? activeTeamId;

  /// The membership in the active team, or null before onboarding.
  TeamMembership? get activeMembership {
    for (final m in memberships) {
      if (m.team.id == activeTeamId) return m;
    }
    return null;
  }

  /// Whether the person may do [capability] in the active team. For
  /// showing and hiding controls only; the server decides.
  bool can(Capability capability) =>
      activeMembership?.capabilities.contains(capability) ?? false;

  /// Whether the person is a student or parent in the active team (ADR
  /// 025): they see their family's pages, not the staff's.
  bool get isFamily =>
      !can(Capability.viewOwnLessons) && can(Capability.viewLinkedLessons);

  /// Whether the active team has one member. Team features are hidden then;
  /// there is no separate solo mode.
  bool get isTeamOfOne => (activeMembership?.team.memberCount ?? 1) <= 1;

  /// Whether the person can switch to another team.
  bool get hasSeveralTeams => memberships.length > 1;

  /// Whether the person still has to create or join a team.
  bool get needsOnboarding => memberships.isEmpty;

  /// A copy showing [teamId] instead.
  SignedIn withActiveTeam(String teamId) =>
      SignedIn(user: user, memberships: memberships, activeTeamId: teamId);
}
