// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LocationList', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = LocationList(
        items: <Location>[
          Location(
            id: '00000000-0000-0000-0000-000000000000',
            name: 'Studio room 2',
            kind: LocationKind.inPerson,
          ),
        ],
      );
      final parsed = LocationList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LocationList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LocationList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
