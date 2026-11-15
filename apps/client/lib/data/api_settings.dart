import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What every HTTP repository needs to reach the API. Built once by the
/// composition root (app/backend_overrides.dart) and shared, so all
/// repositories use one connection pool.
@immutable
class ApiSettings {
  /// Creates settings for the API at [baseUrl].
  const ApiSettings({required this.baseUrl, required this.client});

  /// The API's address, such as https://api.example.com.
  final Uri baseUrl;

  /// The HTTP client; tests pass a fake.
  final http.Client client;
}
