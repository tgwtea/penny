// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../../core/team_time.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/lesson_providers.dart';
import '../domain/lesson.dart';
import 'lesson_form.dart';
import 'lesson_views.dart';

/// Today's lessons, in time order, with the now line between those that
/// have ended and those to come (docs/design/screens.md, "Today"). One tap
/// marks a lesson done, with Undo.
///
/// Owners of a team choose between their own lessons and everyone's;
/// teachers only ever see their own.
class TodayScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

enum _Scope { mine, everyone }

class _TodayScreenState extends ConsumerState<TodayScreen> {
  _Scope _scope = _Scope.everyone;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final team = ref.watch(activeTeamProvider);
    final now = ref.watch(clockProvider)();
    if (team == null) return const SizedBox.shrink();

    final seesTeam =
        team.can(Capability.viewTeamTimetable) && !team.isTeamOfOne;
    final scope = seesTeam ? _scope : _Scope.mine;
    final dayStart = team.time.startOfDay(now);
    final range = (
      from: dayStart,
      to: dayStart.add(const Duration(days: 1)),
      teacherId: scope == _Scope.mine ? team.membershipId : null,
      studentId: null,
    );
    final lessons = ref.watch(lessonsProvider(range));
    final canAdd = team.can(Capability.manageLessons);

    return PennyPage(
      title: 'Today',
      actions: [
        if (canAdd)
          PennyButton(
            label: 'Add lesson',
            icon: PennyIcons.addLesson,
            onPressed: () => showLessonForm(context, ref, team: team),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PennyFormat.longDate(team.time.wallClock(now)),
            style: PennyText.heading.copyWith(color: c.copperText),
          ),
          if (seesTeam) ...[
            const SizedBox(height: PennySpace.s3),
            Align(
              alignment: Alignment.centerLeft,
              child: PennySegmented<_Scope>(
                segments: const [
                  PennySegment(value: _Scope.mine, label: 'Mine'),
                  PennySegment(value: _Scope.everyone, label: 'Everyone'),
                ],
                selected: _scope,
                compact: PennyLayout.isWide(context),
                onChanged: (s) => setState(() => _scope = s),
              ),
            ),
          ],
          const SizedBox(height: PennySpace.s4),
          switch (lessons) {
            AsyncData(:final value) =>
              value.isEmpty
                  ? _NoLessons(team: team, range: range, canAdd: canAdd)
                  : _LessonList(lessons: value, team: team, now: now),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load today\'s lessons.',
              body: error is Failure ? failureText(error) : null,
              action: PennyButton(
                label: 'Retry',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.quiet,
                onPressed: () => ref.invalidate(lessonsProvider(range)),
              ),
            ),
            _ => const Column(
              children: [
                PennySkeletonRow(),
                PennySkeletonRow(),
                PennySkeletonRow(),
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _LessonList extends ConsumerWidget {
  const _LessonList({
    required this.lessons,
    required this.team,
    required this.now,
  });

  final List<Lesson> lessons;
  final ActiveTeam team;
  final DateTime now;

  Future<void> _markDone(
    BuildContext context,
    WidgetRef ref,
    Lesson lesson,
  ) async {
    final actions = ref.read(lessonActionsProvider);
    try {
      final done = await actions.complete(lesson);
      if (!context.mounted) return;
      PennySnackbar.show(
        context,
        message: 'Lesson marked done',
        onUndo: () async {
          try {
            await actions.reopen(done);
          } on Failure catch (f) {
            if (context.mounted) {
              PennySnackbar.show(context, message: failureText(f));
            }
          }
        },
      );
    } on Failure catch (f) {
      if (context.mounted) PennySnackbar.show(context, message: failureText(f));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clashing = lessons
        .where(
          (l) => l.clashes.isNotEmpty && l.status != LessonStatus.cancelled,
        )
        .toList();
    final nowIndex = lessons.indexWhere((l) => l.endsAt.isAfter(now));
    final rows = <Widget>[];
    for (final (i, l) in lessons.indexed) {
      if (i == nowIndex) rows.add(PennyNowLine(now: team.time.wallClock(now)));
      if (i > 0 && i != nowIndex) rows.add(const PennyDivider());
      rows.add(
        LessonRow(
          lesson: lessonView(l, team.time),
          now: team.time.wallClock(now),
          viewerMembershipId: team.membershipId,
          onTap: () => context.push(Paths.lesson(l.id)),
          onMarkDone: canComplete(team, l) && l.status == LessonStatus.scheduled
              ? () => _markDone(context, ref, l)
              : null,
        ),
      );
    }
    if (nowIndex < 0) rows.add(PennyNowLine(now: team.time.wallClock(now)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (clashing.isNotEmpty) ...[
          PennyNotice(
            tone: PennyNoticeTone.warning,
            title: clashing.length == 1
                ? clashText(context, clashing.first.clashes.first, team.time)
                : '${clashing.length} lessons overlap today.',
            body:
                'Clashes never block saving. Open a lesson to move it, or '
                'keep both.',
          ),
          const SizedBox(height: PennySpace.s4),
        ],
        ...rows,
      ],
    );
  }
}

/// Today is empty: say so, and when the next lesson is.
class _NoLessons extends ConsumerWidget {
  const _NoLessons({
    required this.team,
    required this.range,
    required this.canAdd,
  });

  final ActiveTeam team;
  final LessonRange range;
  final bool canAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(
      lessonsProvider((
        from: range.to,
        to: range.to.add(const Duration(days: 14)),
        teacherId: range.teacherId,
        studentId: null,
      )),
    );
    final next = upcoming.value
        ?.where((l) => l.status != LessonStatus.cancelled)
        .firstOrNull;
    final body = next != null
        ? '${range.teacherId == null ? 'The team\'s' : 'Your'} next lesson is '
              '${_day(team.time, next.startsAt)} '
              'at ${PennyFormat.time(context, team.time.wallClock(next.startsAt))}.'
        : canAdd
        ? 'Lessons you add will appear here, in time order.'
        : 'Lessons the owner gives you will appear here, in time order.';
    // "Add lesson" is already the page's action.
    return PennyEmptyState(title: 'No lessons today', body: body);
  }

  /// "Friday" within the coming week, "Fri 4 Dec" after it.
  String _day(TeamTime time, DateTime at) {
    final wall = time.wallClock(at);
    final inAWeek = time.wallClock(range.from).add(const Duration(days: 7));
    return wall.isBefore(inAWeek)
        ? PennyFormat.weekday(wall)
        : PennyFormat.shortDate(wall);
  }
}
