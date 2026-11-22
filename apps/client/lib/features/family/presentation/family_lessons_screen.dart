// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../../core/team_time.dart';
import '../../lessons/domain/lesson.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/failure_text.dart';
import '../../students/domain/student.dart';
import '../application/family_providers.dart';
import '../domain/family.dart';

/// A family account's home (docs/design/screens.md, "Family lessons"): the
/// lessons coming up and just past for a student, or a parent's children,
/// read-only, with the notes the team meant for them and the students'
/// goals (ADR 025).
class FamilyLessonsScreen extends ConsumerWidget {
  /// Creates the screen.
  const FamilyLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final team = ref.watch(activeTeamProvider);
    if (team == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider)();
    // Whole days, so the range is the same all day and loads once.
    final today = team.time.startOfDay(now);
    final range = (
      from: today.subtract(const Duration(days: 14)),
      to: today.add(const Duration(days: 31)),
    );
    final students = ref.watch(familyStudentsProvider);
    final lessons = ref.watch(familyLessonsProvider(range));
    void retry() => ref
      ..invalidate(familyStudentsProvider)
      ..invalidate(familyLessonsProvider(range));

    final failure = students.error ?? lessons.error;
    final kids = students.value;
    final all = lessons.value;
    return PennyPage(
      title: 'Lessons',
      child: switch ((kids, all, failure)) {
        (_, _, final Object error) => PennyNotice(
          tone: PennyNoticeTone.danger,
          title: 'Couldn\'t load the lessons.',
          body: error is Failure ? failureText(error) : null,
          action: PennyButton(
            label: 'Retry',
            icon: PennyIcons.retry,
            variant: PennyButtonVariant.quiet,
            onPressed: retry,
          ),
        ),
        (final List<FamilyStudent> kids, final List<FamilyLesson> all, _) =>
          kids.isEmpty
              ? const PennyEmptyState(
                  title: 'No students linked to your account yet.',
                  body:
                      'The team links you to a student when they give you '
                      'access. Ask them if you expected to see someone here.',
                )
              : _Lessons(
                  kids: kids,
                  lessons: all,
                  now: now,
                  time: team.time,
                  textColor: c,
                ),
        _ => const Column(
          children: [
            PennySkeletonRow(),
            PennySkeletonRow(),
            PennySkeletonRow(),
          ],
        ),
      },
    );
  }
}

class _Lessons extends StatelessWidget {
  const _Lessons({
    required this.kids,
    required this.lessons,
    required this.now,
    required this.time,
    required this.textColor,
  });

  final List<FamilyStudent> kids;
  final List<FamilyLesson> lessons;
  final DateTime now;
  final TeamTime time;
  final PennyColors textColor;

  @override
  Widget build(BuildContext context) {
    final c = textColor;
    final names = {for (final k in kids) k.id: k.name};
    final coming = [
      for (final l in lessons)
        if (l.endsAt.isAfter(now)) l,
    ];
    final past = [
      for (final l in lessons.reversed)
        if (!l.endsAt.isAfter(now)) l,
    ];
    final body = PennyText.body.copyWith(color: c.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kids.length == 1
              ? '${kids.single.name}\'s lessons'
              : PennyFormat.names([for (final k in kids) k.name], max: 3),
          style: PennyText.heading.copyWith(color: c.text),
        ),
        const PennySectionHeader(title: 'Coming up'),
        if (coming.isEmpty)
          Text('No lessons booked in the next month.', style: body),
        for (final l in coming)
          _LessonEntry(
            lesson: l,
            time: time,
            names: names,
            many: kids.length > 1,
          ),
        const PennySectionHeader(title: 'Recent'),
        if (past.isEmpty)
          Text('No lessons in the last two weeks.', style: body),
        for (final l in past)
          _LessonEntry(
            lesson: l,
            time: time,
            names: names,
            many: kids.length > 1,
          ),
        for (final k in kids)
          if (k.goals.isNotEmpty) ...[
            PennySectionHeader(
              title: kids.length == 1 ? 'Goals' : '${k.name}\'s goals',
            ),
            for (final g in k.goals)
              PennyListRow(
                leading: Icon(
                  g.status == GoalStatus.achieved
                      ? PennyIcons.check
                      : PennyIcons.goal,
                  size: PennyIconSize.standard,
                  color: c.textSecondary,
                ),
                title: g.title,
                subtitle: switch (g.status) {
                  GoalStatus.active => 'Working on it',
                  GoalStatus.achieved => 'Achieved',
                  GoalStatus.dropped => 'Dropped',
                },
              ),
          ],
        const SizedBox(height: PennySpace.s6),
        Text(
          'To change or cancel a lesson, contact the team.',
          style: PennyText.small.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}

class _LessonEntry extends StatelessWidget {
  const _LessonEntry({
    required this.lesson,
    required this.time,
    required this.names,
    required this.many,
  });

  final FamilyLesson lesson;
  final TeamTime time;
  final Map<String, String> names;
  final bool many;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final l = lesson;
    final start = time.wallClock(l.startsAt);
    final others = switch (l.otherStudents) {
      0 => null,
      1 => 'and 1 other student',
      final n => 'and $n other students',
    };
    final who = [
      if (many)
        PennyFormat.names([for (final id in l.studentIds) names[id] ?? '']),
      ?others,
    ].join(' ');
    final subtitle = [
      if (l.title.isNotEmpty) l.title,
      if (l.tutors.isNotEmpty) 'with ${PennyFormat.names(l.tutors)}',
      if (l.place case final p?) p.name,
    ].join(', ');
    final badge = switch (l.status) {
      LessonStatus.completed => PennyStatus.done,
      LessonStatus.cancelled => PennyStatus.cancelled,
      LessonStatus.noShow => PennyStatus.noShow,
      LessonStatus.scheduled => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PennyListRow(
          title:
              '${PennyFormat.shortDate(start)}, '
              '${PennyFormat.timeRange(context, start, time.wallClock(l.endsAt))}',
          subtitle: [
            subtitle,
            if (who.isNotEmpty) who,
          ].where((s) => s.isNotEmpty).join('\n'),
          trailing: [?badge == null ? null : StatusBadge(badge)],
        ),
        for (final i in l.items)
          Padding(
            padding: const EdgeInsets.only(
              left: PennySpace.s4,
              bottom: PennySpace.s2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (i.kind) {
                    ItemKind.task =>
                      i.done ? PennyIcons.taskDone : PennyIcons.taskOpen,
                    ItemKind.goal => PennyIcons.goal,
                    ItemKind.note => PennyIcons.note,
                  },
                  size: PennyIconSize.standard,
                  color: c.textSecondary,
                ),
                const SizedBox(width: PennySpace.s2),
                Expanded(
                  child: Text(
                    i.body,
                    style: PennyText.body.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
