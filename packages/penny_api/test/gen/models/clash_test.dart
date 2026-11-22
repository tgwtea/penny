// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Clash', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = Clash(
        lessonId: '00000000-0000-0000-0000-000000000000',
        startsAt: DateTime.utc(2024),
        endsAt: DateTime.utc(2024),
        who: 'example',
      );
      final parsed = Clash.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Clash.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Clash.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
