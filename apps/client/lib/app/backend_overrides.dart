import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;

import '../core/env.dart';
import '../data/api_settings.dart';
import '../demo/demo_backend.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/data/http_session_repository.dart';
import '../features/system/application/server_info_provider.dart';
import '../features/system/data/http_server_info_repository.dart';

/// The composition root (ADR 012): the only place that knows both the demo
/// and the HTTP repositories exist. Screens see domain interfaces only.
///
/// Add every new repository to both branches; the contract tests in
/// test/contract/ keep the two implementations honest.
List<Override> backendOverrides(AppConfig config, {http.Client? httpClient}) {
  return switch (config.backend) {
    BackendKind.demo => demoOverrides(),
    BackendKind.http => _httpOverrides(
      ApiSettings(
        baseUrl: config.apiBaseUrl,
        client: httpClient ?? http.Client(),
      ),
    ),
  };
}

List<Override> _httpOverrides(ApiSettings api) => [
  sessionRepositoryProvider.overrideWithValue(HttpSessionRepository()),
  serverInfoRepositoryProvider.overrideWithValue(HttpServerInfoRepository(api)),
];
