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

// Firebase, for the http backend (docs/runbooks/firebase-auth-setup.md).
// Without an API key the app signs in through the local Auth emulator.
const _firebaseDefines = {
  'projectId': String.fromEnvironment('PENNY_FIREBASE_PROJECT_ID'),
  'apiKey': String.fromEnvironment('PENNY_FIREBASE_API_KEY'),
  'appId': String.fromEnvironment('PENNY_FIREBASE_APP_ID'),
  'authDomain': String.fromEnvironment('PENNY_FIREBASE_AUTH_DOMAIN'),
  'messagingSenderId': String.fromEnvironment(
    'PENNY_FIREBASE_MESSAGING_SENDER_ID',
  ),
  'authEmulatorHost': String.fromEnvironment(
    'PENNY_FIREBASE_AUTH_EMULATOR_HOST',
  ),
};

/// Reads the build configuration.
///
/// Set at build time with `--dart-define`:
///
///     flutter run --dart-define=PENNY_BACKEND=http --dart-define=PENNY_API_URL=http://localhost:8080
///
/// The web image is built once and promoted between environments, so on the
/// web, values not given as dart-defines come from `config.json` next to
/// `index.html`, which the container writes at start (apps/client/Dockerfile).
Future<AppConfig> loadAppConfig({http.Client? client}) async {
  final web = kIsWeb
      ? await _webConfig(client ?? http.Client())
      : const <String, dynamic>{};
  final webFirebase = web['firebase'] is Map<String, dynamic>
      ? web['firebase'] as Map<String, dynamic>
      : const <String, dynamic>{};

  String pick(String define, Object? fromWeb) =>
      define.isNotEmpty ? define : (fromWeb is String ? fromWeb : '');
  String firebase(String key) => pick(_firebaseDefines[key]!, webFirebase[key]);

  final apiUrl = pick(_apiUrlDefine, web['apiUrl']);
  return AppConfig.parse(
    backend: _backendDefine,
    apiUrl: apiUrl.isEmpty ? _defaultApiUrl : apiUrl,
    firebase: FirebaseSettings.parse(
      projectId: firebase('projectId'),
      apiKey: firebase('apiKey'),
      appId: firebase('appId'),
      authDomain: firebase('authDomain'),
      messagingSenderId: firebase('messagingSenderId'),
      authEmulatorHost: firebase('authEmulatorHost'),
    ),
  );
}

Future<Map<String, dynamic>> _webConfig(http.Client client) async {
  try {
    final response = await client.get(Uri.base.resolve('config.json'));
    if (response.statusCode != 200) return const {};
    final json = jsonDecode(response.body);
    if (json is Map<String, dynamic>) return json;
  } on Exception {
    // No config.json, as under `flutter run -d chrome`: use the defaults.
  }
  return const {};
}
