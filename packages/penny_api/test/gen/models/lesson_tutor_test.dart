// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonTutor', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = LessonTutor(
        membershipId: '00000000-0000-0000-0000-000000000000',
        displayName: 'example',
        role: TutorRole.lead,
      );
      final parsed = LessonTutor.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonTutor.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonTutor.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
