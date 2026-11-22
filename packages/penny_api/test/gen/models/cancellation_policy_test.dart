// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationPolicy', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = CancellationPolicy(
        membershipId: '00000000-0000-0000-0000-000000000000',
        noticeHours: 0,
        lateCancellationBillable: false,
        noShowBillable: false,
        summary: 'example',
        isDefault: false,
      );
      final parsed = CancellationPolicy.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CancellationPolicy.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CancellationPolicy.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
