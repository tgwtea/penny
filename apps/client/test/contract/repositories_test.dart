// Runs each repository contract against every implementation: the demo
// backend, and the HTTP backend against a fake server speaking the contract
// in api/openapi.yaml.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penny/data/api_settings.dart';
import 'package:penny/demo/demo_personas.dart';
import 'package:penny/demo/demo_repositories.dart';
import 'package:penny/features/auth/data/http_session_repository.dart';
import 'package:penny/features/system/data/http_server_info_repository.dart';

import 'server_info_repository_contract.dart';
import 'session_repository_contract.dart';

/// A fake Penny API answering the contract's example responses.
MockClient fakeApi() => MockClient((request) async {
  return switch ((request.method, request.url.path)) {
    ('GET', '/v1/version') => http.Response(
      jsonEncode({'version': '0.1.0', 'commit': '3f2c1a9'}),
      200,
      headers: {'content-type': 'application/json'},
    ),
    _ => http.Response(
      jsonEncode({
        'type': 'urn:penny:problem:not-found',
        'title': 'Not found',
        'status': 404,
      }),
      404,
      headers: {'content-type': 'application/problem+json'},
    ),
  };
});

ApiSettings fakeApiSettings() => ApiSettings(
  baseUrl: Uri.parse('https://api.example.com'),
  client: fakeApi(),
);

void main() {
  serverInfoRepositoryContract(
    'DemoServerInfoRepository',
    DemoServerInfoRepository.new,
  );
  serverInfoRepositoryContract(
    'HttpServerInfoRepository',
    () => HttpServerInfoRepository(fakeApiSettings()),
  );

  for (final persona in DemoPersona.values) {
    sessionRepositoryContract(
      'DemoSessionRepository as ${persona.name}',
      () => DemoSessionRepository(persona: persona),
    );
  }
  sessionRepositoryContract('HttpSessionRepository', HttpSessionRepository.new);
}
