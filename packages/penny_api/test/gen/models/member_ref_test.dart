// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('MemberRef', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = MemberRef(
        membershipId: '00000000-0000-0000-0000-000000000000',
        displayName: 'example',
      );
      final parsed = MemberRef.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(MemberRef.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => MemberRef.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
