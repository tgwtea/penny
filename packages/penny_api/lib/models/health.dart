import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/health_check.dart';
import 'package:penny_api/models/health_status.dart';

@immutable
class Health {
  const Health({required this.status, required this.checks});

  /// Converts a `Map<String, dynamic>` to a [Health].
  factory Health.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Health',
      json,
      () => Health(
        status: HealthStatus.fromJson(json['status'] as String),
        checks: (json['checks'] as List)
            .map<HealthCheck>(
              (e) => HealthCheck.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Health? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Health.fromJson(json);
  }

  final HealthStatus status;

  /// One entry per dependency checked. Empty for liveness.
  final List<HealthCheck> checks;

  /// Converts a [Health] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'status': status.toJson(),
      'checks': checks.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([status, listHash(checks)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Health &&
        status == other.status &&
        listsEqual(checks, other.checks);
  }
}
