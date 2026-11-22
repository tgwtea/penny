// GENERATED — do not hand-edit.
import 'package:penny_api/api.dart';
import 'package:test/test.dart';

void main() {
  group('PayeeAccount', () {
    test('round-trips via maybeFromJson/toJson', () {
      const instance = PayeeAccount(
        membershipId: '00000000-0000-0000-0000-000000000000',
        proxyType: ProxyType.mobile,
        proxyValue: '+6591234567',
        displayName: 'example',
        sendAutomatically: false,
        verified: false,
        testPayload: 'example',
      );
      final parsed = PayeeAccount.maybeFromJson(instance.toJson())!;
      expect(parsed, equals(instance));
      expect(parsed.hashCode, equals(instance.hashCode));
    });

    test('maybeFromJson returns null on null input', () {
      expect(PayeeAccount.maybeFromJson(null), isNull);
    });

    test('maybeFromJson throws FormatException on invalid input', () {
      expect(
        () => PayeeAccount.maybeFromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
