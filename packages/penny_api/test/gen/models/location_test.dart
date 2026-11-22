// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Location', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Location(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'Studio room 2',
        kind: LocationKind.inPerson,
      );
      final parsed = Location.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Location.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Location.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
