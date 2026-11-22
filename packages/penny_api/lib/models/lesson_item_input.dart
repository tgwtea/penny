import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/item_kind.dart';
import 'package:penny_api/models/item_visibility.dart';

@immutable
class LessonItemInput {
  LessonItemInput({
    required this.kind,
    required this.body,
    this.visibility,
    this.goalId,
  }) {
    body.validate(minLength: 1, maxLength: 2000);
  }

  /// Converts a `Map<String, dynamic>` to a [LessonItemInput].
  factory LessonItemInput.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonItemInput',
      json,
      () => LessonItemInput(
        kind: ItemKind.fromJson(json['kind'] as String),
        body: json['body'] as String,
        visibility: ItemVisibility.maybeFromJson(json['visibility'] as String?),
        goalId: json['goalId'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonItemInput? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonItemInput.fromJson(json);
  }

  final ItemKind kind;
  final String body;

  /// Who may see the item besides the team's staff: `student` items are
  /// seen by the signed-in student, `contacts` items by the student and
  /// their signed-in parents (ADR 025).
  final ItemVisibility? visibility;
  final String? goalId;

  /// Converts a [LessonItemInput] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'kind': kind.toJson(),
      'body': body,
      'visibility': ?visibility?.toJson(),
      'goalId': ?goalId,
    };
  }

  @override
  int get hashCode => Object.hashAll([kind, body, visibility, goalId]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonItemInput &&
        kind == other.kind &&
        body == other.body &&
        visibility == other.visibility &&
        goalId == other.goalId;
  }
}
