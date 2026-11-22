// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PublicPaymentRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = PublicPaymentRequest(
        teamName: 'example',
        payeeName: 'example',
        studentFirstName: 'example',
        amountCents: 0,
        currency: 'example',
        reference: 'example',
        dueOn: Date(2024, 1, 1),
        lines: <PublicPaymentLine>[
          PublicPaymentLine(description: 'example', amountCents: 0),
        ],
        status: PaymentRequestStatus.draft,
        payerConfirmed: false,
        coTaught: false,
      );
      final parsed = PublicPaymentRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PublicPaymentRequest.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PublicPaymentRequest.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
