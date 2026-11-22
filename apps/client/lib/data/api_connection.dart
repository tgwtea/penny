import 'package:penny_api/api.dart';

import 'api_failures.dart';
import 'api_settings.dart';

/// Supplies the signed-in person's ID token, or null when nobody is signed
/// in. The HTTP session repository provides it from the identity provider.
typedef IdTokenSource = Future<String?> Function();

/// The API, called as the signed-in person.
///
/// Every HTTP repository makes its calls through one shared connection
/// (built by app/backend_overrides.dart): it attaches a fresh ID token to
/// each request and turns every failure into a domain Failure, so nothing
/// above `data/` sees HTTP, tokens or generated types.
class ApiConnection {
  /// Creates a connection. Without [idToken], requests go out anonymously,
  /// which is enough for public endpoints.
  ApiConnection(this.settings, {IdTokenSource? idToken})
    : _idToken = idToken ?? _anonymous;

  /// Where the API is and the HTTP client to reach it with.
  final ApiSettings settings;

  final IdTokenSource _idToken;
  String? _token;

  /// The generated client. Its secured operations read the token cached by
  /// the call in progress.
  late final ApiClient client = ApiClient(
    baseUri: settings.baseUrl,
    client: settings.client,
    readSecret: (name) => name == _tokenSecret ? _token : null,
  );

  /// The security scheme's name in api/openapi.yaml.
  static const _tokenSecret = 'firebaseIdToken';

  static Future<String?> _anonymous() async => null;

  /// Runs [request] with a current ID token. Throws only Failures.
  Future<T> call<T>(Future<T> Function(ApiClient api) request) =>
      guardApiCall(() async {
        _token = await _idToken();
        return request(client);
      });
}
