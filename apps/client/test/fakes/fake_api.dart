import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penny/data/api_connection.dart';
import 'package:penny/data/api_settings.dart';

/// A fake Penny API speaking the contract in api/openapi.yaml, kept in
/// memory. It knows only what the HTTP repositories under test need; each
/// feature adds its routes here.
class FakeApi {
  /// The signed-in person's display name, keyed by email.
  final names = <String, String>{};

  /// Teams (memberships, as /v1/me returns them) per email.
  final memberships = <String, List<Map<String, Object?>>>{};

  /// Every request, for assertions: "GET /v1/me".
  final requests = <String>[];

  /// When set, every request fails with this status.
  int? failWith;

  /// An HTTP client answering as this API.
  late final http.Client client = MockClient(_handle);

  /// A connection to this API, sending tokens from [idToken].
  ApiConnection connection({IdTokenSource? idToken}) => ApiConnection(
    ApiSettings(baseUrl: Uri.parse('https://api.example.com'), client: client),
    idToken: idToken,
  );

  Future<http.Response> _handle(http.Request request) async {
    final route = '${request.method} ${request.url.path}';
    requests.add(route);
    if (failWith != null) {
      return problem(failWith!, 'urn:penny:problem:internal');
    }
    if (route == 'GET /v1/version') {
      return json({'version': '0.1.0', 'commit': '3f2c1a9'});
    }

    final email = _emailFrom(request.headers['authorization']);
    if (email == null) {
      return problem(401, 'urn:penny:problem:unauthenticated');
    }
    switch (route) {
      case 'GET /v1/me':
        return json(_me(email));
      case 'PATCH /v1/me':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        names[email] = body['displayName'] as String;
        return json(_me(email));
      case 'DELETE /v1/me':
        names.remove(email);
        return http.Response('', 204);
    }
    return problem(404, 'urn:penny:problem:not-found');
  }

  Map<String, Object?> _me(String email) => {
    'user': {
      'id': 'user-${email.hashCode}',
      'email': email,
      'displayName': names[email] ?? email.split('@').first,
    },
    'memberships': memberships[email] ?? const [],
  };

  /// Tokens from FakeIdentityProvider look like `token-<email>-<n>`.
  static String? _emailFrom(String? header) {
    if (header == null || !header.startsWith('bearer token-')) return null;
    final rest = header.substring('bearer token-'.length);
    return rest.substring(0, rest.lastIndexOf('-'));
  }

  /// A JSON response.
  static http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  /// An RFC 9457 problem response.
  static http.Response problem(int status, String type) => http.Response(
    jsonEncode({'type': type, 'title': 'Problem', 'status': status}),
    status,
    headers: {'content-type': 'application/problem+json'},
  );

  /// A membership as /v1/me returns it.
  static Map<String, Object?> membership({
    required String teamId,
    required String teamName,
    String role = 'owner',
    int memberCount = 1,
    List<String> capabilities = const ['view_own_lessons'],
  }) => {
    'id': 'membership-$teamId',
    'workspace': {
      'id': teamId,
      'name': teamName,
      'timezone': 'Asia/Singapore',
      'memberCount': memberCount,
    },
    'role': role,
    'capabilities': capabilities,
  };
}
