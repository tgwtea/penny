import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/item_kind.dart';
import 'package:penny_api/models/item_visibility.dart';
import 'package:penny_api/models/member_ref.dart';

@immutable
class LessonItem {
  const LessonItem({
    required this.id,
    required this.kind,
    required this.body,
    required this.visibility,
    required this.done,
    required this.author,
    required this.createdAt,
    this.doneAt,
    this.goalId,
  });

  /// Converts a `Map<String, dynamic>` to a [LessonItem].
  factory LessonItem.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonItem',
      json,
      () => LessonItem(
        id: json['id'] as String,
        kind: ItemKind.fromJson(json['kind'] as String),
        body: json['body'] as String,
        visibility: ItemVisibility.fromJson(json['visibility'] as String),
        done: json['done'] as bool,
        doneAt: maybeParseDateTime(json['doneAt'] as String?),
        goalId: json['goalId'] as String?,
        author: MemberRef.fromJson(json['author'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonItem? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonItem.fromJson(json);
  }

  final String id;
  final ItemKind kind;
  final String body;

  /// Who may see the item besides the team's staff: `student` items are
  /// seen by the signed-in student, `contacts` items by the student and
  /// their signed-in parents (ADR 025).
  final ItemVisibility visibility;

  /// Ticked off. Tasks only.
  final bool done;
  final DateTime? doneAt;

  /// The student goal this item works towards.
  final String? goalId;

  /// A team member, as other records mention them.
  final MemberRef author;
  final DateTime createdAt;

  /// Converts a [LessonItem] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.toJson(),
      'body': body,
      'visibility': visibility.toJson(),
      'done': done,
      'doneAt': ?doneAt?.toUtc().toIso8601String(),
      'goalId': ?goalId,
      'author': author.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    body,
    visibility,
    done,
    doneAt,
    goalId,
    author,
    createdAt,
  ]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonItem &&
        id == other.id &&
        kind == other.kind &&
        body == other.body &&
        visibility == other.visibility &&
        done == other.done &&
        doneAt == other.doneAt &&
        goalId == other.goalId &&
        author == other.author &&
        createdAt == other.createdAt;
  }
}
