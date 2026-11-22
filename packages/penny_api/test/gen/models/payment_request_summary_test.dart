// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentRequestSummary', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PaymentRequestSummary(
        id: '00000000-0000-0000-0000-000000000000',
        reference: 'PNY-7K3Q9X',
        student: const StudentRef(
          id: '00000000-0000-0000-0000-000000000000',
          name: 'example',
        ),
        payee: const MemberRef(
          membershipId: '00000000-0000-0000-0000-000000000000',
          displayName: 'example',
        ),
        amountCents: 0,
        currency: 'example',
        dueOn: const Date(2024, 1, 1),
        status: PaymentRequestStatus.draft,
        overdue: false,
        createdAt: DateTime.utc(2024),
      );
      final parsed = PaymentRequestSummary.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PaymentRequestSummary.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PaymentRequestSummary.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
