// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../../foundation/format.dart';
import '../../foundation/icons.dart';
import '../../foundation/pressable.dart';
import '../../tokens.g.dart';
import '../button.dart';
import '../status_badge.dart';
import 'lesson_view.dart';

/// One lesson in a list, as on Today: the time spine on the left, names and
/// one meta line in the middle, Mark done on the right.
///
/// Rows sit on one `surface` separated by hairline dividers; never cards.
class LessonRow extends StatelessWidget {
  /// Creates a lesson row.
  const LessonRow({
    super.key,
    required this.lesson,
    required this.now,
    this.viewerMembershipId,
    this.onTap,
    this.onMarkDone,
  });

  /// The lesson.
  final LessonView lesson;

  /// The current time; lessons that have ended fade their start time.
  final DateTime now;

  /// The tutor viewing the list, so the meta line names the others.
  final String? viewerMembershipId;

  /// Opens the lesson.
  final VoidCallback? onTap;

  /// Marks the lesson done. Null when the viewer may not, or when the
  /// lesson is not scheduled; the button is then not shown.
  final VoidCallback? onMarkDone;

  static const double _spineWidth = 64;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final past = lesson.end.isBefore(now);
    final cancelled = lesson.status == LessonViewStatus.cancelled;
    final meta = lesson.metaLine(viewerMembershipId: viewerMembershipId);
    final badges = <PennyStatus>[
      if (lesson.status == LessonViewStatus.done) PennyStatus.done,
      if (lesson.status == LessonViewStatus.cancelled) PennyStatus.cancelled,
      if (lesson.status == LessonViewStatus.noShow) PennyStatus.noShow,
      if (lesson.hasClash && !cancelled) PennyStatus.clash,
      if (lesson.isMakeUp) PennyStatus.makeUp,
    ];
    final canMarkDone =
        onMarkDone != null && lesson.status == LessonViewStatus.scheduled;

    final IconData metaIcon =
        lesson.isShared && meta != null && meta.startsWith('Shared')
        ? PennyIcons.shared
        : lesson.location != null
        ? PennyIcons.location
        : lesson.isOnline
        ? PennyIcons.online
        : PennyIcons.makeUp;

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(
        PennySpace.s4,
        PennySpace.s3,
        PennySpace.s2,
        PennySpace.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _spineWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PennyFormat.time(context, lesson.start),
                  style: PennyText.timeLg.copyWith(
                    color: past ? c.textTertiary : c.text,
                  ),
                ),
                Text(
                  PennyFormat.time(context, lesson.end),
                  style: PennyText.caption.copyWith(
                    color: c.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PennySpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PennyFormat.names(lesson.students, max: 3),
                  style: PennyText.bodyStrong.copyWith(
                    color: cancelled ? c.textTertiary : c.text,
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (meta != null) ...[
                  const SizedBox(height: PennySpace.s1 / 2),
                  Row(
                    children: [
                      Icon(
                        metaIcon,
                        size: PennyIconSize.badge,
                        color: c.textSecondary,
                      ),
                      const SizedBox(width: PennySpace.s1),
                      Expanded(
                        child: Text(
                          meta,
                          style: PennyText.small.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: PennySpace.s2),
                  Wrap(
                    spacing: PennySpace.s1,
                    runSpacing: PennySpace.s1,
                    children: [for (final b in badges) StatusBadge(b)],
                  ),
                ],
              ],
            ),
          ),
          if (canMarkDone)
            PennyIconButton(
              icon: PennyIcons.check,
              tooltip: 'Mark done',
              onPressed: onMarkDone,
            ),
        ],
      ),
    );

    final semanticsLabel = [
      PennyFormat.timeRange(context, lesson.start, lesson.end),
      PennyFormat.names(lesson.students, max: lesson.students.length),
      ?meta,
      for (final b in badges) b.word,
    ].join(', ');

    if (onTap == null) {
      return Semantics(
        label: semanticsLabel,
        child: ExcludeSemantics(child: row),
      );
    }
    return PennyPressable(
      onPressed: onTap,
      contentColor: c.text,
      borderRadius: BorderRadius.zero,
      isButton: true,
      semanticLabel: canMarkDone ? null : semanticsLabel,
      child: canMarkDone ? Semantics(label: semanticsLabel, child: row) : row,
    );
  }
}
