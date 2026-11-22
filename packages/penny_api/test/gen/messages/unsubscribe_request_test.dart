// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('UnsubscribeRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = UnsubscribeRequest();
      final parsed = UnsubscribeRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(UnsubscribeRequest.maybeFromJson(null), isNull);
    });
  });
}
