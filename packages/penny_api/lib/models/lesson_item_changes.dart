import 'package:meta/meta.dart';
import 'package:penny_api/api_exception.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/item_visibility.dart';

@immutable
class LessonItemChanges {
  LessonItemChanges({this.body, this.done, this.visibility}) {
    body?.validate(minLength: 1, maxLength: 2000);
  }

  /// Converts a `Map<String, dynamic>` to a [LessonItemChanges].
  factory LessonItemChanges.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonItemChanges',
      json,
      () => LessonItemChanges(
        body: json['body'] as String?,
        done: json['done'] as bool?,
        visibility: ItemVisibility.maybeFromJson(json['visibility'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonItemChanges? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonItemChanges.fromJson(json);
  }

  final String? body;
  final bool? done;

  /// Who may see the item besides the team's staff: `student` items are
  /// seen by the signed-in student, `contacts` items by the student and
  /// their signed-in parents (ADR 025).
  final ItemVisibility? visibility;

  /// Converts a [LessonItemChanges] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'body': ?body, 'done': ?done, 'visibility': ?visibility?.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([body, done, visibility]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonItemChanges &&
        body == other.body &&
        done == other.done &&
        visibility == other.visibility;
  }
}
