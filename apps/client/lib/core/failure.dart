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
  const ForbiddenFailure(super.message);
}

/// The thing asked for does not exist (any more).
final class NotFoundFailure extends Failure {
  /// Creates a not-found failure.
  const NotFoundFailure(super.message);
}

/// Someone else changed it first; reload and try again.
final class ConflictFailure extends Failure {
  /// Creates a conflict failure.
  const ConflictFailure(super.message);
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
