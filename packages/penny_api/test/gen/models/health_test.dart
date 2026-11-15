// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Health', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Health(
        status: HealthStatus.ok,
        checks: <HealthCheck>[
          HealthCheck(name: 'database', status: HealthStatus.ok),
        ],
      );
      final parsed = Health.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Health.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Health.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
