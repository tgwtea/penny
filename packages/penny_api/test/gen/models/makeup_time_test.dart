// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('MakeupTime', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = MakeupTime(
        startsAt: DateTime.utc(2024),
        endsAt: DateTime.utc(2024),
      );
      final parsed = MakeupTime.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(MakeupTime.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => MakeupTime.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
