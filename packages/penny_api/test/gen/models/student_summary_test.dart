// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentSummary', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = StudentSummary(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'Arjun Nair',
        archived: false,
      );
      final parsed = StudentSummary.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentSummary.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentSummary.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
