// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentRequestInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PaymentRequestInput(
        studentId: '00000000-0000-0000-0000-000000000000',
        payeeId: '00000000-0000-0000-0000-000000000000',
        dueOn: const Date(2024, 1, 1),
      );
      final parsed = PaymentRequestInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PaymentRequestInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PaymentRequestInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
