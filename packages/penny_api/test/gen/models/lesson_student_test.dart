// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonStudent', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = LessonStudent(
        studentId: '00000000-0000-0000-0000-000000000000',
        name: 'example',
      );
      final parsed = LessonStudent.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonStudent.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonStudent.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
