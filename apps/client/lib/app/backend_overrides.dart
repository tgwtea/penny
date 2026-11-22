import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../core/env.dart';
import '../data/api_connection.dart';
import '../data/api_settings.dart';
import '../demo/demo_backend.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/data/http_session_repository.dart';
import '../features/auth/data/identity_provider.dart';
import '../features/system/application/server_info_provider.dart';
import '../features/system/data/http_server_info_repository.dart';
import '../features/team/application/team_controller.dart';
import '../features/team/data/http_team_repository.dart';

/// The composition root (ADR 012): the only place that knows both the demo
/// and the HTTP repositories exist. Screens see domain interfaces only.
///
/// Add every new repository to both branches; the contract tests in
/// test/contract/ keep the two implementations honest.
///
/// [identity] is required for the HTTP backend; main.dart starts Firebase
/// and passes it in.
List<Override> backendOverrides(
  AppConfig config, {
  IdentityProvider? identity,
  http.Client? httpClient,
}) {
  return switch (config.backend) {
    BackendKind.demo => demoOverrides(),
    BackendKind.http => httpOverrides(
      ApiSettings(
        baseUrl: config.apiBaseUrl,
        client: httpClient ?? http.Client(),
      ),
      identity:
          identity ??
          (throw ArgumentError('The http backend needs an identity provider')),
    ),
  };
}

/// Every repository against the Go API, as the person [identity] signs in.
List<Override> httpOverrides(
  ApiSettings settings, {
  required IdentityProvider identity,
}) {
  final api = ApiConnection(settings, idToken: identity.idToken);
  final session = HttpSessionRepository(identity: identity, api: api);
  return [
    sessionRepositoryProvider.overrideWithValue(session),
    authRepositoryProvider.overrideWithValue(session),
    serverInfoRepositoryProvider.overrideWithValue(
      HttpServerInfoRepository(api),
    ),
    teamRepositoryProvider.overrideWithValue(HttpTeamRepository(api)),
  ];
}
