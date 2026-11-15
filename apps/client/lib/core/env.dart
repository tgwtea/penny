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
  const AppConfig({required this.backend, required this.apiBaseUrl});

  /// Builds a configuration from raw values, as dart-defines or config.json
  /// supply them. Throws [FormatException] for an invalid value, so a
  /// misbuilt app fails at start instead of half-working.
  factory AppConfig.parse({required String backend, required String apiUrl}) =>
      AppConfig(
        backend: parseBackend(backend),
        apiBaseUrl: parseApiUrl(apiUrl),
      );

  /// The repositories to use.
  final BackendKind backend;

  /// Where the API is, for [BackendKind.http].
  final Uri apiBaseUrl;

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
