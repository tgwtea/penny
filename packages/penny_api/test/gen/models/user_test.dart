// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('User', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = User(
        id: '00000000-0000-0000-0000-000000000000',
        email: 'user@example.com',
        displayName: 'example',
      );
      final parsed = User.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(User.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => User.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
