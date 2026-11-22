import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/env.dart';
import '../../../core/failure.dart';
import 'identity_provider.dart';

/// Firebase Auth as Penny's identity provider (ADR 004). The only file that
/// knows Firebase exists, apart from `main.dart` starting it.
class FirebaseIdentityProvider implements IdentityProvider {
  FirebaseIdentityProvider._(this._auth);

  /// Starts Firebase for [settings] and returns the provider. With an
  /// emulator host, sign-in goes to the local Auth emulator under a demo
  /// project, which never reaches a real Firebase project.
  static Future<FirebaseIdentityProvider> start(
    FirebaseSettings settings,
  ) async {
    final app = settings.usesEmulator
        ? await Firebase.initializeApp(demoProjectId: settings.projectId)
        : await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: settings.apiKey,
              appId: settings.appId,
              messagingSenderId: settings.messagingSenderId,
              projectId: settings.projectId,
              authDomain: settings.authDomain,
            ),
          );
    final auth = FirebaseAuth.instanceFor(app: app);
    final emulator = settings.authEmulatorHost;
    if (emulator != null) {
      final (host, port) = _hostAndPort(emulator);
      await auth.useAuthEmulator(host, port);
    }
    return FirebaseIdentityProvider._(auth);
  }

  final FirebaseAuth _auth;

  @override
  IdentityAccount? get currentAccount => _account(_auth.currentUser);

  @override
  Stream<IdentityAccount?> get accountChanges =>
      _auth.userChanges().map(_account);

  @override
  Future<String?> idToken() => _guard(() async {
    return _auth.currentUser?.getIdToken();
  });

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _guard(() async {
        await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      });

  @override
  Future<void> createAccount(String name, String email, String password) =>
      _guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        final user = credential.user;
        if (user == null) return;
        await user.updateDisplayName(name.trim());
        await user.sendEmailVerification();
      });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    await _auth.signInWithPopup(GoogleAuthProvider());
  });

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    await _auth.currentUser?.sendEmailVerification();
  });

  @override
  Future<void> reload() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    // The ID token's email_verified claim was fixed when it was issued.
    await user.getIdToken(true);
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Say "sent" whether or not the account exists.
      if (e.code != 'user-not-found') rethrow;
    }
  });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> deleteAccount() => _guard(() async {
    await _auth.currentUser?.delete();
  });

  static IdentityAccount? _account(User? user) => user == null
      ? null
      : IdentityAccount(
          uid: user.uid,
          email: user.email ?? '',
          emailVerified: user.emailVerified,
        );

  /// Runs [action], translating Firebase's errors into domain failures.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw failureFor(e.code, e.message);
    } on FirebaseException catch (e) {
      throw failureFor(e.code, e.message);
    }
  }

  /// The domain failure for a Firebase error code.
  static Failure failureFor(String code, String? message) {
    final reason = switch (code) {
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'wrong-password' ||
      'user-not-found' ||
      'user-disabled' => AuthFailureReason.wrongCredentials,
      'email-already-in-use' || 'account-exists-with-different-credential' =>
        AuthFailureReason.emailInUse,
      'weak-password' => AuthFailureReason.weakPassword,
      'invalid-email' || 'missing-email' => AuthFailureReason.invalidEmail,
      'too-many-requests' => AuthFailureReason.tooManyAttempts,
      'popup-closed-by-user' ||
      'cancelled-popup-request' ||
      'user-cancelled' ||
      'web-context-canceled' => AuthFailureReason.cancelled,
      'requires-recent-login' => AuthFailureReason.requiresRecentSignIn,
      'network-request-failed' => null,
      _ => AuthFailureReason.unknown,
    };
    return reason == null
        ? NetworkFailure(message ?? code)
        : AuthFailure(reason, '$code: ${message ?? ''}');
  }

  static (String, int) _hostAndPort(String hostPort) {
    final i = hostPort.lastIndexOf(':');
    final port = i < 0 ? null : int.tryParse(hostPort.substring(i + 1));
    if (port == null) {
      throw FormatException(
        'PENNY_FIREBASE_AUTH_EMULATOR_HOST must be host:port',
        hostPort,
      );
    }
    return (hostPort.substring(0, i), port);
  }
}
