// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentRef', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = StudentRef(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'example',
      );
      final parsed = StudentRef.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentRef.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentRef.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
