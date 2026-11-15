import '../domain/session.dart';
import '../domain/session_repository.dart';

/// The session against the real API.
///
/// Sign-in arrives in Phase 3 (Firebase Auth behind this same interface).
/// Until then nobody can be signed in, so the app shows the sign-in screen.
class HttpSessionRepository implements SessionRepository {
  @override
  Session get current => const SignedOut();

  @override
  Stream<Session> get changes => const Stream.empty();

  @override
  Future<void> switchTeam(String teamId) async {
    throw StateError('Nobody is signed in, so there is no team to switch to.');
  }
}
