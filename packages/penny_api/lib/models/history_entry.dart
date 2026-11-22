import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';

@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.action,
    required this.at,
    this.actorName,
    this.before,
    this.after,
  });

  /// Converts a `Map<String, dynamic>` to a [HistoryEntry].
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'HistoryEntry',
      json,
      () => HistoryEntry(
        action: json['action'] as String,
        at: DateTime.parse(json['at'] as String),
        actorName: json['actorName'] as String?,
        before: json['before'] as Map<String, dynamic>?,
        after: json['after'] as Map<String, dynamic>?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static HistoryEntry? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return HistoryEntry.fromJson(json);
  }

  /// Example: `'lesson.completed'`
  final String action;
  final DateTime at;

  /// Absent for changes Penny made itself.
  final String? actorName;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  /// Converts a [HistoryEntry] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'at': at.toUtc().toIso8601String(),
      'actorName': ?actorName,
      'before': ?before,
      'after': ?after,
    };
  }

  @override
  int get hashCode =>
      Object.hashAll([action, at, actorName, mapHash(before), mapHash(after)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HistoryEntry &&
        action == other.action &&
        at == other.at &&
        actorName == other.actorName &&
        mapsEqual(before, other.before) &&
        mapsEqual(after, other.after);
  }
}
