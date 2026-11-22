// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('FamilyPaymentRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = FamilyPaymentRequest(
        teamName: 'example',
        payeeName: 'example',
        studentFirstName: 'example',
        amountCents: 0,
        currency: 'example',
        reference: 'example',
        dueOn: const Date(2024, 1, 1),
        lines: const <PublicPaymentLine>[
          PublicPaymentLine(description: 'example', amountCents: 0),
        ],
        status: PaymentRequestStatus.draft,
        payerConfirmed: false,
        coTaught: false,
        id: '00000000-0000-0000-0000-000000000000',
        student: const StudentRef(
          id: '00000000-0000-0000-0000-000000000000',
          name: 'example',
        ),
        createdAt: DateTime.utc(2024),
      );
      final parsed = FamilyPaymentRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(FamilyPaymentRequest.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => FamilyPaymentRequest.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
