// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PublicPaymentLine', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = PublicPaymentLine(
        description: 'example',
        amountCents: 0,
      );
      final parsed = PublicPaymentLine.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PublicPaymentLine.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PublicPaymentLine.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
