// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('FamilyLessonList', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = FamilyLessonList(
        items: <FamilyLesson>[
          FamilyLesson(
            id: '00000000-0000-0000-0000-000000000000',
            studentIds: const <String>['00000000-0000-0000-0000-000000000000'],
            otherStudents: 0,
            startsAt: DateTime.utc(2024),
            endsAt: DateTime.utc(2024),
            status: LessonStatus.scheduled,
            tutors: const <String>['example'],
            items: <FamilyLessonItem>[
              FamilyLessonItem(
                kind: ItemKind.task,
                body: 'example',
                done: false,
                createdAt: DateTime.utc(2024),
              ),
            ],
          ),
        ],
      );
      final parsed = FamilyLessonList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(FamilyLessonList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => FamilyLessonList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
