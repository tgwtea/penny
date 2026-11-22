import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/attendance.dart';

@immutable
class LessonStudent {
  const LessonStudent({
    required this.studentId,
    required this.name,
    this.attendance,
  });

  /// Converts a `Map<String, dynamic>` to a [LessonStudent].
  factory LessonStudent.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'LessonStudent',
      json,
      () => LessonStudent(
        studentId: json['studentId'] as String,
        name: json['name'] as String,
        attendance: Attendance.maybeFromJson(json['attendance'] as String?),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static LessonStudent? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LessonStudent.fromJson(json);
  }

  final String studentId;
  final String name;
  final Attendance? attendance;

  /// Converts a [LessonStudent] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'name': name,
      'attendance': ?attendance?.toJson(),
    };
  }

  @override
  int get hashCode => Object.hashAll([studentId, name, attendance]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonStudent &&
        studentId == other.studentId &&
        name == other.name &&
        attendance == other.attendance;
  }
}
