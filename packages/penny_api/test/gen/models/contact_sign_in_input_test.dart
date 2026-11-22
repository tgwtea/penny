// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('ContactSignInInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = ContactSignInInput(canSignIn: false);
      final parsed = ContactSignInInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ContactSignInInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ContactSignInInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
