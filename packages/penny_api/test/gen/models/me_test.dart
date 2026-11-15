// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Me', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Me(
        user: User(
          id: '00000000-0000-0000-0000-000000000000',
          email: 'user@example.com',
          displayName: 'example',
        ),
        memberships: <Membership>[
          Membership(
            id: '00000000-0000-0000-0000-000000000000',
            workspace: Workspace(
              id: '00000000-0000-0000-0000-000000000000',
              name: 'Koh Guitar Studio',
              timezone: 'Asia/Singapore',
              memberCount: 8,
            ),
            role: MembershipRole.owner,
            capabilities: <Capability>[Capability.viewOwnLessons],
          ),
        ],
      );
      final parsed = Me.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Me.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Me.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
