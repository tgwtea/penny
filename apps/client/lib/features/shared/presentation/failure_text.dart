import '../../../core/failure.dart';

/// What to tell the person about [failure], in Penny's voice: what happened
/// and what to do, without apology (brand book, "Voice and copy").
///
/// Screens with more context, such as sign-in, choose their own words for
/// the failures they expect and fall back to this for the rest.
String failureText(Failure failure) => switch (failure) {
  NetworkFailure() =>
    'Couldn\'t reach Penny. Check your connection, then try again.',
  UnauthenticatedFailure() => 'Your sign-in has expired. Sign in again.',
  ForbiddenFailure(:final detail) =>
    detail ??
        'You can\'t do this in this team. Ask the team owner if you need to.',
  NotFoundFailure() => 'This no longer exists. It may have been removed.',
  ConflictFailure(:final detail) =>
    detail ?? 'Someone else changed this first. Reload it, then try again.',
  ValidationFailure(:final detail) =>
    detail ?? 'Check what you entered, then try again.',
  AuthFailure(:final reason) => authFailureText(reason),
  ServerFailure(:final requestId) =>
    requestId == null
        ? 'Something went wrong on Penny\'s side. Try again in a moment.'
        : 'Something went wrong on Penny\'s side. Try again in a moment. '
              'If it keeps happening, quote $requestId.',
};

/// What to tell the person when the identity provider refuses.
String authFailureText(AuthFailureReason reason) => switch (reason) {
  AuthFailureReason.wrongCredentials =>
    'That email and password don\'t match. Check them, or reset your password.',
  AuthFailureReason.emailInUse =>
    'An account with this email already exists. Sign in instead.',
  AuthFailureReason.weakPassword =>
    'Choose a stronger password: at least 8 characters, not a common word.',
  AuthFailureReason.invalidEmail =>
    'Enter an email address like name@example.com.',
  AuthFailureReason.tooManyAttempts =>
    'Too many attempts. Wait a few minutes, then try again.',
  AuthFailureReason.cancelled => 'Sign-in was cancelled.',
  AuthFailureReason.requiresRecentSignIn =>
    'For your security, sign in again, then delete your account.',
  AuthFailureReason.network =>
    'Couldn\'t reach the sign-in service. Check your connection, then try again.',
  AuthFailureReason.unknown => 'That didn\'t work. Try again.',
};
