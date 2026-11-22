// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('StudentList', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = StudentList(
        items: <StudentSummary>[
          StudentSummary(
            id: '00000000-0000-0000-0000-000000000000',
            name: 'Arjun Nair',
            archived: false,
          ),
        ],
      );
      final parsed = StudentList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(StudentList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => StudentList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
