// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationPolicyInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = CancellationPolicyInput(
        noticeHours: 0,
        lateCancellationBillable: false,
        noShowBillable: false,
      );
      final parsed = CancellationPolicyInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CancellationPolicyInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CancellationPolicyInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
