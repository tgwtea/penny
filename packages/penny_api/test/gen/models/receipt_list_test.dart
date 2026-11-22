// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('ReceiptList', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ReceiptList(
        items: <ReceiptSummary>[
          ReceiptSummary(
            id: '00000000-0000-0000-0000-000000000000',
            number: 'example',
            issuedAt: DateTime.utc(2024),
            amountCents: 0,
            currency: 'example',
            student: const StudentRef(
              id: '00000000-0000-0000-0000-000000000000',
              name: 'example',
            ),
            payee: const MemberRef(
              membershipId: '00000000-0000-0000-0000-000000000000',
              displayName: 'example',
            ),
            voided: false,
          ),
        ],
      );
      final parsed = ReceiptList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ReceiptList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ReceiptList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
