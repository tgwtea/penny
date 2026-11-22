import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penny/data/api_connection.dart';
import 'package:penny/data/api_settings.dart';

import 'fake_scheduling_api.dart';

/// A fake Penny API speaking the contract in api/openapi.yaml, kept in
/// memory. It knows only what the HTTP repositories under test need; each
/// feature adds its routes here.
class FakeApi {
  /// The signed-in person's display name, keyed by email.
  final names = <String, String>{};

  /// Extra teams (memberships, as /v1/me returns them) per email, for tests
  /// that need a team without creating it through [teams].
  final memberships = <String, List<Map<String, Object?>>>{};

  /// Teams created through the API, by ID, with their members as the
  /// members routes return them.
  final teams = <String, ({String name, List<Map<String, Object?>> members})>{};
  int _seq = 0;

  /// Students, places, lessons, policies, series, the timetable and
  /// calendar links (Phase 5 and 6 routes).
  late final scheduling = FakeSchedulingApi(
    memberOf: (teamId, email) {
      final team = teams[teamId];
      if (team == null) return null;
      for (final m in team.members) {
        if (m['email'] == email && m['status'] == 'active') {
          return (id: m['id']! as String, role: m['role']! as String);
        }
      }
      return null;
    },
    nameOf: (membershipId) {
      for (final team in teams.values) {
        for (final m in team.members) {
          if (m['id'] == membershipId) return m['displayName']! as String;
        }
      }
      return '';
    },
    staffOf: (teamId) => [
      for (final m in teams[teamId]?.members ?? const <Map<String, Object?>>[])
        if (m['status'] == 'active' &&
            (m['role'] == 'owner' || m['role'] == 'teacher'))
          (
            id: m['id']! as String,
            role: m['role']! as String,
            name: m['displayName']! as String,
          ),
    ],
  );

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
    final schedulingRoute = scheduling.handle(request, email);
    if (schedulingRoute != null) return schedulingRoute;
    final teamRoute = _teamRoute(request, email);
    if (teamRoute != null) return teamRoute;
    switch (route) {
      case 'GET /v1/me':
        _claimInvitations(email);
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
      'displayName': _nameOf(email),
    },
    'memberships': [
      ...?memberships[email],
      for (final MapEntry(key: id, value: team) in teams.entries)
        for (final m in team.members)
          if (m['email'] == email && m['status'] == 'active')
            {
              'id': m['id'],
              'workspace': _workspace(id),
              'role': m['role'],
              'capabilities': m['role'] == 'owner'
                  ? const ['manage_team', 'view_team_timetable']
                  : const ['view_own_lessons'],
            },
    ],
  };

  String _nameOf(String email) => names[email] ?? email.split('@').first;

  Map<String, Object?> _workspace(String id) => {
    'id': id,
    'name': teams[id]!.name,
    'timezone': 'Asia/Singapore',
    'memberCount': teams[id]!.members
        .where((m) => m['status'] == 'active')
        .length,
  };

  /// [email]'s person signs in, which claims their invitations, as
  /// GET /v1/me does.
  void signIn(String email) => _claimInvitations(email);

  void _claimInvitations(String email) {
    for (final team in teams.values) {
      for (final m in team.members) {
        if (m['email'] == email && m['status'] == 'invited') {
          m['status'] = 'active';
          m['displayName'] = _nameOf(email);
          m['joinedAt'] = '2026-11-19T08:20:00Z';
        }
      }
    }
  }

  /// The teams routes, keeping the server's rules
  /// (services/api/internal/workspace/service.go): only owners manage, an
  /// outsider gets 404, owners come first, an email already in the team is
  /// 409, and so is leaving a team without an owner.
  http.Response? _teamRoute(http.Request request, String email) {
    final parts = request.url.pathSegments;
    if (parts.length < 2 || parts[0] != 'v1' || parts[1] != 'workspaces') {
      return null;
    }
    if (parts.length == 2 && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final id = 'team-${++_seq}';
      teams[id] = (
        name: (body['name'] as String).trim(),
        members: [
          {
            'id': 'member-${++_seq}',
            'displayName': _nameOf(email),
            'email': email,
            'role': 'owner',
            'status': 'active',
            'joinedAt': '2026-11-19T08:20:00Z',
          },
        ],
      );
      final owner = teams[id]!.members.first;
      return json({
        'id': owner['id'],
        'workspace': _workspace(id),
        'role': 'owner',
        'capabilities': const ['manage_team'],
      }, 201);
    }
    final team = parts.length > 2 ? teams[parts[2]] : null;
    final me = team?.members.where(
      (m) => m['email'] == email && m['status'] == 'active',
    );
    if (team == null || me == null || me.isEmpty) {
      return problem(404, 'urn:penny:problem:not-found');
    }
    if (me.first['role'] != 'owner') {
      return problem(
        403,
        'urn:penny:problem:forbidden',
        detail: 'Only the team owner can do this.',
      );
    }
    if (parts.length == 4 && parts[3] == 'members') {
      if (request.method == 'GET') {
        final sorted = [...team.members]
          ..sort((a, b) {
            final byRole = (a['role'] == 'owner' ? 0 : 1).compareTo(
              b['role'] == 'owner' ? 0 : 1,
            );
            return byRole != 0
                ? byRole
                : (a['displayName'] as String).toLowerCase().compareTo(
                    (b['displayName'] as String).toLowerCase(),
                  );
          });
        return json({'items': sorted});
      }
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final address = (body['email'] as String).trim().toLowerCase();
        if (team.members.any((m) => m['email'] == address)) {
          return problem(
            409,
            'urn:penny:problem:conflict',
            detail: 'Someone with this email is already in the team.',
          );
        }
        final member = <String, Object?>{
          'id': 'member-${++_seq}',
          'displayName': body['displayName'],
          'email': address,
          'role': body['role'] ?? 'teacher',
          'status': 'invited',
        };
        team.members.add(member);
        return json(member, 201);
      }
    }
    if (parts.length == 5 && parts[3] == 'members') {
      final target = team.members.where((m) => m['id'] == parts[4]);
      if (target.isEmpty) return problem(404, 'urn:penny:problem:not-found');
      final member = target.first;
      final owners = team.members
          .where((m) => m['role'] == 'owner' && m['status'] == 'active')
          .length;
      final lastOwner =
          member['role'] == 'owner' &&
          member['status'] == 'active' &&
          owners <= 1;
      final body = request.method == 'PATCH'
          ? jsonDecode(request.body) as Map<String, dynamic>
          : const <String, dynamic>{};
      final demoting = request.method == 'PATCH' && body['role'] != 'owner';
      if (lastOwner && (request.method == 'DELETE' || demoting)) {
        return problem(
          409,
          'urn:penny:problem:conflict',
          detail: 'A team needs an owner. Make someone else an owner first.',
        );
      }
      if (request.method == 'DELETE') {
        team.members.remove(member);
        return http.Response('', 204);
      }
      if (request.method == 'PATCH') {
        member['role'] = body['role'];
        return json(member);
      }
    }
    return problem(404, 'urn:penny:problem:not-found');
  }

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
  static http.Response problem(int status, String type, {String? detail}) =>
      http.Response(
        jsonEncode({
          'type': type,
          'title': 'Problem',
          'status': status,
          'detail': ?detail,
        }),
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
