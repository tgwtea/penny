// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentSignInInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = StudentSignInInput(email: 'user@example.com');
      final parsed = StudentSignInInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentSignInInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentSignInInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
