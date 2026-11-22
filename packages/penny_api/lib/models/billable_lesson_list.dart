import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/billable_lesson.dart';

@immutable
class BillableLessonList {
  const BillableLessonList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [BillableLessonList].
  factory BillableLessonList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'BillableLessonList',
      json,
      () => BillableLessonList(
        items: (json['items'] as List)
            .map<BillableLesson>(
              (e) => BillableLesson.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static BillableLessonList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return BillableLessonList.fromJson(json);
  }

  final List<BillableLesson> items;
  final String? nextCursor;

  /// Converts a [BillableLessonList] to a `Map<String, dynamic>`.
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
    return other is BillableLessonList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
