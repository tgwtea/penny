import 'dart:async';

import '../core/capability.dart';
import '../core/failure.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/domain/session_repository.dart';
import '../features/system/domain/server_info.dart';
import '../features/team/domain/team_member.dart';
import '../features/team/domain/team_repository.dart';
import 'demo_actor.dart';
import 'demo_personas.dart';
import 'demo_store.dart';

/// The demo session: one of the [DemoPersona]s, switchable at run time.
///
/// Demo builds sign in only as a persona (PRD R2, "Viewing as"); there are
/// no accounts, passwords or emails.
class DemoSessionRepository implements SessionRepository, AuthRepository {
  /// Starts signed in as [persona], or signed out when it is null. The
  /// persona's teams come from [store], shared with the other demo
  /// repositories.
  DemoSessionRepository({
    DemoPersona? persona = DemoPersona.owner,
    DemoStore? store,
  }) : store = store ?? DemoStore(),
       _persona = persona {
    _current = persona == null
        ? const SignedOut()
        : sessionFor(persona, store: this.store);
  }

  /// The demo's data.
  final DemoStore store;

  final _changes = StreamController<Session>.broadcast();
  late Session _current;
  DemoPersona? _persona;
  String? _renamedTo;

  @override
  Session get current => _current;

  @override
  Stream<Session> get changes => _changes.stream;

  /// The persona signed in, or null.
  DemoPersona? get persona => _persona;

  /// Views the demo as [persona].
  void usePersona(DemoPersona persona) {
    _persona = persona;
    _renamedTo = null;
    _emit(sessionFor(persona, store: store));
  }

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

  /// Reads the persona's teams from the store again, keeping the team they
  /// are looking at.
  @override
  Future<void> refresh() async {
    final persona = _persona;
    final session = _current;
    if (persona == null || session is! SignedIn) return;
    _emit(
      sessionFor(
        persona,
        store: store,
        activeTeamId: session.activeTeamId,
        displayName: _renamedTo,
      ),
    );
  }

  @override
  Future<void> rename(String displayName) async {
    _renamedTo = displayName.trim();
    await refresh();
  }

  @override
  Future<void> signOut() async {
    _persona = null;
    _emit(const SignedOut());
  }

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

/// Teams in the demo store, keeping the server's rules: owners first, no
/// duplicate emails, and never a team without an owner. Changes reload the
/// demo session, so the team's size shows at once.
class DemoTeamRepository implements TeamRepository {
  /// Creates the repository over [session]'s store.
  DemoTeamRepository(this._session);

  final DemoSessionRepository _session;

  DemoStore get _store => _session.store;

  @override
  Future<List<TeamMember>> members(String teamId) async =>
      _store.membersOf(teamId);

  @override
  Future<TeamMember> addTeacher(
    String teamId, {
    required String name,
    required String email,
  }) async {
    final trimmed = name.trim();
    final address = email.trim().toLowerCase();
    if (trimmed.isEmpty) {
      throw const ValidationFailure(
        'blank name',
        detail: 'Enter the teacher\'s name.',
      );
    }
    if (_store.hasEmail(teamId, address)) {
      throw const ConflictFailure(
        'duplicate email',
        detail: 'Someone with this email is already in the team.',
      );
    }
    return _store.invite(teamId, trimmed, address, TeamRole.teacher);
  }

  @override
  Future<TeamMember> changeRole(
    String teamId,
    String memberId,
    TeamRole role,
  ) async {
    final member = _find(teamId, memberId);
    if (member.role == role) return member;
    _keepAnOwner(teamId, member);
    final changed = TeamMember(
      id: member.id,
      name: member.name,
      email: member.email,
      role: role,
      status: member.status,
      joinedAt: member.joinedAt,
    );
    _store.update(teamId, changed);
    return changed;
  }

  @override
  Future<void> remove(String teamId, String memberId) async {
    _keepAnOwner(teamId, _find(teamId, memberId));
    _store.remove(teamId, memberId);
  }

  @override
  Future<String> createTeam({required String name}) async {
    final session = _session.current;
    if (session is! SignedIn) throw const UnauthenticatedFailure('signed out');
    if (name.trim().isEmpty) {
      throw const ValidationFailure(
        'blank name',
        detail: 'Enter a name for your team.',
      );
    }
    return _store.createTeam(name.trim(), session.user);
  }

  @override
  Future<void> setReminderHours(String teamId, int hours) async {
    DemoActor.of(_session, teamId).require(Capability.manageTeam);
    if (hours < 0 || hours > 168) {
      throw const ValidationFailure(
        'reminder hours',
        detail: 'Remind between 1 and 168 hours ahead, or not at all.',
      );
    }
    _store.setReminderHours(teamId, hours);
  }

  TeamMember _find(String teamId, String memberId) => _store
      .membersOf(teamId)
      .firstWhere(
        (m) => m.id == memberId,
        orElse: () => throw const NotFoundFailure('no such member'),
      );

  void _keepAnOwner(String teamId, TeamMember member) {
    if (!member.isOwner || member.status != MemberStatus.active) return;
    final owners = _store
        .membersOf(teamId)
        .where((m) => m.isOwner && m.status == MemberStatus.active);
    if (owners.length <= 1) {
      throw const ConflictFailure(
        'last owner',
        detail: 'A team needs an owner. Make someone else an owner first.',
      );
    }
  }
}

/// Demo builds talk to no server; they report themselves as the backend.
class DemoServerInfoRepository implements ServerInfoRepository {
  @override
  Future<ServerInfo> fetch() async =>
      const ServerInfo(version: 'demo', commit: 'in-memory');
}
