// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('ReceiptRef', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = ReceiptRef(
        id: '00000000-0000-0000-0000-000000000000',
        number: 'R-0042',
        voided: false,
      );
      final parsed = ReceiptRef.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ReceiptRef.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ReceiptRef.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
