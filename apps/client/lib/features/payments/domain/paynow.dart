/// PayNow QR payloads, encoded the way the server encodes them
/// (services/api/internal/billing/paynow), for the demo backend: the HTTP
/// backend receives payloads from the API and only draws them.
///
/// Both encoders are pinned by the same golden cases in api/fixtures/paynow.
library;

/// How a PayNow account is addressed, with its EMVCo value.
enum PayNowProxy {
  /// A Singapore mobile number, +65 and eight digits.
  mobile(0),

  /// A business's UEN.
  uen(2);

  const PayNowProxy(this.code);

  /// The value in the payload's merchant account field.
  final int code;
}

/// One QR code's content.
class PayNowPayload {
  /// A code for [proxy] of [type]; see the fields.
  const PayNowPayload({
    required this.type,
    required this.proxy,
    required this.merchantName,
    this.amountCents = 0,
    this.editable = false,
    this.expiry,
    this.reference = '',
  });

  /// How [proxy] addresses the account.
  final PayNowProxy type;

  /// "+6591234567" or a UEN such as "201234567N".
  final String proxy;

  /// The amount in SGD cents; 0 leaves it out, for the payer to fill in.
  final int amountCents;

  /// Whether the payer may change the amount. Requests fix it.
  final bool editable;

  /// The last day the code can be paid, as a date; null for none.
  final DateTime? expiry;

  /// The payee's name, printable ASCII, at most 25 characters.
  final String merchantName;

  /// The bill reference, such as PNY-7K3Q9X.
  final String reference;

  static final _mobile = RegExp(r'^\+65[89][0-9]{7}$');
  static final _uen = RegExp(r'^[0-9A-Z]{9,10}$');
  static final _reference = RegExp(r'^[0-9A-Z-]{1,25}$');

  /// The payload string the QR code holds. Throws [ArgumentError] for a
  /// proxy, amount, reference or name the server would refuse.
  String encode() {
    final validProxy = switch (type) {
      PayNowProxy.mobile => _mobile.hasMatch(proxy),
      PayNowProxy.uen => _uen.hasMatch(proxy),
    };
    if (!validProxy) throw ArgumentError.value(proxy, 'proxy');
    if (amountCents < 0) throw ArgumentError.value(amountCents, 'amountCents');
    if (reference.isNotEmpty && !_reference.hasMatch(reference)) {
      throw ArgumentError.value(reference, 'reference');
    }
    final name = _merchantName(merchantName);
    if (name.isEmpty) throw ArgumentError.value(merchantName, 'merchantName');

    final account = StringBuffer()
      ..write(_field('00', 'SG.PAYNOW'))
      ..write(_field('01', '${type.code}'))
      ..write(_field('02', proxy))
      ..write(_field('03', editable || amountCents == 0 ? '1' : '0'));
    final e = expiry;
    if (e != null) {
      account.write(
        _field(
          '04',
          '${e.year.toString().padLeft(4, '0')}'
              '${e.month.toString().padLeft(2, '0')}'
              '${e.day.toString().padLeft(2, '0')}',
        ),
      );
    }

    final b = StringBuffer()
      ..write(_field('00', '01'))
      ..write(_field('01', '12'))
      ..write(_field('26', account.toString()))
      ..write(_field('52', '0000'))
      ..write(_field('53', '702'));
    if (amountCents > 0) {
      final cents = (amountCents % 100).toString().padLeft(2, '0');
      b.write(_field('54', '${amountCents ~/ 100}.$cents'));
    }
    b
      ..write(_field('58', 'SG'))
      ..write(_field('59', name))
      ..write(_field('60', 'Singapore'));
    if (reference.isNotEmpty) b.write(_field('62', _field('01', reference)));
    b.write('6304');
    final body = b.toString();
    return body + crc16(body).toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static String _field(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

  static String _merchantName(String s) {
    final ascii = String.fromCharCodes(
      s.trim().runes.where((r) => r >= 0x20 && r < 0x7f),
    ).trim();
    return ascii.length > 25 ? ascii.substring(0, 25).trim() : ascii;
  }
}

/// CRC-16/CCITT-FALSE (polynomial 0x1021, initial 0xFFFF), which EMVCo QR
/// codes end with.
int crc16(String s) {
  var crc = 0xFFFF;
  for (final unit in s.codeUnits) {
    crc ^= unit << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}
