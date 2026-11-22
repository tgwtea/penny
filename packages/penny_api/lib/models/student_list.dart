import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/student_summary.dart';

@immutable
class StudentList {
  const StudentList({required this.items, this.nextCursor});

  /// Converts a `Map<String, dynamic>` to a [StudentList].
  factory StudentList.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentList',
      json,
      () => StudentList(
        items: (json['items'] as List)
            .map<StudentSummary>(
              (e) => StudentSummary.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentList? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentList.fromJson(json);
  }

  final List<StudentSummary> items;
  final String? nextCursor;

  /// Converts a [StudentList] to a `Map<String, dynamic>`.
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
    return other is StudentList &&
        listsEqual(items, other.items) &&
        nextCursor == other.nextCursor;
  }
}
