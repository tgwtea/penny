// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Series', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Series(
        id: '00000000-0000-0000-0000-000000000000',
        startsOn: Date(2024, 1, 1),
        startTime: 'example',
        durationMinutes: 0,
        recurrence: 'example',
        timezone: 'example',
        tutors: <LessonTutor>[
          LessonTutor(
            membershipId: '00000000-0000-0000-0000-000000000000',
            displayName: 'example',
            role: TutorRole.lead,
          ),
        ],
        students: <LessonStudent>[
          LessonStudent(
            studentId: '00000000-0000-0000-0000-000000000000',
            name: 'example',
          ),
        ],
        feeCents: 0,
        currency: 'example',
        bookedUntil: Date(2024, 1, 1),
        version: 0,
      );
      final parsed = Series.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Series.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Series.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
