import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/lesson.dart';
import 'package:penny_api/models/member_ref.dart';

@immutable
class TimetableColumn {
  const TimetableColumn({required this.tutor, required this.lessons});

  /// Converts a `Map<String, dynamic>` to a [TimetableColumn].
  factory TimetableColumn.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'TimetableColumn',
      json,
      () => TimetableColumn(
        tutor: MemberRef.fromJson(json['tutor'] as Map<String, dynamic>),
        lessons: (json['lessons'] as List)
            .map<Lesson>((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static TimetableColumn? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return TimetableColumn.fromJson(json);
  }

  /// A team member, as other records mention them.
  final MemberRef tutor;
  final List<Lesson> lessons;

  /// Converts a [TimetableColumn] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'tutor': tutor.toJson(),
      'lessons': lessons.map((e) => e.toJson()).toList(),
    };
  }

  @override
  int get hashCode => Object.hashAll([tutor, listHash(lessons)]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimetableColumn &&
        tutor == other.tutor &&
        listsEqual(lessons, other.lessons);
  }
}
