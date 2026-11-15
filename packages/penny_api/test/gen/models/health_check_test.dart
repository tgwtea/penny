// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('HealthCheck', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = HealthCheck(name: 'database', status: HealthStatus.ok);
      final parsed = HealthCheck.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(HealthCheck.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => HealthCheck.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
