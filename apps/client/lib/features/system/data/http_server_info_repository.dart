import 'package:penny_api/api.dart';

import '../../../data/api_connection.dart';
import '../domain/server_info.dart';

/// Reads the server's build from `GET /v1/version`.
class HttpServerInfoRepository implements ServerInfoRepository {
  /// Creates a repository calling the API through [api].
  HttpServerInfoRepository(this._api);

  final ApiConnection _api;

  @override
  Future<ServerInfo> fetch() => _api.call((client) async {
    final v = await SystemApi(client).getVersion();
    return ServerInfo(version: v.version, commit: v.commit);
  });
}
