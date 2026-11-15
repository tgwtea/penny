import 'session.dart';

/// Where the session comes from: the demo persona or the real identity
/// provider (ADR 012).
abstract interface class SessionRepository {
  /// The session right now. Available synchronously so the router can decide
  /// where to go on the first frame.
  Session get current;

  /// Every later change: sign-in, sign-out, switching team.
  Stream<Session> get changes;

  /// Makes [teamId] the active team. It must be one of the memberships.
  Future<void> switchTeam(String teamId);
}
