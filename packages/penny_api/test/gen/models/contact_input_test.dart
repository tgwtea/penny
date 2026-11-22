// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('ContactInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = ContactInput(
        name: 'example',
        relationship: ContactRelationship.parent,
      );
      final parsed = ContactInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(ContactInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => ContactInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
