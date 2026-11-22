// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateMemberRequest', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = UpdateMemberRequest(role: MembershipRole.owner);
      final parsed = UpdateMemberRequest.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(UpdateMemberRequest.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => UpdateMemberRequest.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
