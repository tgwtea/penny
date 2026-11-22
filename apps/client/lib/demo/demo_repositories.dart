import 'dart:async';

import '../core/failure.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/domain/session_repository.dart';
import '../features/system/domain/server_info.dart';
import 'demo_personas.dart';

/// The demo session: one of the [DemoPersona]s, switchable at run time.
///
/// Demo builds sign in only as a persona (PRD R2, "Viewing as"); there are
/// no accounts, passwords or emails.
class DemoSessionRepository implements SessionRepository, AuthRepository {
  /// Starts signed in as [persona], or signed out when it is null.
  DemoSessionRepository({DemoPersona? persona = DemoPersona.owner})
    : _current = persona == null ? const SignedOut() : sessionFor(persona);

  final _changes = StreamController<Session>.broadcast();
  Session _current;

  @override
  Session get current => _current;

  @override
  Stream<Session> get changes => _changes.stream;

  /// Views the demo as [persona].
  void usePersona(DemoPersona persona) => _emit(sessionFor(persona));

  @override
  SignInMethods get methods => SignInMethods(
    personas: [
      for (final p in DemoPersona.values)
        SignInPersona(
          id: p.name,
          name: p.displayName,
          description: p.description,
        ),
    ],
  );

  @override
  Future<void> signInAsPersona(String personaId) async {
    usePersona(DemoPersona.values.byName(personaId));
  }

  @override
  Future<void> switchTeam(String teamId) async {
    final session = _current;
    if (session is! SignedIn ||
        !session.memberships.any((m) => m.team.id == teamId)) {
      throw ArgumentError.value(
        teamId,
        'teamId',
        'not one of the demo persona\'s teams',
      );
    }
    _emit(session.withActiveTeam(teamId));
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> rename(String displayName) async {
    final session = _current;
    if (session is! SignedIn) return;
    _emit(
      SignedIn(
        user: SessionUser(
          id: session.user.id,
          displayName: displayName.trim(),
          email: session.user.email,
        ),
        memberships: session.memberships,
        activeTeamId: session.activeTeamId,
      ),
    );
  }

  @override
  Future<void> signOut() async => _emit(const SignedOut());

  /// The demo has no accounts to delete; it signs out.
  @override
  Future<void> deleteAccount() => signOut();

  // Demo builds offer personas only (methods); screens never call these.

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _personasOnly();

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) => _personasOnly();

  @override
  Future<void> signInWithGoogle() => _personasOnly();

  @override
  Future<void> resendVerificationEmail() => _personasOnly();

  @override
  Future<void> checkVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) => _personasOnly();

  Future<void> _personasOnly() async => throw const AuthFailure(
    AuthFailureReason.unknown,
    'demo builds sign in as a persona',
  );

  void _emit(Session session) {
    _current = session;
    _changes.add(session);
  }

  /// Releases the stream.
  Future<void> dispose() => _changes.close();
}

/// Demo builds talk to no server; they report themselves as the backend.
class DemoServerInfoRepository implements ServerInfoRepository {
  @override
  Future<ServerInfo> fetch() async =>
      const ServerInfo(version: 'demo', commit: 'in-memory');
}
