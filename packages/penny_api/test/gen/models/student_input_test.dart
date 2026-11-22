// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = StudentInput(name: 'example');
      final parsed = StudentInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
