// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Membership', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Membership(
        id: '00000000-0000-0000-0000-000000000000',
        workspace: Workspace(
          id: '00000000-0000-0000-0000-000000000000',
          name: 'Koh Guitar Studio',
          timezone: 'Asia/Singapore',
          memberCount: 8,
          reminderHours: 24,
        ),
        role: MembershipRole.owner,
        capabilities: <Capability>[Capability.viewOwnLessons],
      );
      final parsed = Membership.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Membership.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Membership.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
