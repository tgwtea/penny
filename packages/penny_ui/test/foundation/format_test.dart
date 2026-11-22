// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny_ui/penny_ui.dart';
import 'package:penny_ui/testing.dart';

void main() {
  group('names', () {
    test('shows every name up to the limit', () {
      expect(PennyFormat.names(['Mei Lin', 'Arjun']), 'Mei Lin, Arjun');
    });

    test('counts the rest instead of truncating silently', () {
      expect(
        PennyFormat.names(['Mei', 'Arjun', 'Sofia', 'Ravi', 'Hana']),
        'Mei, Arjun +3',
      );
    });
  });

  test('firstName takes the first word', () {
    expect(PennyFormat.firstName('  Mei Lin Tan '), 'Mei');
  });

  test('dates read as the voice rules say', () {
    final thursday = DateTime(2026, 11, 19);
    expect(PennyFormat.shortDate(thursday), 'Thu 19 Nov');
    expect(PennyFormat.longDate(thursday), 'Thursday 19 November');
    expect(
      PennyFormat.weekRange(DateTime(2026, 11, 16), DateTime(2026, 11, 22)),
      '16 to 22 November',
    );
    expect(
      PennyFormat.weekRange(DateTime(2026, 11, 30), DateTime(2026, 12, 6)),
      '30 November to 6 December',
    );
    expect(PennyFormat.month(thursday), 'November 2026');
  });

  testWidgets('times follow the device 12- or 24-hour setting', (tester) async {
    final t = DateTime(2026, 11, 19, 16, 30);
    late String h24;
    late String h12;
    await tester.pumpWidget(
      pennyTestApp(
        Builder(builder: (context) => Text(h24 = PennyFormat.time(context, t))),
      ),
    );
    await tester.pumpWidget(
      pennyTestApp(
        Builder(builder: (context) => Text(h12 = PennyFormat.time(context, t))),
        use24HourTime: false,
      ),
    );
    expect(h24, '16:30');
    expect(h12, '4:30 PM');
  });
}
