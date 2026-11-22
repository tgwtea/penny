// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('Workspace', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = Workspace(
        id: '00000000-0000-0000-0000-000000000000',
        name: 'Koh Guitar Studio',
        timezone: 'Asia/Singapore',
        memberCount: 8,
        reminderHours: 24,
      );
      final parsed = Workspace.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(Workspace.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => Workspace.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
