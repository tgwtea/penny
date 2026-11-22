// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('GoalChanges', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = GoalChanges();
      final parsed = GoalChanges.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(GoalChanges.maybeFromJson(null), isNull);
    });
  });
}
