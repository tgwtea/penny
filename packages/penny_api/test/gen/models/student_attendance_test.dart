// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentAttendance', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = StudentAttendance(
        studentId: '00000000-0000-0000-0000-000000000000',
        attendance: Attendance.present,
      );
      final parsed = StudentAttendance.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentAttendance.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentAttendance.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
