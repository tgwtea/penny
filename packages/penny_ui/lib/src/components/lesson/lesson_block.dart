import 'package:flutter/material.dart';

import '../../foundation/format.dart';
import '../../foundation/icons.dart';
import '../../foundation/pressable.dart';
import '../../tokens.g.dart';
import 'lesson_view.dart';

/// One lesson placed on the timetable grid. The Timetable sizes and
/// positions it; the block fills what it is given and shows as much as fits:
/// the time range, the students, then one meta line.
///
/// Colour comes from status only, never from the person.
class LessonBlock extends StatelessWidget {
  /// Creates a lesson block.
  const LessonBlock({
    super.key,
    required this.lesson,
    this.viewerMembershipId,
    this.onTap,
  });

  /// The lesson.
  final LessonView lesson;

  /// The tutor whose column this block is in, so the meta line names the
  /// others ("Shared with Aisha").
  final String? viewerMembershipId;

  /// Opens the lesson.
  final VoidCallback? onTap;

  /// Blocks are never drawn shorter than this, even for 15-minute lessons.
  static const double minHeight = 24;

  static const double _clashEdge = 2;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final cancelled = lesson.status == LessonViewStatus.cancelled;
    final clash = lesson.hasClash && !cancelled;

    final (Color ground, Color? edge) = switch (lesson.status) {
      LessonViewStatus.scheduled => (c.inkSubtle, c.inkSubtleEdge),
      LessonViewStatus.done => (c.successSubtle, null),
      LessonViewStatus.cancelled => (c.surfaceSunken, null),
      LessonViewStatus.noShow => (c.warningSubtle, null),
    };
    final nameColor = cancelled ? c.textTertiary : c.text;
    final names = PennyFormat.names(
      lesson.students.map(PennyFormat.firstName).toList(),
    );
    final meta = lesson.metaLine(viewerMembershipId: viewerMembershipId);
    final statusIcon = switch (lesson.status) {
      LessonViewStatus.done => (PennyIcons.check, c.success),
      LessonViewStatus.noShow => (PennyIcons.noShow, c.warning),
      _ => null,
    };

    final label = [
      PennyFormat.timeRange(context, lesson.start, lesson.end),
      PennyFormat.names(lesson.students, max: lesson.students.length),
      ?meta,
      if (lesson.status == LessonViewStatus.done) 'Done',
      if (cancelled) 'Cancelled',
      if (lesson.status == LessonViewStatus.noShow) 'No-show',
      if (clash) 'Clash',
    ].join(', ');

    const radius = BorderRadius.all(Radius.circular(PennyRadius.sm));
    final block = LayoutBuilder(
      builder: (context, constraints) {
        final tall = constraints.maxHeight >= 40;
        final roomy = constraints.maxHeight >= 56;
        return Container(
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.symmetric(
            horizontal: PennySpace.s2,
            vertical: tall ? PennySpace.s1 : PennySpace.s1 / 2,
          ),
          decoration: BoxDecoration(
            color: ground,
            borderRadius: radius,
            border: clash
                ? Border.all(color: c.danger, width: _clashEdge)
                : edge == null
                ? null
                : Border.all(color: edge),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tall)
                Text(
                  PennyFormat.timeRange(context, lesson.start, lesson.end),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PennyText.caption.copyWith(
                    color: cancelled ? c.textTertiary : c.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Row(
                children: [
                  if (clash) ...[
                    Icon(
                      PennyIcons.warning,
                      size: PennyIconSize.badge,
                      color: c.danger,
                    ),
                    const SizedBox(width: PennySpace.s1),
                  ] else if (statusIcon != null) ...[
                    Icon(
                      statusIcon.$1,
                      size: PennyIconSize.badge,
                      color: statusIcon.$2,
                    ),
                    const SizedBox(width: PennySpace.s1),
                  ],
                  Expanded(
                    child: Text(
                      names,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PennyText.smallStrong.copyWith(
                        color: nameColor,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (roomy && clash)
                Text(
                  'Clash',
                  style: PennyText.caption.copyWith(
                    color: c.danger,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (roomy && meta != null)
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PennyText.caption.copyWith(color: c.textSecondary),
                ),
            ],
          ),
        );
      },
    );

    return PennyPressable(
      onPressed: onTap,
      contentColor: c.text,
      borderRadius: radius,
      semanticLabel: label,
      minHitSize: 0,
      child: block,
    );
  }
}
