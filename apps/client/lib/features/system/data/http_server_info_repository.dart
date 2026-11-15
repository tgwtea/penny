import 'package:penny_api/api.dart';

import '../../../data/api_failures.dart';
import '../../../data/api_settings.dart';
import '../domain/server_info.dart';

/// Reads the server's build from `GET /v1/version`.
class HttpServerInfoRepository implements ServerInfoRepository {
  /// Creates a repository talking to the API in [settings].
  HttpServerInfoRepository(ApiSettings settings)
    : _api = SystemApi(apiClientFor(settings.baseUrl, settings.client));

  final SystemApi _api;

  @override
  Future<ServerInfo> fetch() => guardApiCall(() async {
    final v = await _api.getVersion();
    return ServerInfo(version: v.version, commit: v.commit);
  });
}
