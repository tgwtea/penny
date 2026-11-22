import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/capability.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/auth/data/http_session_repository.dart';
import 'package:penny/features/auth/domain/session.dart';

import '../fakes/fake_api.dart';
import '../fakes/fake_identity_provider.dart';

void main() {
  late FakeIdentityProvider identity;
  late FakeApi api;
  late HttpSessionRepository repo;

  setUp(() {
    identity = FakeIdentityProvider();
    api = FakeApi();
    repo = HttpSessionRepository(
      identity: identity,
      api: api.connection(idToken: identity.idToken),
    );
  });

  test('starts while the provider restores a saved sign-in', () {
    expect(repo.current, isA<SessionStarting>());
  });

  test('with nobody saved, signed out', () async {
    identity.restore();
    await pumpEventQueue();
    expect(repo.current, isA<SignedOut>());
  });

  test('a new account waits for email verification, then signs in', () async {
    identity.restore();
    await repo.createAccount(
      name: 'Hana Lim',
      email: 'hana@example.com',
      password: 'correct horse',
    );
    await pumpEventQueue();
    expect(repo.current, isA<AwaitingVerification>());
    expect(identity.calls, contains('sendEmailVerification'));
    expect(api.requests, isNot(contains('GET /v1/me')));

    identity.verify('hana@example.com');
    await repo.checkVerification();
    await pumpEventQueue();
    expect(repo.current, isA<SignedIn>());
  });

  test('loads teams and capabilities from /v1/me', () async {
    identity.seed('daniel@kohguitar.example', 'pw');
    api.memberships['daniel@kohguitar.example'] = [
      FakeApi.membership(
        teamId: 'team-1',
        teamName: 'Koh Guitar Studio',
        memberCount: 8,
        capabilities: ['manage_team', 'view_team_timetable'],
      ),
    ];
    identity.restore(signedInAs: 'daniel@kohguitar.example');
    await pumpEventQueue();

    final s = repo.current as SignedIn;
    expect(s.activeMembership?.team.name, 'Koh Guitar Studio');
    expect(s.can(Capability.manageTeam), isTrue);
    expect(s.can(Capability.managePayments), isFalse);
    expect(s.isTeamOfOne, isFalse);
  });

  test('a failed load says why and recovers on refresh', () async {
    identity.seed('mei@example.com', 'pw');
    api.failWith = 503;
    identity.restore(signedInAs: 'mei@example.com');
    await pumpEventQueue();
    final failed = repo.current;
    expect(failed, isA<SessionUnavailable>());
    expect((failed as SessionUnavailable).failure, isA<ServerFailure>());

    api.failWith = null;
    await repo.refresh();
    expect(repo.current, isA<SignedIn>());
  });

  test('wrong passwords are an AuthFailure, not a session change', () async {
    identity
      ..seed('mei@example.com', 'right')
      ..restore();
    await pumpEventQueue();
    await expectLater(
      repo.signInWithEmail(email: 'mei@example.com', password: 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (f) => f.reason,
          'reason',
          AuthFailureReason.wrongCredentials,
        ),
      ),
    );
    expect(repo.current, isA<SignedOut>());
  });

  test('deleting removes Penny\'s record before the sign-in', () async {
    identity.seed('priya@example.com', 'pw');
    identity.restore(signedInAs: 'priya@example.com');
    await pumpEventQueue();

    await repo.deleteAccount();
    expect(api.requests.last, 'DELETE /v1/me');
    expect(identity.calls.last, 'deleteAccount');
  });
}
