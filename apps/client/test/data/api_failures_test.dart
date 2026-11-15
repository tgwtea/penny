import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penny/data/api_settings.dart';
import 'package:penny/core/failure.dart';
import 'package:penny/features/system/data/http_server_info_repository.dart';

/// Drives the real generated client against a fake server, so the mapping
/// from HTTP to Failure is tested end to end.
HttpServerInfoRepository _repositoryAnswering(
  Future<http.Response> Function(http.Request) handler,
) {
  return HttpServerInfoRepository(
    ApiSettings(
      baseUrl: Uri.parse('https://api.example.com'),
      client: MockClient(handler),
    ),
  );
}

http.Response _problem(int status, String type, {String? detail}) =>
    http.Response(
      jsonEncode({
        'type': type,
        'title': 'Something',
        'status': status,
        'detail': ?detail,
        'requestId': 'r-1',
      }),
      status,
      headers: {'content-type': 'application/problem+json'},
    );

void main() {
  test('maps problem types to failures', () async {
    final cases = {
      _problem(401, 'urn:penny:problem:unauthenticated'):
          isA<UnauthenticatedFailure>(),
      _problem(403, 'urn:penny:problem:forbidden'): isA<ForbiddenFailure>(),
      _problem(404, 'urn:penny:problem:not-found'): isA<NotFoundFailure>(),
      _problem(412, 'urn:penny:problem:precondition-failed'):
          isA<ConflictFailure>(),
      _problem(
        400,
        'urn:penny:problem:validation',
        detail: 'Pick a later date.',
      ): isA<ValidationFailure>().having(
        (f) => f.detail,
        'detail',
        'Pick a later date.',
      ),
      _problem(500, 'urn:penny:problem:internal'): isA<ServerFailure>().having(
        (f) => f.requestId,
        'requestId',
        'r-1',
      ),
    };
    for (final MapEntry(key: response, value: matcher) in cases.entries) {
      final repo = _repositoryAnswering((_) async => response);
      await expectLater(repo.fetch(), throwsA(matcher), reason: response.body);
    }
  });

  test('an error page that is not a problem is a server failure', () async {
    final repo = _repositoryAnswering(
      (_) async => http.Response('<html>Bad gateway</html>', 502),
    );
    await expectLater(repo.fetch(), throwsA(isA<ServerFailure>()));
  });

  test('a connection failure is a network failure', () async {
    final repo = _repositoryAnswering(
      (_) async => throw http.ClientException('connection refused'),
    );
    await expectLater(repo.fetch(), throwsA(isA<NetworkFailure>()));
  });
}
