// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('GoalInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = GoalInput(title: 'example');
      final parsed = GoalInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(GoalInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => GoalInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
