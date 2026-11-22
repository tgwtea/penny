// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('TutorInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = TutorInput(
        membershipId: '00000000-0000-0000-0000-000000000000',
        role: TutorRole.lead,
      );
      final parsed = TutorInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(TutorInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => TutorInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
