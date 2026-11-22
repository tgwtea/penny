import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/item_kind.dart';

@immutable
class FamilyLessonItem {
  const FamilyLessonItem({
    required this.kind,
    required this.body,
    required this.done,
    required this.createdAt,
  });

  /// Converts a `Map<String, dynamic>` to a [FamilyLessonItem].
  factory FamilyLessonItem.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyLessonItem',
      json,
      () => FamilyLessonItem(
        kind: ItemKind.fromJson(json['kind'] as String),
        body: json['body'] as String,
        done: json['done'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyLessonItem? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyLessonItem.fromJson(json);
  }

  final ItemKind kind;
  final String body;
  final bool done;
  final DateTime createdAt;

  /// Converts a [FamilyLessonItem] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'kind': kind.toJson(),
      'body': body,
      'done': done,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode => Object.hashAll([kind, body, done, createdAt]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyLessonItem &&
        kind == other.kind &&
        body == other.body &&
        done == other.done &&
        createdAt == other.createdAt;
  }
}
