// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Member', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Member(
        id: '00000000-0000-0000-0000-000000000000',
        displayName: 'Mei Lin Tan',
        email: 'user@example.com',
        role: MembershipRole.owner,
        status: MemberStatus.active,
      );
      final parsed = Member.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Member.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Member.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
