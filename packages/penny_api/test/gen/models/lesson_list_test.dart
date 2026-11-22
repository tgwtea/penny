// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonList', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = LessonList(
        items: <Lesson>[
          Lesson(
            id: '00000000-0000-0000-0000-000000000000',
            startsAt: DateTime.utc(2024),
            endsAt: DateTime.utc(2024),
            status: LessonStatus.scheduled,
            kind: LessonKind.regular,
            tutors: const <LessonTutor>[
              LessonTutor(
                membershipId: '00000000-0000-0000-0000-000000000000',
                displayName: 'example',
                role: TutorRole.lead,
              ),
            ],
            students: const <LessonStudent>[
              LessonStudent(
                studentId: '00000000-0000-0000-0000-000000000000',
                name: 'example',
              ),
            ],
            feeCents: 0,
            currency: 'SGD',
            billable: false,
            clashes: <Clash>[
              Clash(
                lessonId: '00000000-0000-0000-0000-000000000000',
                startsAt: DateTime.utc(2024),
                endsAt: DateTime.utc(2024),
                who: 'example',
              ),
            ],
            version: 0,
          ),
        ],
      );
      final parsed = LessonList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
