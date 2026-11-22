// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('BillableLessonList', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = BillableLessonList(
        items: <BillableLesson>[
          BillableLesson(
            lessonId: '00000000-0000-0000-0000-000000000000',
            startsAt: DateTime.utc(2024),
            status: LessonStatus.scheduled,
            students: const <LessonStudent>[
              LessonStudent(
                studentId: '00000000-0000-0000-0000-000000000000',
                name: 'example',
              ),
            ],
            feeCents: 0,
            currency: 'example',
            payee: const MemberRef(
              membershipId: '00000000-0000-0000-0000-000000000000',
              displayName: 'example',
            ),
          ),
        ],
      );
      final parsed = BillableLessonList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(BillableLessonList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => BillableLessonList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
