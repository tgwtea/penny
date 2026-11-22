// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../../foundation/format.dart';
import '../../foundation/icons.dart';
import '../../foundation/pressable.dart';
import '../../tokens.g.dart';
import 'lesson_view.dart';

/// A month of lessons, Monday to Sunday, one cell a day. Tapping a day
/// opens it.
///
/// On laptop each day lists its first lessons as "16:00 Arjun" on the
/// lesson's status ground, then "+2 more". On phone ([compact]) a day shows
/// how many lessons it has, and a warning when one clashes. Today's number
/// sits on `copper-subtle` in `copper-text`; days outside the month are
/// `text-tertiary`.
class MonthGrid extends StatelessWidget {
  /// Creates a month grid.
  const MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.lessonsOn,
    this.onTapDay,
    this.compact = false,
  });

  /// Any day in the month shown.
  final DateTime month;

  /// Today, in the team's timezone.
  final DateTime today;

  /// The lessons on a day, by start.
  final List<LessonView> Function(DateTime day) lessonsOn;

  /// Opens a day.
  final ValueChanged<DateTime>? onTapDay;

  /// Counts instead of lesson labels, for phone widths.
  final bool compact;

  /// The most lessons a laptop cell lists before "+N more".
  static const maxLessons = 3;

  static const double _cellHeight = 112;
  static const double _compactCellHeight = 56;

  /// The days the grid shows: whole weeks, Monday to Sunday, covering the
  /// month.
  static List<DateTime> daysFor(DateTime month) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.add(Duration(days: DateTime.sunday - last.weekday));
    return [
      for (
        var d = start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final days = daysFor(month);
    final weeks = [
      for (var i = 0; i < days.length; i += 7) days.sublist(i, i + 7),
    ];
    final side = BorderSide(color: c.hairline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final d in weeks.first)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PennySpace.s1,
                      vertical: PennySpace.s2,
                    ),
                    child: Text(
                      compact
                          ? PennyFormat.weekdayShort(d).substring(0, 1)
                          : PennyFormat.weekdayShort(d),
                      style: PennyText.caption.copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: side, left: side),
          ),
          child: Column(
            children: [
              for (final week in weeks)
                Row(
                  children: [
                    for (final d in week)
                      Expanded(
                        child: Container(
                          height: compact ? _compactCellHeight : _cellHeight,
                          decoration: BoxDecoration(
                            border: Border(right: side, bottom: side),
                          ),
                          child: _DayCell(
                            day: d,
                            inMonth: d.month == month.month,
                            isToday: DateUtils.isSameDay(d, today),
                            lessons: lessonsOn(d),
                            compact: compact,
                            onTap: onTapDay == null ? null : () => onTapDay!(d),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.lessons,
    required this.compact,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final List<LessonView> lessons;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final active = [
      for (final l in lessons)
        if (l.status != LessonViewStatus.cancelled) l,
    ];
    final clashes = active.where((l) => l.hasClash).length;
    final summary = [
      PennyFormat.longDate(day),
      if (active.isEmpty)
        'no lessons'
      else
        '${active.length} lesson${active.length == 1 ? '' : 's'}',
      if (clashes > 0) '$clashes clash${clashes == 1 ? '' : 'es'}',
    ].join(', ');
    final number = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PennySpace.s1,
        vertical: PennySpace.s1 / 2,
      ),
      decoration: isToday
          ? BoxDecoration(
              color: c.copperSubtle,
              borderRadius: BorderRadius.circular(PennyRadius.xs),
            )
          : null,
      child: Text(
        '${day.day}',
        style: PennyText.caption.copyWith(
          color: isToday
              ? c.copperText
              : inMonth
              ? c.text
              : c.textTertiary,
          fontWeight: isToday ? FontWeight.w600 : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.all(PennySpace.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          number,
          if (compact && active.isNotEmpty) ...[
            const SizedBox(height: PennySpace.s1),
            Row(
              children: [
                const SizedBox(width: PennySpace.s1),
                if (clashes > 0) ...[
                  Icon(
                    PennyIcons.warning,
                    size: PennyIconSize.badge,
                    color: c.danger,
                  ),
                  const SizedBox(width: PennySpace.s1 / 2),
                ],
                Flexible(
                  child: Text(
                    '${active.length}',
                    maxLines: 1,
                    style: PennyText.caption.copyWith(
                      color: c.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!compact) ...[
            for (final l in lessons.take(MonthGrid.maxLessons)) ...[
              const SizedBox(height: PennySpace.s1 / 2),
              _Entry(lesson: l),
            ],
            if (lessons.length > MonthGrid.maxLessons)
              Padding(
                padding: const EdgeInsets.only(
                  top: PennySpace.s1 / 2,
                  left: PennySpace.s1,
                ),
                child: Text(
                  '+${lessons.length - MonthGrid.maxLessons} more',
                  maxLines: 1,
                  style: PennyText.caption.copyWith(color: c.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );

    return Semantics(
      label: summary,
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null
          ? content
          : PennyPressable(
              onPressed: onTap,
              contentColor: c.text,
              borderRadius: BorderRadius.zero,
              minHitSize: 0,
              child: SizedBox.expand(child: content),
            ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.lesson});

  final LessonView lesson;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final cancelled = lesson.status == LessonViewStatus.cancelled;
    final clash = lesson.hasClash && !cancelled;
    final ground = switch (lesson.status) {
      LessonViewStatus.scheduled => c.inkSubtle,
      LessonViewStatus.done => c.successSubtle,
      LessonViewStatus.cancelled => c.surfaceSunken,
      LessonViewStatus.noShow => c.warningSubtle,
    };
    final names = PennyFormat.names(
      lesson.students.map(PennyFormat.firstName).toList(),
      max: 1,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: PennySpace.s1),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(PennyRadius.xs),
        border: clash ? Border.all(color: c.danger) : null,
      ),
      child: Text(
        '${PennyFormat.time(context, lesson.start)} $names',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PennyText.caption.copyWith(
          color: cancelled ? c.textTertiary : c.text,
          decoration: cancelled ? TextDecoration.lineThrough : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
