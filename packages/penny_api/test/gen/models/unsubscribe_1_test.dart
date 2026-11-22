// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Unsubscribe1', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Unsubscribe1(
        category: EmailCategory.lessonReminders,
        teamName: 'example',
        maskedEmail: 'example',
      );
      final parsed = Unsubscribe1.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Unsubscribe1.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Unsubscribe1.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
