// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonItemInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = LessonItemInput(kind: ItemKind.task, body: 'example');
      final parsed = LessonItemInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonItemInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonItemInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
