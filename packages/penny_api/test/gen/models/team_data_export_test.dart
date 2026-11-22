// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('TeamDataExport', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = TeamDataExport(
        membershipId: '00000000-0000-0000-0000-000000000000',
        teamId: '00000000-0000-0000-0000-000000000000',
        teamName: 'example',
        role: MembershipRole.owner,
        displayName: 'example',
        email: 'example',
        cancellationPolicies: <CancellationPolicy>[
          CancellationPolicy(
            membershipId: '00000000-0000-0000-0000-000000000000',
            noticeHours: 0,
            lateCancellationBillable: false,
            noShowBillable: false,
            summary: 'example',
            isDefault: false,
          ),
        ],
      );
      final parsed = TeamDataExport.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(TeamDataExport.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => TeamDataExport.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
