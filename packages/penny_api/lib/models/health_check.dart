import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/health_status.dart';

@immutable
class HealthCheck {
  const HealthCheck({required this.name, required this.status, this.detail});

  /// Converts a `Map<String, dynamic>` to a [HealthCheck].
  factory HealthCheck.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'HealthCheck',
      json,
      () => HealthCheck(
        name: json['name'] as String,
        status: HealthStatus.fromJson(json['status'] as String),
        detail: json['detail'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static HealthCheck? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return HealthCheck.fromJson(json);
  }

  /// Example: `'database'`
  final String name;
  final HealthStatus status;

  /// Why the check failed. Never contains secrets.
  final String? detail;

  /// Converts a [HealthCheck] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'name': name, 'status': status.toJson(), 'detail': ?detail};
  }

  @override
  int get hashCode => Object.hashAll([name, status, detail]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HealthCheck &&
        name == other.name &&
        status == other.status &&
        detail == other.detail;
  }
}
