import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/family_lesson.dart';

@immutable
class FamilyLessonList {
  const FamilyLessonList({required this.items});

  /// Converts a `Map<String, dynamic>` to a [FamilyLessonList].
  factory FamilyLessonList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'FamilyLessonList',
      json,
      () => FamilyLessonList(
        items: (json['items'] as List)
            .map<FamilyLesson>(
              (e) => FamilyLesson.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static FamilyLessonList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return FamilyLessonList.fromJson(json);
  }

  final List<FamilyLesson> items;

  /// Converts a [FamilyLessonList] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'items': items.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(items).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyLessonList && listsEqual(items, other.items);
  }
}
