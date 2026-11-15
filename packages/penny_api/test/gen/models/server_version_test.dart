// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('ServerVersion', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = ServerVersion(version: '0.1.0', commit: '3f2c1a9');
      final parsed = ServerVersion.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ServerVersion.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ServerVersion.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
