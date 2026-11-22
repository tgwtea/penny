// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Voided', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = Voided(
        at: DateTime.utc(2024),
        reason: 'example',
        by: 'example',
      );
      final parsed = Voided.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Voided.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Voided.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
