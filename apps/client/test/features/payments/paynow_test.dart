// The Dart PayNow encoder against the cases the server's is tested with
// (api/fixtures/paynow).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/payments/domain/paynow.dart';

void main() {
  final files =
      Directory('../../api/fixtures/paynow')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the fixtures are there', () => expect(files, isNotEmpty));

  for (final file in files) {
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    test('${file.uri.pathSegments.last}: ${fixture['name']}', () {
      final input = fixture['input'] as Map<String, dynamic>;
      final expiry = input['expiry'] as String?;
      final payload = PayNowPayload(
        type: input['proxyType'] == 'uen'
            ? PayNowProxy.uen
            : PayNowProxy.mobile,
        proxy: input['proxy'] as String,
        amountCents: (input['amountCents'] as num?)?.toInt() ?? 0,
        editable: input['editable'] as bool? ?? false,
        expiry: expiry == null || expiry.isEmpty
            ? null
            : DateTime.parse(expiry),
        merchantName: input['merchantName'] as String,
        reference: input['reference'] as String? ?? '',
      );
      expect(payload.encode(), fixture['payload']);
    });
  }

  test('the checksum is CRC-16/CCITT-FALSE', () {
    expect(crc16('123456789'), 0x29B1);
  });

  test('a proxy the server would refuse is refused', () {
    expect(
      () => const PayNowPayload(
        type: PayNowProxy.mobile,
        proxy: '91234567',
        merchantName: 'Mei Lin Tan',
      ).encode(),
      throwsArgumentError,
    );
  });
}
