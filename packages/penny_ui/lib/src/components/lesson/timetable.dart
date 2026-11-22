import 'dart:math' as math;

// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../../foundation/format.dart';
import '../../tokens.g.dart';
import '../avatar.dart';
import 'lesson_block.dart';
import 'lesson_view.dart';

/// One column of a [Timetable]: a tutor in the team day view, or a day in
/// the week view.
@immutable
class TimetableColumn {
  /// Creates a column.
  const TimetableColumn({
    required this.id,
    required this.date,
    required this.title,
    this.subtitle,
    this.personName,
    this.isToday = false,
  });

  /// Identifies the column in [TimetableEntry.columnId]: a membership ID or
  /// a date key.
  final String id;

  /// The day this column shows. Tapping a free slot reports times on it.
  final DateTime date;

  /// The tutor's name, or the day ("Thu 19").
  final String title;

  /// A short count: "4 lessons, 1 clash".
  final String? subtitle;

  /// Shows an avatar for this person beside the title.
  final String? personName;

  /// Marks today's column in week view: `copper-subtle` behind `copper-text`.
  final bool isToday;
}

/// A lesson placed in one column. A shared lesson has one entry in each of
/// its tutors' columns.
@immutable
class TimetableEntry {
  /// Creates an entry.
  const TimetableEntry({required this.columnId, required this.lesson});

  /// The [TimetableColumn.id] this lesson appears in.
  final String columnId;

  /// The lesson.
  final LessonView lesson;
}

/// A day or week of lessons on a time grid.
///
/// Free time is empty `surface`: nothing is drawn in a free slot, so "who is
/// free on Thursday at 5pm?" is answered by looking for white. Columns share
/// the width with a 120 px minimum; beyond that the grid, not the page,
/// scrolls sideways with the hour labels pinned.
class Timetable extends StatefulWidget {
  /// Creates a timetable.
  const Timetable({
    super.key,
    required this.columns,
    required this.entries,
    required this.startHour,
    required this.endHour,
    this.now,
    this.onTapLesson,
    this.onTapSlot,
  }) : assert(
         startHour >= 0 && endHour <= 24 && startHour < endHour,
         'Invalid hour range.',
       );

  /// The columns, left to right.
  final List<TimetableColumn> columns;

  /// The lessons, each placed in one column.
  final List<TimetableEntry> entries;

  /// The first hour shown, 0 to 23.
  final int startHour;

  /// The hour the grid ends at, 1 to 24.
  final int endHour;

  /// The current time. The now line is drawn only when it falls inside the
  /// hour range; pass null when the visible period does not contain today.
  final DateTime? now;

  /// Opens a lesson.
  final void Function(LessonView lesson)? onTapLesson;

  /// Called with a column and the 15-minute slot tapped in it. Null makes
  /// free slots inert (for people who may not add lessons).
  final void Function(TimetableColumn column, DateTime slotStart)? onTapSlot;

  /// The narrowest a column gets before the grid scrolls sideways.
  static const double minColumnWidth = 120;

  @override
  State<Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<Timetable> {
  static const double _hour = PennySize.timetableHour;
  static const double _gutter = PennySize.timetableGutter;
  // Room above the first hour line so its label is not clipped.
  static const double _top = PennySpace.s2;

  late final ScrollController _vertical;
  final ScrollController _bodyHorizontal = ScrollController();
  final ScrollController _headerHorizontal = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open scrolled to an hour before now, so the current lesson is in view.
    final now = widget.now;
    final initial = now == null ? 0.0 : math.max(0.0, _y(now) - _hour);
    _vertical = ScrollController(initialScrollOffset: initial);
    _bodyHorizontal.addListener(() {
      if (_headerHorizontal.hasClients) {
        _headerHorizontal.jumpTo(_bodyHorizontal.offset);
      }
    });
  }

  @override
  void dispose() {
    _vertical.dispose();
    _bodyHorizontal.dispose();
    _headerHorizontal.dispose();
    super.dispose();
  }

  double _y(DateTime t) =>
      _top + ((t.hour * 60 + t.minute) - widget.startHour * 60) / 60 * _hour;

