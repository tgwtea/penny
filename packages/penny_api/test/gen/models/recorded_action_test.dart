// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('RecordedAction', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = RecordedAction(
        at: DateTime.utc(2024),
        action: 'lesson.completed',
        entityType: 'lesson',
        entityId: '00000000-0000-0000-0000-000000000000',
      );
      final parsed = RecordedAction.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(RecordedAction.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => RecordedAction.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
