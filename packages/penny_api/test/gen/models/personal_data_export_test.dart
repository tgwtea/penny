// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PersonalDataExport', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PersonalDataExport(
        exportedAt: DateTime.utc(2024),
        person: PersonalDataExportPerson(
          id: '00000000-0000-0000-0000-000000000000',
          email: 'example',
          displayName: 'example',
          createdAt: DateTime.utc(2024),
        ),
        teams: const <TeamDataExport>[
          TeamDataExport(
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
          ),
        ],
        actions: <RecordedAction>[
          RecordedAction(
            at: DateTime.utc(2024),
            action: 'lesson.completed',
            entityType: 'lesson',
            entityId: '00000000-0000-0000-0000-000000000000',
          ),
        ],
        actionsTruncated: false,
      );
      final parsed = PersonalDataExport.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PersonalDataExport.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PersonalDataExport.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
