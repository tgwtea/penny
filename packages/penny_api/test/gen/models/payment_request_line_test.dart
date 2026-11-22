// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentRequestLine', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = PaymentRequestLine(
        description: 'Guitar lesson, Thu 19 Nov',
        amountCents: 0,
      );
      final parsed = PaymentRequestLine.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PaymentRequestLine.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PaymentRequestLine.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
