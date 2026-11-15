import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/auth/domain/session.dart';
import 'package:penny/features/auth/domain/session_repository.dart';

/// What every SessionRepository must do (ADR 012).
void sessionRepositoryContract(
  String implementation,
  SessionRepository Function() create,
) {
  group('$implementation honours the SessionRepository contract', () {
    test('has a session from the start, without waiting', () {
      expect(create().current, isA<Session>());
    });

    test('a signed-in session has an active team it belongs to', () {
      final session = create().current;
      if (session is SignedIn && session.activeTeamId != null) {
        expect(session.activeMembership, isNotNull);
      }
    });

    test('switching to a team the person is not in fails', () async {
      await expectLater(create().switchTeam('not-a-team'), throwsA(anything));
    });
  });
}
