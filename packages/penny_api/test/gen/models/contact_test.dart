// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Contact', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Contact(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'Priya Nair',
        relationship: ContactRelationship.parent,
        receivesReminders: false,
        receivesBilling: false,
      );
      final parsed = Contact.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Contact.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Contact.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
