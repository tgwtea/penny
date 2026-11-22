import 'package:flutter/foundation.dart';

/// Signing in and out and looking after the account (ADR 004).
///
/// Every method throws an AuthFailure (core/failure.dart) when the identity
/// provider refuses, and a NetworkFailure when it cannot be reached. The
/// resulting session arrives through SessionRepository.changes.
abstract interface class AuthRepository {
  /// The ways this build lets people in.
  SignInMethods get methods;

  /// Signs in with an email address and password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Creates an account and sends the verification email.
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  });

  /// Signs in with Google. Google accounts arrive verified.
  Future<void> signInWithGoogle();

  /// Signs in as one of [SignInMethods.personas].
  Future<void> signInAsPersona(String personaId);

  /// Sends the verification email again.
  Future<void> resendVerificationEmail();

  /// Checks whether the person has clicked the verification link yet.
  Future<void> checkVerification();

  /// Sends a password reset email. Succeeds whether or not an account
  /// exists, so the screen cannot be used to discover accounts.
  Future<void> sendPasswordReset(String email);

  /// Signs out.
  Future<void> signOut();

  /// Deletes the account: Penny's record first, then the sign-in.
  Future<void> deleteAccount();
}

/// What a sign-in screen should offer.
@immutable
class SignInMethods {
  /// Creates the set.
  const SignInMethods({
    this.emailPassword = false,
    this.google = false,
    this.personas = const [],
  });

  /// Email address and password, with account creation and reset.
  final bool emailPassword;

  /// Continue with Google.
  final bool google;

  /// People a demo can be viewed as (PRD R2). Empty outside demo builds.
  final List<SignInPersona> personas;
}

/// One person a demo can be viewed as.
@immutable
class SignInPersona {
  /// Creates a persona.
  const SignInPersona({
    required this.id,
    required this.name,
    required this.description,
  });

  /// Passed to AuthRepository.signInAsPersona.
  final String id;

  /// "Daniel Koh".
  final String name;

  /// "Studio owner, 8 tutors".
  final String description;
}
