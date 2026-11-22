// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../shared/application/active_team.dart';
import '../../shared/presentation/back_link.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/lesson_providers.dart';
import '../domain/lesson.dart';
import '../domain/location.dart';
import '../domain/series.dart';
import 'cancel_lesson_form.dart';
import 'lesson_form.dart';
import 'lesson_item_form.dart';
import 'lesson_views.dart';
import 'series_views.dart';

/// One lesson (docs/design/screens.md, "Lesson details"): when and where,
/// who teaches and who attends, what may be done with it, its tasks, goals
/// and notes, the lead tutor's cancellation policy and its history.
class LessonDetailsScreen extends ConsumerWidget {
  /// Creates the screen for [lessonId].
  const LessonDetailsScreen({super.key, required this.lessonId});

  /// The lesson.
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(activeTeamProvider);
    final lesson = ref.watch(lessonDetailProvider(lessonId));
    if (team == null) return const SizedBox.shrink();
    return PennyPage(
      title: 'Lesson',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(fallback: Paths.today),
          const SizedBox(height: PennySpace.s2),
          switch (lesson) {
            AsyncData(:final value) => _Details(lesson: value, team: team),
            AsyncError(:final error) =>
              error is NotFoundFailure
                  ? PennyEmptyState(
                      title: 'This lesson does not exist.',
                      body: 'It may have been removed, or be another tutor\'s.',
                      action: PennyButton(
                        label: 'Go to Today',
                        onPressed: () => context.go(Paths.today),
                      ),
                    )
                  : PennyNotice(
                      tone: PennyNoticeTone.danger,
                      title: 'Couldn\'t load this lesson.',
                      body: error is Failure ? failureText(error) : null,
                      action: PennyButton(
                        label: 'Retry',
                        icon: PennyIcons.retry,
                        variant: PennyButtonVariant.quiet,
                        onPressed: () =>
                            ref.invalidate(lessonDetailProvider(lessonId)),
                      ),
                    ),
            _ => const Column(
              children: [PennySkeletonRow(), PennySkeletonRow()],
            ),
          },
        ],
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.lesson, required this.team});

  final Lesson lesson;
  final ActiveTeam team;

  /// Runs a lesson change and says how it went. A stale version reloads
  /// the lesson, so the person sees what changed before trying again.
  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<Object?> Function() change,
    String done, {
    Future<void> Function(Object? result)? undo,
  }) async {
    try {
      final result = await change();
      if (!context.mounted) return;
      PennySnackbar.show(
        context,
        message: done,
        onUndo: undo == null ? null : () => undo(result),
      );
    } on Failure catch (f) {
      if (f is ConflictFailure) ref.invalidate(lessonDetailProvider(lesson.id));
      if (context.mounted) PennySnackbar.show(context, message: failureText(f));
    }
  }

  /// Reschedules the lesson, or, for a lesson that repeats, first asks
  /// whether the change is to it alone or to the series from a day on.
  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final seriesId = lesson.seriesId;
    if (seriesId == null) {
      return showLessonForm(context, ref, team: team, lesson: lesson);
    }
    final scope = await showPennyChoice<SeriesScope>(
      context,
      title: 'Change which lessons?',
      choices: seriesScopeChoices,
    );
    if (scope == null || !context.mounted) return;
    if (scope == SeriesScope.thisLesson) {
      return showLessonForm(context, ref, team: team, lesson: lesson);
    }
    try {
      final series = await ref.read(seriesProvider(seriesId).future);
      if (!context.mounted) return;
      await showLessonForm(
        context,
        ref,
        team: team,
        lesson: lesson,
        series: series,
        scope: scope,
      );
    } on Failure catch (f) {
      if (context.mounted) PennySnackbar.show(context, message: failureText(f));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final actions = ref.read(lessonActionsProvider);
    final cancelled = lesson.status == LessonStatus.cancelled;
    final scheduled = lesson.status == LessonStatus.scheduled;
    final complete = canComplete(team, lesson);
    final manage = team.can(Capability.manageLessons);
    final badges = lessonBadges(lesson);
    final place = lesson.place;
    final lead = lesson.lead;
    final items = lesson.items ?? const <LessonItem>[];
    final editItems = canEditItems(team, lesson);

    Future<void> undoable(Future<Lesson> Function() change, String done) =>
        _act(
          context,
          ref,
          change,
          done,
          undo: (result) async {
            try {
              await actions.reopen(result! as Lesson);
            } on Failure catch (f) {
              if (context.mounted) {
                PennySnackbar.show(context, message: failureText(f));
              }
            }
          },
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            PennyFormat.names([
              for (final s in lesson.students) s.name,
            ], max: lesson.students.length),
            style: PennyText.title.copyWith(
              color: cancelled ? c.textTertiary : c.text,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (lesson.title.isNotEmpty)
          Text(
            lesson.title,
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        const SizedBox(height: PennySpace.s2),
        Text(
          lessonWhen(context, lesson, team.time),
          style: PennyText.body.copyWith(
            color: c.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: PennySpace.s2),
          Wrap(
            spacing: PennySpace.s1,
            runSpacing: PennySpace.s1,
            children: [for (final b in badges) StatusBadge(b)],
          ),
        ],
        for (final clash in cancelled ? const <Clash>[] : lesson.clashes) ...[
          const SizedBox(height: PennySpace.s3),
          PennyNotice(
            tone: PennyNoticeTone.warning,
            title: clashText(context, clash, team.time),
            body: 'Clashes never block. Move one of them, or keep both.',
            action: PennyButton(
              label: 'Open that lesson',
              variant: PennyButtonVariant.quiet,
              size: PennyButtonSize.compact,
              onPressed: () => context.push(Paths.lesson(clash.lessonId)),
            ),
          ),
        ],
        if (lesson.cancellation case final cx?) ...[
          const SizedBox(height: PennySpace.s3),
          PennyNotice(
            title: cx.party == CancellationParty.tutor
                ? 'Cancelled by the tutor.'
                : cx.late
                ? 'Cancelled late by the family.'
                : 'Cancelled by the family, with notice.',
            body: [
              if (cx.reason.isNotEmpty) asSentence(cx.reason),
              lesson.billable ? 'The lesson is charged.' : 'It is not charged.',
            ].join(' '),
            action: lesson.makeupLessonId == null
                ? null
                : PennyButton(
                    label: 'Open the make-up lesson',
                    variant: PennyButtonVariant.quiet,
                    size: PennyButtonSize.compact,
                    onPressed: () =>
                        context.push(Paths.lesson(lesson.makeupLessonId!)),
                  ),
          ),
        ],
        if (lesson.makeupForLessonId != null) ...[
          const SizedBox(height: PennySpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: PennyButton(
              label: 'Makes up for a cancelled lesson',
              icon: PennyIcons.makeUp,
              variant: PennyButtonVariant.quiet,
              size: PennyButtonSize.compact,
              onPressed: () =>
                  context.push(Paths.lesson(lesson.makeupForLessonId!)),
            ),
          ),
        ],
        if (place != null) ...[
          const SizedBox(height: PennySpace.s3),
          PennyListRow(
            leading: Icon(
              place.kind == LocationKind.online
                  ? PennyIcons.online
                  : PennyIcons.location,
              size: PennyIconSize.standard,
              color: c.textSecondary,
            ),
            title: place.name,
            subtitle: place.kind == LocationKind.online
                ? (place.meetingUrl.isEmpty ? null : place.meetingUrl)
                : (place.address.isEmpty ? null : place.address),
          ),
        ],
        const SizedBox(height: PennySpace.s4),
        Wrap(
          spacing: PennySpace.s2,
          runSpacing: PennySpace.s2,
          children: [
            if (scheduled && complete) ...[
              PennyButton(
                label: 'Mark done',
                icon: PennyIcons.check,
                onPressed: () => undoable(
                  () => actions.complete(lesson),
                  'Lesson marked done',
                ),
              ),
              PennyButton(
                label: 'No-show',
                variant: PennyButtonVariant.secondary,
                onPressed: () => undoable(
                  () => actions.markNoShow(lesson),
                  'Marked as a no-show',
                ),
              ),
            ],
            if (scheduled && manage) ...[
              PennyButton(
                label: 'Reschedule',
                variant: PennyButtonVariant.secondary,
                onPressed: () => _reschedule(context, ref),
              ),
              PennyButton(
                label: 'Cancel lesson',
                variant: PennyButtonVariant.danger,
                onPressed: () async {
                  final done = await showPennySheet<String>(
                    context,
                    title: 'Cancel this lesson',
                    builder: (sheetContext) => CancelLessonForm(
                      team: team,
                      lesson: lesson,
                      onDone: (m) => Navigator.of(sheetContext).pop(m),
                    ),
                  );
                  if (done != null && context.mounted) {
                    PennySnackbar.show(context, message: done);
                  }
                },
              ),
            ],
            if (!scheduled && (manage || complete))
              PennyButton(
                label: 'Reopen',
                icon: PennyIcons.retry,
                variant: PennyButtonVariant.secondary,
                onPressed: () => _act(
                  context,
                  ref,
                  () => actions.reopen(lesson),
                  'Lesson reopened',
                ),
              ),
          ],
        ),
        if (lesson.seriesId case final seriesId?)
          _Repeats(lesson: lesson, seriesId: seriesId, team: team),
        const PennySectionHeader(title: 'Tutors'),
        for (final t in lesson.tutors)
          PennyListRow(
            leading: PennyAvatar(name: t.name),
            title: t.name,
            tag: t.membershipId == team.membershipId ? 'You' : null,
            trailing: [
              Text(
                t.isLead ? 'Lead' : 'Assisting',
                style: PennyText.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        if (lesson.isShared && lead != null) ...[
          const SizedBox(height: PennySpace.s2),
          PennyNotice(
            title: '${PennyFormat.firstName(lead.name)} bills this lesson.',
            body: 'The tutors arrange the split outside Penny.',
          ),
        ],
        const PennySectionHeader(title: 'Students'),
        for (final s in lesson.students)
          PennyListRow(
            leading: PennyAvatar(name: s.name),
            title: s.name,
            onTap: () => context.push(Paths.student(s.studentId)),
            trailing: [
              if (s.attendance != null)
                Text(switch (s.attendance!) {
                  Attendance.present => 'Present',
                  Attendance.absent => 'Absent',
                  Attendance.late => 'Late',
                }, style: PennyText.small.copyWith(color: c.textSecondary)),
            ],
          ),
        const SizedBox(height: PennySpace.s3),
        Text(
          lesson.feeCents == 0
              ? 'No fee'
              : 'Fee ${PennyFormat.money(lesson.feeCents, currency: lesson.currency)}'
                    '${lead == null ? '' : ', billed by ${PennyFormat.firstName(lead.name)}'}',
          style: PennyText.body.copyWith(
            color: c.textSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        PennySectionHeader(
          title: 'Tasks, goals and notes',
          action: editItems
              ? PennyButton(
                  label: 'Add',
                  icon: PennyIcons.add,
                  variant: PennyButtonVariant.quiet,
                  size: PennyButtonSize.compact,
                  onPressed: () => showPennySheet<void>(
                    context,
                    title: 'Add to this lesson',
                    builder: (sheetContext) => LessonItemForm(
                      lessonId: lesson.id,
                      onDone: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                )
              : null,
        ),
        if (items.isEmpty)
          Text(
            'Nothing yet. Add what to practise, a goal, or a note.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        for (final item in items)
          _ItemRow(item: item, lesson: lesson, team: team, canEdit: editItems),
        if (lesson.policy case final p?) ...[
          PennySectionHeader(
            title: lead == null
                ? 'Cancellation policy'
                : '${PennyFormat.firstName(lead.name)}\'s cancellation policy',
          ),
          if (p.summary.isNotEmpty)
            Text(p.summary, style: PennyText.body.copyWith(color: c.text)),
          Text(
            policyFacts(p),
            style: PennyText.small.copyWith(color: c.textSecondary),
          ),
        ],
        const PennySectionHeader(title: 'History'),
        _History(lessonId: lesson.id, team: team),
      ],
    );
  }
}

/// The series a lesson repeats in, and stopping it.
class _Repeats extends ConsumerWidget {
  const _Repeats({
    required this.lesson,
    required this.seriesId,
    required this.team,
  });

  final Lesson lesson;
  final String seriesId;
  final ActiveTeam team;

  Future<void> _stop(BuildContext context, WidgetRef ref, Series s) async {
    final day = team.time.wallClock(lesson.startsAt);
    final ok = await showPennyConfirmation(
      context,
      title: 'Stop repeating after this lesson?',
      body:
          'Lessons after ${PennyFormat.shortDate(day)} that have not '
          'happened are removed. Lessons with notes stay.',
      confirmLabel: 'Stop repeating',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(lessonActionsProvider)
          .endSeries(s, after: team.time.dateOf(lesson.startsAt));
      if (context.mounted) {
        PennySnackbar.show(context, message: 'Repeating stopped');
      }
    } on Failure catch (f) {
      if (f is ConflictFailure) ref.invalidate(seriesProvider(seriesId));
      if (context.mounted) PennySnackbar.show(context, message: failureText(f));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final series = ref.watch(seriesProvider(seriesId));
    final manage = team.can(Capability.manageLessons);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PennySectionHeader(
          title: 'Repeats',
          action: manage && series.value != null
              ? PennyButton(
                  label: 'Stop repeating',
                  variant: PennyButtonVariant.quiet,
                  size: PennyButtonSize.compact,
                  onPressed: () => _stop(context, ref, series.value!),
                )
              : null,
        ),
        switch (series) {
          AsyncData(:final value) => PennyListRow(
            leading: Icon(
              PennyIcons.recurring,
              size: PennyIconSize.standard,
              color: c.textSecondary,
            ),
            title: seriesSummary(context, value),
            subtitle:
                'Booked up to ${PennyFormat.shortDate(value.bookedUntil)}',
          ),
          AsyncError(:final error) => Text(
            error is Failure ? failureText(error) : 'Couldn\'t load it.',
            style: PennyText.small.copyWith(color: c.textSecondary),
          ),
          _ => const PennySkeletonRow(),
        },
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.lesson,
    required this.team,
    required this.canEdit,
  });

  final LessonItem item;
  final Lesson lesson;
  final ActiveTeam team;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final actions = ref.read(lessonActionsProvider);
    final mayDelete =
        team.can(Capability.manageLessons) ||
        (canEdit && item.authorMembershipId == team.membershipId);

    Future<void> run(Future<Object?> Function() change) async {
      try {
        await change();
      } on Failure catch (f) {
        if (context.mounted) {
          PennySnackbar.show(context, message: failureText(f));
        }
      }
    }

    final menu = mayDelete
        ? [
            PennyMenuButton(
              tooltip: 'Actions for this item',
              items: [
                PennyMenuItem(
                  label: 'Remove',
                  icon: PennyIcons.delete,
                  destructive: true,
                  onSelected: () =>
                      run(() => actions.deleteItem(lesson.id, item.id)),
                ),
              ],
            ),
          ]
        : const <Widget>[];

    if (item.kind == ItemKind.task) {
      return PennyCheckRow(
        title: item.body,
        subtitle: item.authorName,
        checked: item.done,
        onChanged: canEdit
            ? (done) =>
                  run(() => actions.updateItem(lesson.id, item.id, done: done))
            : null,
        trailing: menu,
      );
    }
    return PennyListRow(
      leading: Icon(
        item.kind == ItemKind.goal ? PennyIcons.goal : PennyIcons.note,
        size: PennyIconSize.standard,
        color: c.textSecondary,
      ),
      title: item.body,
      subtitle:
          '${item.kind == ItemKind.goal ? 'Goal' : 'Note'}, ${item.authorName}',
      trailing: menu,
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.lessonId, required this.team});

  final String lessonId;
  final ActiveTeam team;

  static String _what(String action) => switch (action) {
    'lesson.created' => 'Booked',
    'lesson.updated' => 'Changed',
    'lesson.completed' => 'Marked done',
    'lesson.no_show' => 'Marked as a no-show',
    'lesson.cancelled' => 'Cancelled',
    'lesson.reopened' => 'Reopened',
    'lesson.item_added' => 'Added a task, goal or note',
    'lesson.item_updated' => 'Updated a task, goal or note',
    'lesson.item_removed' => 'Removed a task, goal or note',
    _ => 'Changed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final history = ref.watch(lessonHistoryProvider(lessonId));
    return switch (history) {
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in value.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: PennySpace.s2),
              child: Text(
                '${_what(e.action)}${e.actorName == null ? '' : ' by ${e.actorName}'}, '
                '${PennyFormat.shortDate(team.time.wallClock(e.at))} '
                '${PennyFormat.time(context, team.time.wallClock(e.at))}',
                style: PennyText.small.copyWith(color: c.textSecondary),
              ),
            ),
        ],
      ),
      AsyncError() => Text(
        'Couldn\'t load the history.',
        style: PennyText.small.copyWith(color: c.textSecondary),
      ),
      _ => const PennySkeleton(height: 14),
    };
  }
}
