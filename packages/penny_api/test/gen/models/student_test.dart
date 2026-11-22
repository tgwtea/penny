// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Student', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = Student(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'example',
        archived: false,
        contacts: const <Contact>[
          Contact(
            id: '00000000-0000-0000-0000-000000000000',
            name: 'Priya Nair',
            relationship: ContactRelationship.parent,
            receivesReminders: false,
            receivesBilling: false,
          ),
        ],
        goals: <Goal>[
          Goal(
            id: '00000000-0000-0000-0000-000000000000',
            title: 'Play Malaguena at 120 bpm',
            status: GoalStatus.active,
            createdAt: DateTime.utc(2024),
          ),
        ],
      );
      final parsed = Student.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Student.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Student.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
