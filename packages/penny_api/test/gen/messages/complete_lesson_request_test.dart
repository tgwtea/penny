// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('CompleteLessonRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = CompleteLessonRequest();
      final parsed = CompleteLessonRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(CompleteLessonRequest.maybeFromJson(null), isNull);
    });
  });
}
