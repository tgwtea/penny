// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('MemberList', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = MemberList(
        items: <Member>[
          Member(
            id: '00000000-0000-0000-0000-000000000000',
            displayName: 'Mei Lin Tan',
            email: 'user@example.com',
            role: MembershipRole.owner,
            status: MemberStatus.active,
          ),
        ],
      );
      final parsed = MemberList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(MemberList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => MemberList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
