// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('LessonItem', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = LessonItem(
        id: '00000000-0000-0000-0000-000000000000',
        kind: ItemKind.task,
        body: 'example',
        visibility: ItemVisibility.staff,
        done: false,
        author: const MemberRef(
          membershipId: '00000000-0000-0000-0000-000000000000',
          displayName: 'example',
        ),
        createdAt: DateTime.utc(2024),
      );
      final parsed = LessonItem.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(LessonItem.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => LessonItem.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
