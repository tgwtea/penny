import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class ServerVersion {
  const ServerVersion({required this.version, required this.commit});

  /// Converts a `Map<String, dynamic>` to a [ServerVersion].
  factory ServerVersion.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'ServerVersion',
      json,
      () => ServerVersion(
        version: json['version'] as String,
        commit: json['commit'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static ServerVersion? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ServerVersion.fromJson(json);
  }

  /// The release version, or "dev" for a local build.
  /// Example: `'0.1.0'`
  final String version;

  /// The git commit the server was built from, or "unknown".
  /// Example: `'3f2c1a9'`
  final String commit;

  /// Converts a [ServerVersion] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'version': version, 'commit': commit};
  }

  @override
  int get hashCode => Object.hashAll([version, commit]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerVersion &&
        version == other.version &&
        commit == other.commit;
  }
}
