// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Receipt', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = Receipt(
        id: '00000000-0000-0000-0000-000000000000',
        number: 'R-0042',
        issuedAt: DateTime.utc(2024),
        amountCents: 0,
        currency: 'example',
        paidOn: const Date(2024, 1, 1),
        method: PaymentMethod.paynow,
        payee: const MemberRef(
          membershipId: '00000000-0000-0000-0000-000000000000',
          displayName: 'example',
        ),
        student: const StudentRef(
          id: '00000000-0000-0000-0000-000000000000',
          name: 'example',
        ),
        request: const ReceiptRequest(
          id: '00000000-0000-0000-0000-000000000000',
          reference: 'example',
        ),
        lines: const <PaymentRequestLine>[
          PaymentRequestLine(
            description: 'Guitar lesson, Thu 19 Nov',
            amountCents: 0,
          ),
        ],
        contentSha256: 'example',
      );
      final parsed = Receipt.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Receipt.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Receipt.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
