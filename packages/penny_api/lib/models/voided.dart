import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class Voided {
  const Voided({required this.at, required this.reason, required this.by});

  /// Converts a `Map<String, dynamic>` to a [Voided].
  factory Voided.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Voided',
      json,
      () => Voided(
        at: DateTime.parse(json['at'] as String),
        reason: json['reason'] as String,
        by: json['by'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Voided? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Voided.fromJson(json);
  }

  final DateTime at;
  final String reason;
  final String by;

  /// Converts a [Voided] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'at': at.toUtc().toIso8601String(), 'reason': reason, 'by': by};
  }

  @override
  int get hashCode => Object.hashAll([at, reason, by]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Voided &&
        at == other.at &&
        reason == other.reason &&
        by == other.by;
  }
}
