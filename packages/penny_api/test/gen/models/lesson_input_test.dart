// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = LessonInput(
        startsAt: DateTime.utc(2024),
        endsAt: DateTime.utc(2024),
        tutors: const <TutorInput>[
          TutorInput(
            membershipId: '00000000-0000-0000-0000-000000000000',
            role: TutorRole.lead,
          ),
        ],
        studentIds: const <String>['00000000-0000-0000-0000-000000000000'],
      );
      final parsed = LessonInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
