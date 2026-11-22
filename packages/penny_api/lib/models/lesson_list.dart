import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/lesson.dart';

@immutable
class LessonList {
  const LessonList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [LessonList].
  factory LessonList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonList',
      json,
      () => LessonList(
        items: (json['items'] as List)
            .map<Lesson>((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonList.fromJson(json);
  }

  final List<Lesson> items;
  final String? nextCursor;

  /// Converts a [LessonList] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'nextCursor': ?nextCursor,
    };
  }

  @override
  int get hashCode => Object.hashAll([listHash(items), nextCursor]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
