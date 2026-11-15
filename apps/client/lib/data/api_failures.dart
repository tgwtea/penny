import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:penny_api/api.dart';

import '../core/failure.dart';

/// HTTP plumbing shared by every feature's `data/` folder.
///
/// Runs [call] and turns anything the generated client can throw into a
/// domain [Failure], so nothing above `data/` sees HTTP or generated types.
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on ApiException<Object?> catch (e) {
    // The generated client reports transport errors (no connection, TLS)
    // as status 400 with the cause in innerException; tell them apart from
    // a real 400 before reading the status.
    if (e.innerException != null) throw NetworkFailure(e.message ?? '$e');
    final body = e.body;
    throw failureFromProblem(e.code, body is Problem ? body : null);
  } on http.ClientException catch (e) {
    throw NetworkFailure(e.message);
  } on TimeoutException catch (e) {
    throw NetworkFailure(e.message ?? 'timed out');
  } on FormatException catch (e) {
    // An error page from a proxy, or a body that does not match the contract.
    throw ServerFailure('unexpected response: ${e.message}');
  }
}

/// Maps an RFC 9457 problem to a failure. Branches on the problem `type`,
/// which the contract keeps stable, falling back to the status code.
Failure failureFromProblem(int status, Problem? problem) {
  final message = problem?.title ?? 'HTTP $status';
  return switch (problem?.type) {
    'urn:penny:problem:unauthenticated' => UnauthenticatedFailure(message),
    'urn:penny:problem:forbidden' => ForbiddenFailure(message),
    'urn:penny:problem:not-found' => NotFoundFailure(message),
    'urn:penny:problem:conflict' ||
    'urn:penny:problem:precondition-failed' => ConflictFailure(message),
    'urn:penny:problem:validation' => ValidationFailure(
      message,
      detail: problem?.detail,
    ),
    _ => switch (status) {
      401 => UnauthenticatedFailure(message),
      403 => ForbiddenFailure(message),
      404 => NotFoundFailure(message),
      409 || 412 => ConflictFailure(message),
      400 || 422 => ValidationFailure(message, detail: problem?.detail),
      _ => ServerFailure(message, requestId: problem?.requestId),
    },
  };
}

/// A generated API client for [baseUrl] over [client].
ApiClient apiClientFor(Uri baseUrl, http.Client client) =>
    ApiClient(baseUri: baseUrl, client: client);
