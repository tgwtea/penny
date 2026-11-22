import 'package:flutter/foundation.dart';

/// The identity provider as the HTTP backend needs it (ADR 004).
///
/// FirebaseIdentityProvider is the real one; tests use a fake. Replacing
/// Firebase with another OIDC provider means writing one new implementation
/// of this interface. It lives in `data/` because it is a detail of how
/// HttpSessionRepository signs people in, not something screens know about.
///
/// Methods throw AuthFailure or NetworkFailure, like AuthRepository.
abstract interface class IdentityProvider {
  /// The signed-in account, or null.
  IdentityAccount? get currentAccount;

  /// The account after every sign-in, sign-out and [reload]. The first
  /// event arrives once a saved sign-in has been restored, or found absent.
  Stream<IdentityAccount?> get accountChanges;

  /// A current ID token for the API, or null when signed out. Refreshed by
  /// the provider when it is about to expire.
  Future<String?> idToken();

  /// Signs in with email and password.
  Future<void> signInWithEmail(String email, String password);

  /// Creates an account, sets its name and sends the verification email.
  Future<void> createAccount(String name, String email, String password);

  /// Signs in with Google.
  Future<void> signInWithGoogle();

  /// Sends the verification email again.
  Future<void> sendEmailVerification();

  /// Re-reads the account, such as its verification status, and refreshes
  /// the ID token so its claims match. Emits on [accountChanges].
  Future<void> reload();

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email);

  /// Signs out.
  Future<void> signOut();

  /// Deletes the sign-in account itself.
  Future<void> deleteAccount();
}

/// An account at the identity provider.
@immutable
class IdentityAccount {
  /// Creates an account.
  const IdentityAccount({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });

  /// The provider's ID for the person.
  final String uid;

  /// Their email address.
  final String email;

  /// Whether they have proven they own [email].
  final bool emailVerified;

  @override
  bool operator ==(Object other) =>
      other is IdentityAccount &&
      other.uid == uid &&
      other.email == email &&
      other.emailVerified == emailVerified;

  @override
  int get hashCode => Object.hash(uid, email, emailVerified);
}
