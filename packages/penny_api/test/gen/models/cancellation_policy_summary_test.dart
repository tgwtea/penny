// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationPolicySummary', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = CancellationPolicySummary(
        noticeHours: 0,
        lateCancellationBillable: false,
        noShowBillable: false,
        summary: 'example',
      );
      final parsed = CancellationPolicySummary.maybeFromJson(
        instance.toJson(),
      )!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CancellationPolicySummary.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CancellationPolicySummary.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
