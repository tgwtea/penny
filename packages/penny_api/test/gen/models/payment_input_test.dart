// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PaymentInput(
        amountCents: 1,
        paidOn: const Date(2024, 1, 1),
        method: PaymentMethod.paynow,
      );
      final parsed = PaymentInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PaymentInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PaymentInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
