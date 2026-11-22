import 'package:flutter/foundation.dart';

/// Which implementation of the repositories the app runs against (ADR 012).
enum BackendKind {
  /// In-memory demo data in `lib/demo/`. No server needed.
  demo,

  /// The Go API over HTTP.
  http,
}

/// How this build of the app is configured. Loaded by app/config.dart.
@immutable
class AppConfig {
  /// Creates a configuration.
  const AppConfig({
    required this.backend,
    required this.apiBaseUrl,
    this.firebase = FirebaseSettings.emulator,
  });

  /// Builds a configuration from raw values, as dart-defines or config.json
  /// supply them. Throws [FormatException] for an invalid value, so a
  /// misbuilt app fails at start instead of half-working.
  factory AppConfig.parse({
    required String backend,
    required String apiUrl,
    FirebaseSettings firebase = FirebaseSettings.emulator,
  }) => AppConfig(
    backend: parseBackend(backend),
    apiBaseUrl: parseApiUrl(apiUrl),
    firebase: firebase,
  );

  /// The repositories to use.
  final BackendKind backend;

  /// Where the API is, for [BackendKind.http].
  final Uri apiBaseUrl;

  /// The identity provider, for [BackendKind.http].
  final FirebaseSettings firebase;

  /// Parses `PENNY_BACKEND`.
  static BackendKind parseBackend(String value) {
    return BackendKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () =>
          throw FormatException('PENNY_BACKEND must be demo or http', value),
    );
  }

  /// Parses `PENNY_API_URL`, which must be an absolute http(s) URL.
  static Uri parseApiUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw FormatException(
        'PENNY_API_URL must be an http or https URL',
        value,
      );
    }
    return uri;
  }
}

/// Which Firebase project signs people in (ADR 004), and whether through
/// the local Auth emulator. See docs/runbooks/firebase-auth-setup.md.
@immutable
class FirebaseSettings {
  /// Creates settings. A real project needs every field but
  /// [authEmulatorHost]; the emulator needs only [projectId].
  const FirebaseSettings({
    required this.projectId,
    this.apiKey = '',
    this.appId = '',
    this.authDomain = '',
    this.messagingSenderId = '',
    this.authEmulatorHost,
  });

  /// Builds settings from raw values. Without an API key the app uses the
  /// local Auth emulator, as `task run:client:web` expects. Throws
  /// [FormatException] when a real project is half configured.
  factory FirebaseSettings.parse({
    String projectId = '',
    String apiKey = '',
    String appId = '',
    String authDomain = '',
    String messagingSenderId = '',
    String authEmulatorHost = '',
  }) {
    if (apiKey.isEmpty) {
      return FirebaseSettings(
        projectId: projectId.isEmpty ? emulator.projectId : projectId,
        authEmulatorHost: authEmulatorHost.isEmpty
            ? emulator.authEmulatorHost
            : authEmulatorHost,
      );
    }
    final missing = [
      if (projectId.isEmpty) 'PENNY_FIREBASE_PROJECT_ID',
      if (appId.isEmpty) 'PENNY_FIREBASE_APP_ID',
      if (authDomain.isEmpty) 'PENNY_FIREBASE_AUTH_DOMAIN',
      if (messagingSenderId.isEmpty) 'PENNY_FIREBASE_MESSAGING_SENDER_ID',
    ];
    if (missing.isNotEmpty) {
      throw FormatException(
        'Firebase is configured with an API key but without ${missing.join(', ')}',
      );
    }
    return FirebaseSettings(
      projectId: projectId,
      apiKey: apiKey,
      appId: appId,
      authDomain: authDomain,
      messagingSenderId: messagingSenderId,
      authEmulatorHost: authEmulatorHost.isEmpty ? null : authEmulatorHost,
    );
  }

  /// The local Auth emulator from compose.yaml, under its demo project.
  static const emulator = FirebaseSettings(
    projectId: 'demo-penny',
    authEmulatorHost: 'localhost:9099',
  );

  /// The Firebase project ID.
  final String projectId;

  /// The web API key. Not a secret: Firebase identifies the project by it.
  final String apiKey;

  /// The Firebase app ID.
  final String appId;

  /// The domain the Google sign-in popup runs on.
  final String authDomain;

  /// The project's sender ID, required by Firebase's options.
  final String messagingSenderId;

  /// host:port of the Auth emulator, or null for the real service.
  final String? authEmulatorHost;

  /// Whether sign-in goes to the local emulator.
  bool get usesEmulator => authEmulatorHost != null;
}
