import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/student_attendance.dart';

@immutable
class CompleteLessonRequest {
  const CompleteLessonRequest({this.attendance});

  /// Converts a `Map<String, dynamic>` to a [CompleteLessonRequest].
  factory CompleteLessonRequest.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'CompleteLessonRequest',
      json,
      () => CompleteLessonRequest(
        attendance: (json['attendance'] as List?)
            ?.map<StudentAttendance>(
              (e) => StudentAttendance.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static CompleteLessonRequest? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return CompleteLessonRequest.fromJson(json);
  }

  /// Per student. Students left out are recorded as present.
  final List<StudentAttendance>? attendance;

  /// Converts a [CompleteLessonRequest] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'attendance': ?attendance?.map((e) => e.toJson()).toList()};
  }

  @override
  int get hashCode => listHash(attendance).hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompleteLessonRequest &&
        listsEqual(attendance, other.attendance);
  }
}
