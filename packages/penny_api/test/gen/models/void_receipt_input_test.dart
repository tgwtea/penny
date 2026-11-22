// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('VoidReceiptInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = VoidReceiptInput(reason: 'example');
      final parsed = VoidReceiptInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(VoidReceiptInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => VoidReceiptInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
