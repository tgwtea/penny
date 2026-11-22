// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('SeriesChanges', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = SeriesChanges(from: const Date(2024, 1, 1));
      final parsed = SeriesChanges.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(SeriesChanges.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => SeriesChanges.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
