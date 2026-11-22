// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentRecord', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PaymentRecord(
        amountCents: 0,
        paidOn: const Date(2024, 1, 1),
        method: PaymentMethod.paynow,
        recordedBy: 'example',
        recordedAt: DateTime.utc(2024),
      );
      final parsed = PaymentRecord.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PaymentRecord.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PaymentRecord.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
