// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Cancellation', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = Cancellation(
        at: DateTime.utc(2024),
        party: CancellationParty.tutor,
        late_: false,
      );
      final parsed = Cancellation.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Cancellation.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Cancellation.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
