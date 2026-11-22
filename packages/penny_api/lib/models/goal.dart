import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/goal_status.dart';

/// {@template goal}
/// Something a student works towards over several lessons.
/// {@endtemplate}
@immutable
class Goal {
  /// {@macro goal}
  const Goal({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.achievedAt,
  });

  /// Converts a `Map<String, dynamic>` to a [Goal].
  factory Goal.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'Goal',
      json,
      () => Goal(
        id: json['id'] as String,
        title: json['title'] as String,
        status: GoalStatus.fromJson(json['status'] as String),
        achievedAt: maybeParseDateTime(json['achievedAt'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static Goal? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return Goal.fromJson(json);
  }

  final String id;

  /// Example: `'Play Malaguena at 120 bpm'`
  final String title;
  final GoalStatus status;
  final DateTime? achievedAt;
  final DateTime createdAt;

  /// Converts a [Goal] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.toJson(),
      'achievedAt': ?achievedAt?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([id, title, status, achievedAt, createdAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Goal &&
        id == other.id &&
        title == other.title &&
        status == other.status &&
        achievedAt == other.achievedAt &&
        createdAt == other.createdAt;
  }
}
