// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('HistoryList', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = HistoryList(
        items: <HistoryEntry>[
          HistoryEntry(action: 'lesson.completed', at: DateTime.utc(2024)),
        ],
      );
      final parsed = HistoryList.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(HistoryList.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => HistoryList.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