  bool _nowVisible(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    return minutes >= widget.startHour * 60 && minutes <= widget.endHour * 60;
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final gridHeight =
        _top + (widget.endHour - widget.startHour) * _hour + _top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = math.max(1, widget.columns.length);
        final columnWidth = math.max(
          Timetable.minColumnWidth,
          (constraints.maxWidth - _gutter) / columnCount,
        );
        final gridWidth = columnWidth * columnCount;
        final now = widget.now;
        final showNow = now != null && _nowVisible(now);

        return Column(
          children: [
            // Column headers, scrolled sideways in step with the grid.
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.hairline)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: _gutter),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _headerHorizontal,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          for (final col in widget.columns)
                            SizedBox(
                              width: columnWidth,
                              child: _ColumnHeader(column: col),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _vertical,
                child: SizedBox(
                  height: gridHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _gutter,
                        height: gridHeight,
                        child: _HourLabels(
                          startHour: widget.startHour,
                          endHour: widget.endHour,
                          top: _top,
                          now: showNow ? now : null,
                          nowY: showNow ? _y(now) : null,
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _bodyHorizontal,
                          child: SingleChildScrollView(
                            controller: _bodyHorizontal,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: gridWidth,
                              height: gridHeight,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _GridPainter(
                                        hours:
                                            widget.endHour - widget.startHour,
                                        hourHeight: _hour,
                                        top: _top,
                                        columns: columnCount,
                                        columnWidth: columnWidth,
                                        line: c.hairline,
                                      ),
                                    ),
                                  ),
                                  for (
                                    var i = 0;
                                    i < widget.columns.length;
                                    i++
                                  )
                                    Positioned(
                                      left: i * columnWidth,
                                      width: columnWidth,
                                      top: 0,
                                      height: gridHeight,
                                      child: _buildColumn(
                                        widget.columns[i],
                                        columnWidth,
                                      ),
                                    ),
                                  if (showNow)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: _y(now) - _NowLine.thickness / 2,
                                      child: const IgnorePointer(
                                        child: _NowLine(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColumn(TimetableColumn column, double width) {
    final lessons = [
      for (final e in widget.entries)
        if (e.columnId == column.id) e.lesson,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final placed = _placeInLanes(lessons);
    const gap = 2.0;

    return Semantics(
      container: true,
      label: column.subtitle == null
          ? column.title
          : '${column.title}, ${column.subtitle}',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: widget.onTapSlot == null
            ? null
            : (details) => _tapSlot(column, details.localPosition.dy),
        child: Stack(
          children: [
            for (final p in placed)
              Positioned(
                top: _y(p.lesson.start),
                height: math.max(
                  LessonBlock.minHeight,
                  p.lesson.end.difference(p.lesson.start).inMinutes /
                          60 *
                          _hour -
                      gap,
                ),
                left: gap + p.lane * (width - gap) / p.lanes,
                width: (width - gap) / p.lanes - gap,
                child: LessonBlock(
                  lesson: p.lesson,
                  viewerMembershipId: column.personName == null
                      ? null
                      : column.id,
                  onTap: widget.onTapLesson == null
                      ? null
                      : () => widget.onTapLesson!(p.lesson),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _tapSlot(TimetableColumn column, double dy) {
    final minutes = ((dy - _top) / _hour * 60).floor();
    final slot = (minutes ~/ 15) * 15 + widget.startHour * 60;
    if (slot < widget.startHour * 60 || slot >= widget.endHour * 60) return;
    final d = column.date;
    widget.onTapSlot!(
      column,
      DateTime(d.year, d.month, d.day, slot ~/ 60, slot % 60),
    );
  }
}

class _Placed {
  const _Placed(this.lesson, this.lane, this.lanes);
  final LessonView lesson;
  final int lane;
  final int lanes;
}

/// Places overlapping lessons side by side. Each group of lessons that
/// overlap one another shares the column width equally. This is layout
/// only; whether an overlap is a clash is the domain's decision.
List<_Placed> _placeInLanes(List<LessonView> sorted) {
  final result = <_Placed>[];
  var group = <(LessonView, int)>[];
  var laneEnds = <DateTime>[];
  DateTime? groupEnd;

  void flush() {
    final lanes = laneEnds.length;
    for (final (lesson, lane) in group) {
      result.add(_Placed(lesson, lane, lanes));
    }
    group = [];
    laneEnds = [];
    groupEnd = null;
  }

  for (final lesson in sorted) {
    if (groupEnd != null && !lesson.start.isBefore(groupEnd!)) flush();
    var lane = laneEnds.indexWhere((end) => !lesson.start.isBefore(end));
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(lesson.end);
    } else {
      laneEnds[lane] = lesson.end;
    }
    group.add((lesson, lane));
    groupEnd = groupEnd == null || lesson.end.isAfter(groupEnd!)
        ? lesson.end
        : groupEnd;
  }
  flush();
  return result;
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.column});

  final TimetableColumn column;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Container(
      color: column.isToday ? c.copperSubtle : null,
      padding: const EdgeInsets.symmetric(
        horizontal: PennySpace.s2,
        vertical: PennySpace.s2,
      ),
      child: Row(
        children: [
          if (column.personName != null) ...[
            PennyAvatar(name: column.personName!, size: PennyAvatarSize.small),
            const SizedBox(width: PennySpace.s2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PennyText.smallStrong.copyWith(
                    color: column.isToday ? c.copperText : c.text,
                  ),
                ),
                if (column.subtitle != null)
                  Text(
                    column.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PennyText.caption.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HourLabels extends StatelessWidget {
  const _HourLabels({
    required this.startHour,
    required this.endHour,
    required this.top,
    required this.now,
    required this.nowY,
  });

  final int startHour;
  final int endHour;
  final double top;
  final DateTime? now;
  final double? nowY;

  static const double _labelHeight = 16;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final style = PennyText.caption.copyWith(
      color: c.textTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var h = startHour; h <= endHour; h++)
            Positioned(
              top:
                  top +
                  (h - startHour) * PennySize.timetableHour -
                  _labelHeight / 2,
              right: PennySpace.s2,
              child: Text(
                PennyFormat.time(context, DateTime(2000, 1, 1, h % 24)),
                style: style,
              ),
            ),
          if (now != null)
            Positioned(
              top: nowY! - _labelHeight / 2,
              right: PennySpace.s2,
              child: Container(
                color: c.surface,
                child: Text(
                  PennyFormat.time(context, now!),
                  style: style.copyWith(
                    color: c.copperText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  static const double thickness = 2;
  static const double _dot = 8;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return SizedBox(
      height: thickness,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ColoredBox(color: c.copper)),
          Positioned(
            left: -_dot / 2,
            top: (thickness - _dot) / 2,
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: c.copper,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.hours,
    required this.hourHeight,
    required this.top,
    required this.columns,
    required this.columnWidth,
    required this.line,
  });

  final int hours;
  final double hourHeight;
  final double top;
  final int columns;
  final double columnWidth;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var h = 0; h <= hours; h++) {
      final y = top + h * hourHeight + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var i = 1; i < columns; i++) {
      final x = i * columnWidth + 0.5;
      canvas.drawLine(Offset(x, top), Offset(x, size.height - top), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.hours != hours ||
      old.hourHeight != hourHeight ||
      old.columns != columns ||
      old.columnWidth != columnWidth ||
      old.line != line;
}
