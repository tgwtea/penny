// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/format.dart';
import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';
import 'button.dart';

/// The period a [DateNavigator] steps by.
enum DateUnit {
  /// One day.
  day,

  /// One week, Monday to Sunday.
  week,

  /// One calendar month.
  month,
}

/// Moves a schedule view by one day, week or month.
///
/// The title is the visible period. When the period contains today the title
/// is `copper-text`, the only copper in the header; otherwise a "Today"
/// button appears. Tapping the title opens a date picker.
class DateNavigator extends StatelessWidget {
  /// Creates a date navigator.
  const DateNavigator({
    super.key,
    required this.date,
    required this.unit,
    required this.today,
    required this.onChanged,
  });

  /// Any date inside the visible period.
  final DateTime date;

  /// The period shown.
  final DateUnit unit;

  /// Today in the team's timezone. Passed in so tests and screenshots are
  /// stable.
  final DateTime today;

  /// Called with a date inside the new period.
  final ValueChanged<DateTime> onChanged;

  /// The Monday starting the week that contains [d].
  static DateTime startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Whether the period containing [date] also contains [today].
  static bool periodContains(DateUnit unit, DateTime date, DateTime today) {
    return switch (unit) {
      DateUnit.day => DateUtils.isSameDay(date, today),
      DateUnit.week => DateUtils.isSameDay(
        startOfWeek(date),
        startOfWeek(today),
      ),
      DateUnit.month => DateUtils.isSameMonth(date, today),
    };
  }

  /// The title for the period containing [date].
  static String titleFor(DateUnit unit, DateTime date) {
    return switch (unit) {
      DateUnit.day => PennyFormat.longDate(date),
      DateUnit.week => PennyFormat.weekRange(
        startOfWeek(date),
        startOfWeek(date).add(const Duration(days: 6)),
      ),
      DateUnit.month => PennyFormat.month(date),
    };
  }

  DateTime _step(int direction) {
    return switch (unit) {
      DateUnit.day => DateUtils.addDaysToDate(date, direction),
      DateUnit.week => DateUtils.addDaysToDate(date, 7 * direction),
      DateUnit.month => DateUtils.addMonthsToMonthDate(
        DateTime(date.year, date.month),
        direction,
      ),
    };
  }

  String get _unitWord => switch (unit) {
    DateUnit.day => 'day',
    DateUnit.week => 'week',
    DateUnit.month => 'month',
  };

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      currentDate: today,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final containsToday = periodContains(unit, date, today);
    final title = titleFor(unit, date);

    return Row(
      children: [
        PennyIconButton(
          icon: PennyIcons.previous,
          tooltip: 'Previous $_unitWord',
          onPressed: () => onChanged(_step(-1)),
        ),
        PennyIconButton(
          icon: PennyIcons.next,
          tooltip: 'Next $_unitWord',
          onPressed: () => onChanged(_step(1)),
        ),
        const SizedBox(width: PennySpace.s1),
        Flexible(
          child: PennyPressable(
            onPressed: () => _pickDate(context),
            contentColor: c.text,
            semanticLabel: containsToday
                ? '$title, includes today. Choose a date'
                : '$title. Choose a date',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PennySpace.s2,
                vertical: PennySpace.s1,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PennyText.heading.copyWith(
                  color: containsToday ? c.copperText : c.text,
                ),
              ),
            ),
          ),
        ),
        if (!containsToday) ...[
          const SizedBox(width: PennySpace.s2),
          PennyButton(
            label: 'Today',
            variant: PennyButtonVariant.secondary,
            size: PennyButtonSize.compact,
            onPressed: () => onChanged(today),
          ),
        ],
      ],
    );
  }
}
