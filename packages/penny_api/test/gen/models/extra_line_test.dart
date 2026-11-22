// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('ExtraLine', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ExtraLine(description: 'example', amountCents: 1);
      final parsed = ExtraLine.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ExtraLine.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ExtraLine.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
