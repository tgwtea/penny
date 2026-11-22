// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('BillableLesson', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = BillableLesson(
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
      );
      final parsed = BillableLesson.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(BillableLesson.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => BillableLesson.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
