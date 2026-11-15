import 'package:flutter/foundation.dart';

/// Which build of the API the app is talking to.
@immutable
class ServerInfo {
  /// Creates server info.
  const ServerInfo({required this.version, required this.commit});

  /// The release version, or "dev".
  final String version;

  /// The git commit it was built from.
  final String commit;
}

/// Where [ServerInfo] comes from.
abstract interface class ServerInfoRepository {
  /// Asks the backend which build it is. Throws a Failure when it cannot.
  Future<ServerInfo> fetch();
}
