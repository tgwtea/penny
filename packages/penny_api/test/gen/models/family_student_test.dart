// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('FamilyStudent', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = FamilyStudent(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'example',
        goals: <Goal>[
          Goal(
            id: '00000000-0000-0000-0000-000000000000',
            title: 'Play Malaguena at 120 bpm',
            status: GoalStatus.active,
            createdAt: DateTime.utc(2024),
          ),
        ],
      );
      final parsed = FamilyStudent.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(FamilyStudent.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => FamilyStudent.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
