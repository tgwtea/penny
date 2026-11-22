// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('FamilyLessonItem', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = FamilyLessonItem(
        kind: ItemKind.task,
        body: 'example',
        done: false,
        createdAt: DateTime.utc(2024),
      );
      final parsed = FamilyLessonItem.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(FamilyLessonItem.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => FamilyLessonItem.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
