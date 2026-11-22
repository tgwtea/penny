// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarFeed', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = CalendarFeed(url: 'example');
      final parsed = CalendarFeed.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CalendarFeed.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => CalendarFeed.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
