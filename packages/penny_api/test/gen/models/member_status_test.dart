// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('MemberStatus', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = MemberStatus.active;
      final parsed = MemberStatus.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(MemberStatus.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => MemberStatus.maybeFromJson('__invalid_enum_value__'),
        throwsFormatException,
      );
    });

    test('toString matches toJson for every value', () {
      for (final value in MemberStatus.values) {
        expect(value.toString(), equals(value.toJson()));
      }
    });

    test('fromJson round-trips every value', () {
      for (final value in MemberStatus.values) {
        expect(MemberStatus.fromJson(value.toJson()), equals(value));
      }
    });
  });
}
