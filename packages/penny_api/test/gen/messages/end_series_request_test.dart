// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('EndSeriesRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = EndSeriesRequest(after: Date(2024, 1, 1));
      final parsed = EndSeriesRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(EndSeriesRequest.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => EndSeriesRequest.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
