import 'dart:async';

import 'package:penny_api/api.dart' as api;

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../../data/api_connection.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';
import '../domain/session_repository.dart';
import 'identity_provider.dart';

/// The session against the real identity provider and API.
///
/// The identity provider says who someone is; `GET /v1/me` says which teams
/// they belong to and what they may do in each (ADR 004). This repository
/// combines the two into one Session:
///
/// | Identity provider          | /v1/me      | Session              |
/// | -------------------------- | ----------- | -------------------- |
/// | restoring a saved sign-in  |             | SessionStarting      |
/// | nobody                     |             | SignedOut            |
/// | email not verified         |             | AwaitingVerification |
/// | verified                   | failed      | SessionUnavailable   |
/// | verified                   | the person  | SignedIn             |
class HttpSessionRepository implements SessionRepository, AuthRepository {
  /// Creates the repository. [api] must take its ID tokens from
  /// [identity] (app/backend_overrides.dart wires both).
  HttpSessionRepository({
    required IdentityProvider identity,
    required this._api,
  }) : _identity = identity {
    _subscription = identity.accountChanges.listen(_onAccount);
  }

  final IdentityProvider _identity;
  final ApiConnection _api;
  late final StreamSubscription<IdentityAccount?> _subscription;
  final _changes = StreamController<Session>.broadcast();
  Session _current = const SessionStarting();

  /// Increments on every load, so a slow, stale response never overwrites a
  /// newer session (such as signing out while /v1/me is in flight).
  int _generation = 0;

  @override
  Session get current => _current;

  @override
  Stream<Session> get changes => _changes.stream;

  @override
  SignInMethods get methods =>
      const SignInMethods(emailPassword: true, google: true);

  // SessionRepository -------------------------------------------------------

  @override
  Future<void> switchTeam(String teamId) async {
    final session = _current;
    if (session is! SignedIn ||
        !session.memberships.any((m) => m.team.id == teamId)) {
      throw ArgumentError.value(teamId, 'teamId', 'not one of your teams');
    }
    _emit(session.withActiveTeam(teamId));
  }

  @override
  Future<void> refresh() => _load(_identity.currentAccount);

  @override
  Future<void> rename(String displayName) async {
    final me = await _api.call(
      (client) => api.IdentityApi(
        client,
      ).updateMe(api.UpdateMeRequest(displayName: displayName)),
    );
    _emit(sessionFromMe(me, previous: _current));
  }

  // AuthRepository ----------------------------------------------------------

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _identity.signInWithEmail(email, password);

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) => _identity.createAccount(name, email, password);

  @override
  Future<void> signInWithGoogle() => _identity.signInWithGoogle();

  @override
  Future<void> signInAsPersona(String personaId) =>
      throw UnsupportedError('Personas exist only in demo builds.');

  @override
  Future<void> resendVerificationEmail() => _identity.sendEmailVerification();

  @override
  Future<void> checkVerification() async {
    await _identity.reload();
    await refresh();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _identity.sendPasswordReset(email);

  @override
  Future<void> signOut() => _identity.signOut();

  @override
  Future<void> deleteAccount() async {
    // Penny's record first: if the sign-in account went first and this
    // failed, nobody could sign in again to finish removing personal data.
    await _api.call((client) => api.IdentityApi(client).deleteMe());
    await _identity.deleteAccount();
  }

  // Loading -----------------------------------------------------------------

  /// The account the current session was built from.
  IdentityAccount? _loadedFor;

  /// Reacts to the identity provider. It also reports hourly token
  /// refreshes; those change nothing Penny shows, so they load nothing.
  Future<void> _onAccount(IdentityAccount? account) async {
    if (account != null && account == _loadedFor && _current is SignedIn) {
      return;
    }
    await _load(account);
  }

  Future<void> _load(IdentityAccount? account) async {
    final generation = ++_generation;
    _loadedFor = account;
    if (account == null) return _emit(const SignedOut());
    if (!account.emailVerified) {
      return _emit(AwaitingVerification(email: account.email));
    }
    Session next;
    try {
      final me = await _api.call((client) => api.IdentityApi(client).getMe());
      next = sessionFromMe(me, previous: _current);
    } on Failure catch (failure) {
      next = SessionUnavailable(failure);
    }
    if (generation == _generation) _emit(next);
  }

  void _emit(Session session) {
    _current = session;
    _changes.add(session);
  }

  /// Stops listening to the identity provider.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}

/// The session `GET /v1/me` describes. Keeps [previous]'s active team when
/// the person still belongs to it; otherwise their first team.
SignedIn sessionFromMe(api.Me me, {Session? previous}) {
  final memberships = [for (final m in me.memberships) _membership(m)];
  final previousTeam = previous is SignedIn ? previous.activeTeamId : null;
  final active =
      memberships.any((m) => m.team.id == previousTeam) && previousTeam != null
      ? previousTeam
      : memberships.firstOrNull?.team.id;
  return SignedIn(
    user: SessionUser(
      id: me.user.id,
      displayName: me.user.displayName,
      email: me.user.email,
    ),
    memberships: memberships,
    activeTeamId: active,
  );
}

TeamMembership _membership(api.Membership m) => TeamMembership(
  id: m.id,
  team: Team(
    id: m.workspace.id,
    name: m.workspace.name,
    timezone: m.workspace.timezone,
    memberCount: m.workspace.memberCount,
    reminderHours: m.workspace.reminderHours,
  ),
  role: switch (m.role) {
    api.MembershipRole.owner => TeamRole.owner,
    api.MembershipRole.teacher => TeamRole.teacher,
    api.MembershipRole.student => TeamRole.student,
    api.MembershipRole.parent => TeamRole.parent,
  },
  capabilities: {for (final c in m.capabilities) capabilityFrom(c)},
);

/// The domain capability for a contract value.
Capability capabilityFrom(api.Capability c) => switch (c) {
  api.Capability.viewOwnLessons => Capability.viewOwnLessons,
  api.Capability.viewTeamTimetable => Capability.viewTeamTimetable,
  api.Capability.manageTeam => Capability.manageTeam,
  api.Capability.manageLessons => Capability.manageLessons,
  api.Capability.reassignLessons => Capability.reassignLessons,
  api.Capability.completeOwnLessons => Capability.completeOwnLessons,
  api.Capability.editOwnLessonItems => Capability.editOwnLessonItems,
  api.Capability.manageStudents => Capability.manageStudents,
  api.Capability.viewOwnStudents => Capability.viewOwnStudents,
  api.Capability.managePayments => Capability.managePayments,
  api.Capability.manageOwnPayments => Capability.manageOwnPayments,
  api.Capability.viewLinkedLessons => Capability.viewLinkedLessons,
  api.Capability.viewLinkedPayments => Capability.viewLinkedPayments,
};
