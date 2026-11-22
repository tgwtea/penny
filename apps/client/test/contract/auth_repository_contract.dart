import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/auth/domain/auth_repository.dart';
import 'package:penny/features/auth/domain/session.dart';
import 'package:penny/features/auth/domain/session_repository.dart';

/// A repository that is both, signed in and settled.
typedef SignedInRepositories = ({
  AuthRepository auth,
  SessionRepository session,
});

/// What every AuthRepository must do (ADR 012).
void authRepositoryContract(
  String implementation,
  Future<SignedInRepositories> Function() signedIn,
) {
  group('$implementation honours the AuthRepository contract', () {
    test('offers at least one way in', () async {
      final m = (await signedIn()).auth.methods;
      expect(m.emailPassword || m.google || m.personas.isNotEmpty, isTrue);
    });

    test('signing out leaves the person signed out', () async {
      final r = await signedIn();
      expect(r.session.current, isA<SignedIn>());
      await r.auth.signOut();
      await pumpEventQueue();
      expect(r.session.current, isA<SignedOut>());
    });

    test('deleting the account signs the person out', () async {
      final r = await signedIn();
      await r.auth.deleteAccount();
      await pumpEventQueue();
      expect(r.session.current, isA<SignedOut>());
    });

    test('renaming shows the new name at once', () async {
      final r = await signedIn();
      await r.session.rename('Hana Lim');
      final s = r.session.current;
      expect(s, isA<SignedIn>());
      expect((s as SignedIn).user.displayName, 'Hana Lim');
    });
  });
}
