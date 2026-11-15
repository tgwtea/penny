import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/env.dart';

/// `PENNY_BACKEND`: `demo` (the default) or `http`.
const _backendDefine = String.fromEnvironment(
  'PENNY_BACKEND',
  defaultValue: 'demo',
);

/// `PENNY_API_URL`: where the API is, for the http backend.
const _apiUrlDefine = String.fromEnvironment('PENNY_API_URL');

const _defaultApiUrl = 'http://localhost:8080';

/// Reads the build configuration.
///
/// Set at build time with `--dart-define`:
///
///     flutter run --dart-define=PENNY_BACKEND=http --dart-define=PENNY_API_URL=http://localhost:8080
///
/// The web image is built once and promoted between environments, so on the
/// web, without PENNY_API_URL, the address comes from `config.json` next to
/// `index.html`, which the container writes at start (apps/client/Dockerfile).
Future<AppConfig> loadAppConfig({http.Client? client}) async {
  var apiUrl = _apiUrlDefine;
  if (apiUrl.isEmpty && kIsWeb) {
    apiUrl = await _apiUrlFromWebConfig(client ?? http.Client()) ?? '';
  }
  return AppConfig.parse(
    backend: _backendDefine,
    apiUrl: apiUrl.isEmpty ? _defaultApiUrl : apiUrl,
  );
}

Future<String?> _apiUrlFromWebConfig(http.Client client) async {
  try {
    final response = await client.get(Uri.base.resolve('config.json'));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body);
    if (json is Map<String, dynamic> &&
        json['apiUrl'] is String &&
        (json['apiUrl'] as String).isNotEmpty) {
      return json['apiUrl'] as String;
    }
  } on Exception {
    // No config.json, as under `flutter run -d chrome`: use the defaults.
  }
  return null;
}
