// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonLocation', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = LessonLocation(
        kind: LocationKind.inPerson,
        name: 'example',
      );
      final parsed = LessonLocation.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonLocation.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonLocation.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
