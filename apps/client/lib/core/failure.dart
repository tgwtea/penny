/// Why a repository call failed, in terms screens can act on.
///
/// Repositories throw a [Failure] and nothing else; `data/` translates
/// transport errors and API problems into these, so screens never see HTTP.
sealed class Failure implements Exception {
  const Failure(this.message);

  /// What happened, for logs. Screens choose their own words.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server could not be reached: offline, DNS, timeout.
final class NetworkFailure extends Failure {
  /// Creates a network failure.
  const NetworkFailure(super.message);
}

/// The person must sign in (again).
final class UnauthenticatedFailure extends Failure {
  /// Creates an unauthenticated failure.
  const UnauthenticatedFailure(super.message);
}

/// The person may not do this. The client hides such actions, so reaching
/// this means the client's view of permissions is stale.
final class ForbiddenFailure extends Failure {
  /// Creates a forbidden failure.
  const ForbiddenFailure(super.message, {this.detail});

  /// The server's explanation, safe to show.
  final String? detail;
}

/// The thing asked for does not exist (any more).
final class NotFoundFailure extends Failure {
  /// Creates a not-found failure.
  const NotFoundFailure(super.message);
}

/// The request clashes with how things are: someone else changed it first,
/// or it would break a rule such as "a team needs an owner".
final class ConflictFailure extends Failure {
  /// Creates a conflict failure.
  const ConflictFailure(super.message, {this.detail});

  /// The server's explanation, safe to show.
  final String? detail;
}

/// The request was rejected as invalid. [detail] is written for the person.
final class ValidationFailure extends Failure {
  /// Creates a validation failure.
  const ValidationFailure(super.message, {this.detail});

  /// The server's explanation, safe to show.
  final String? detail;
}

/// The server failed or answered in a way the client does not understand.
final class ServerFailure extends Failure {
  /// Creates a server failure.
  const ServerFailure(super.message, {this.requestId});

  /// The server's request ID, to quote when reporting the problem.
  final String? requestId;
}

/// Why signing in, signing up or changing the account failed. Screens pick
/// their own words for each [reason] (auth/presentation/auth_messages.dart).
final class AuthFailure extends Failure {
  /// Creates an auth failure.
  const AuthFailure(this.reason, [String message = '']) : super(message);

  /// What went wrong, in terms the person can act on.
  final AuthFailureReason reason;
}

/// The reasons an identity provider refuses a sign-in or account change.
enum AuthFailureReason {
  /// The email and password do not match an account.
  wrongCredentials,

  /// An account with this email already exists.
  emailInUse,

  /// The password is too easy to guess.
  weakPassword,

  /// The email address is not valid.
  invalidEmail,

  /// Too many attempts; wait before trying again.
  tooManyAttempts,

  /// The person closed the Google window before finishing.
  cancelled,

  /// Deleting the account needs a fresh sign-in first.
  requiresRecentSignIn,

  /// The provider could not be reached.
  network,

  /// Anything else.
  unknown,
}
