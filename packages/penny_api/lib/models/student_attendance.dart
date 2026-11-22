import 'package:meta/meta.dart';
import 'package:penny_api/model_helpers.dart';
import 'package:penny_api/models/attendance.dart';

@immutable
class StudentAttendance {
  const StudentAttendance({required this.studentId, required this.attendance});

  /// Converts a `Map<String, dynamic>` to a [StudentAttendance].
  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    return parseFromJson(
      'StudentAttendance',
      json,
      () => StudentAttendance(
        studentId: json['studentId'] as String,
        attendance: Attendance.fromJson(json['attendance'] as String),
      ),
    );
  }

  /// Convenience to create a nullable type from a nullable json object.
  /// Useful when parsing optional fields.
  static StudentAttendance? maybeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return StudentAttendance.fromJson(json);
  }

  final String studentId;
  final Attendance attendance;

  /// Converts a [StudentAttendance] to a `Map<String, dynamic>`.
  Map<String, dynamic> toJson() {
    return {'studentId': studentId, 'attendance': attendance.toJson()};
  }

  @override
  int get hashCode => Object.hashAll([studentId, attendance]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentAttendance &&
        studentId == other.studentId &&
        attendance == other.attendance;
  }
}
