import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats dates and times the way the brand book's voice rules say.
///
/// Every input is already in the team's timezone; converting is the
/// caller's job. Times follow the device's 12- or 24-hour setting.
abstract final class PennyFormat {
  /// "16:30", or "4:30 PM" on a device set to 12-hour time.
  static String time(BuildContext context, DateTime t) {
    final pattern = MediaQuery.alwaysUse24HourFormatOf(context)
        ? 'HH:mm'
        : 'h:mm a';
    return DateFormat(pattern).format(t);
  }

  /// "16:30 to 17:15".
  static String timeRange(BuildContext context, DateTime start, DateTime end) =>
      '${time(context, start)} to ${time(context, end)}';

  /// "Thu 19 Nov", for tight spaces.
  static String shortDate(DateTime d) => DateFormat('EEE d MMM').format(d);

  /// "Thursday", for a day within the coming week.
  static String weekday(DateTime d) => DateFormat('EEEE').format(d);

  /// "Thursday 19 November", for titles.
  static String longDate(DateTime d) => DateFormat('EEEE d MMMM').format(d);

  /// "16 to 22 November", or "30 November to 6 December" across months.
  static String weekRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${start.day} to ${DateFormat('d MMMM').format(end)}';
    }
    return '${DateFormat('d MMMM').format(start)} to ${DateFormat('d MMMM').format(end)}';
  }

  /// "November 2026".
  static String month(DateTime d) => DateFormat('MMMM y').format(d);

  /// Joins names for a lesson, with "+N" once [max] names are shown:
  /// "Mei Lin, Arjun +3". Never truncates silently.
  static String names(List<String> names, {int max = 2}) {
    if (names.length <= max) return names.join(', ');
    return '${names.take(max).join(', ')} +${names.length - max}';
  }

  /// "S\$ 240.00": an amount of integer cents in [currency] (ISO 4217).
  /// Money is never a floating-point number before this point.
  static String money(int cents, {String currency = 'SGD'}) {
    final symbol = _currencySymbols[currency] ?? '$currency ';
    final whole = cents ~/ 100;
    final part = (cents % 100).abs().toString().padLeft(2, '0');
    final grouped = NumberFormat.decimalPattern('en').format(whole);
    return '${cents < 0 ? '-' : ''}$symbol$grouped.$part';
  }

  static const _currencySymbols = {'SGD': 'S\$ ', 'USD': 'US\$ ', 'MYR': 'RM '};

  /// "45 min", "1 h", "1 h 30 min": a lesson's length.
  static String minutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  /// The first word of a name: "Mei Lin Tan" becomes "Mei".
  static String firstName(String name) =>
      name.trim().split(RegExp(r'\s+')).first;
}
