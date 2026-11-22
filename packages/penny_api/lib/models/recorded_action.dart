import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class RecordedAction {
  const RecordedAction({
    required this.at,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.teamId,
  });

  /// Converts a `Map<String, dynamic>` to a [RecordedAction].
  factory RecordedAction.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'RecordedAction',
      json,
      () => RecordedAction(
        at: DateTime.parse(json['at'] as String),
        teamId: json['teamId'] as String?,
        action: json['action'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static RecordedAction? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return RecordedAction.fromJson(json);
  }

  final DateTime at;
  final String? teamId;

  /// Example: `'lesson.completed'`
  final String action;

  /// Example: `'lesson'`
  final String entityType;
  final String entityId;

  /// Converts a [RecordedAction] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'at': at.toUtc().toIso8601String(),
      'teamId': ?teamId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([at, teamId, action, entityType, entityId]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordedAction &&
        at == other.at &&
        teamId == other.teamId &&
        action == other.action &&
        entityType == other.entityType &&
        entityId == other.entityId;
  }
}
