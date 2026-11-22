// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PayeeAccountInput', () {
    test('round-trips via maybeFromJson/toJson', () {
      final instance = PayeeAccountInput(
        proxyType: ProxyType.mobile,
        proxyValue: 'example',
        displayName: 'example',
      );
      final parsed = PayeeAccountInput.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PayeeAccountInput.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PayeeAccountInput.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
