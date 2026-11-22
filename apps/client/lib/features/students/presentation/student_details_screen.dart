// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/capability.dart';
import '../../../core/failure.dart';
import '../../lessons/application/lesson_providers.dart';
import '../../lessons/presentation/lesson_views.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/back_link.dart';
import '../../shared/presentation/failure_text.dart';
import '../../shared/presentation/paths.dart';
import '../application/student_providers.dart';
import '../domain/student.dart';
import 'student_forms.dart';

/// One student (designs: "student details"): who gets their reminders and
/// receipts, their goals, and their next lessons. Owners change contacts
/// and archive; the student's teachers manage goals.
class StudentDetailsScreen extends ConsumerWidget {
  /// Creates the screen for [studentId].
  const StudentDetailsScreen({super.key, required this.studentId});

  /// The student.
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(activeTeamProvider);
    final student = ref.watch(studentDetailProvider(studentId));
    if (team == null) return const SizedBox.shrink();
    return PennyPage(
      title: 'Student',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BackLink(fallback: Paths.students),
          const SizedBox(height: PennySpace.s2),
          switch (student) {
            AsyncData(:final value) => _Details(student: value, team: team),
            AsyncError(:final error) =>
              error is NotFoundFailure
                  ? PennyEmptyState(
                      title: 'This student is not in your list.',
                      body: 'They may be another teacher\'s student.',
                      action: PennyButton(
                        label: 'Go to Students',
                        onPressed: () => context.go(Paths.students),
                      ),
                    )
                  : PennyNotice(
                      tone: PennyNoticeTone.danger,
                      title: 'Couldn\'t load this student.',
                      body: error is Failure ? failureText(error) : null,
                      action: PennyButton(
                        label: 'Retry',
                        icon: PennyIcons.retry,
                        variant: PennyButtonVariant.quiet,
                        onPressed: () =>
                            ref.invalidate(studentDetailProvider(studentId)),
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
  const _Details({required this.student, required this.team});

  final Student student;
  final ActiveTeam team;

  Future<void> _run(
    BuildContext context,
    Future<Object?> Function() change,
    String done,
  ) async {
    try {
      await change();
      if (context.mounted) PennySnackbar.show(context, message: done);
    } on Failure catch (f) {
      if (context.mounted) PennySnackbar.show(context, message: failureText(f));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = PennyColors.of(context);
    final manage = team.can(Capability.manageStudents);
    final goals = manage || team.can(Capability.editOwnLessonItems);
    final actions = ref.read(studentActionsProvider);
    final now = ref.watch(clockProvider)();
    final upcoming = ref.watch(
      lessonsProvider((
        from: now,
        to: now.add(const Duration(days: 60)),
        teacherId: null,
        studentId: student.id,
      )),
    );

    Future<void> openContact([Contact? contact]) => showPennySheet<void>(
      context,
      title: contact == null ? 'Add contact' : 'Change contact',
      builder: (sheetContext) => ContactForm(
        studentId: student.id,
        contact: contact,
        onDone: () => Navigator.of(sheetContext).pop(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            student.name,
            style: PennyText.title.copyWith(color: c.text),
          ),
        ),
        if (student.primaryTeacherName != null && !team.isTeamOfOne)
          Text(
            'Usually taught by ${student.primaryTeacherName}',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        if (student.archived) ...[
          const SizedBox(height: PennySpace.s3),
          const PennyNotice(
            title: 'This student is archived.',
            body:
                'Their lessons and receipts are kept. Restore them to book '
                'new lessons.',
          ),
        ],
        PennySectionHeader(
          title: 'Contacts',
          action: manage
              ? PennyButton(
                  label: 'Add',
                  icon: PennyIcons.add,
                  variant: PennyButtonVariant.quiet,
                  size: PennyButtonSize.compact,
                  onPressed: openContact,
                )
              : null,
        ),
        if (student.contacts.isEmpty)
          Text(
            'No one gets reminders or receipts yet.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        for (final contact in student.contacts)
          PennyListRow(
            leading: PennyAvatar(name: contact.name),
            title: contact.name,
            tag: contact.relationship.label,
            subtitle: [?contact.email, ?contact.phone].join(', '),
            trailing: [
              if (manage)
                PennyMenuButton(
                  tooltip: 'Actions for ${contact.name}',
                  items: [
                    PennyMenuItem(
                      label: 'Change',
                      icon: PennyIcons.edit,
                      onSelected: () => openContact(contact),
                    ),
                    PennyMenuItem(
                      label: 'Remove',
                      icon: PennyIcons.delete,
                      destructive: true,
                      onSelected: () => _run(
                        context,
                        () => actions.removeContact(student.id, contact.id),
                        '${contact.name} removed',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        PennySectionHeader(
          title: 'Goals',
          action: goals
              ? PennyButton(
                  label: 'Add',
                  icon: PennyIcons.add,
                  variant: PennyButtonVariant.quiet,
                  size: PennyButtonSize.compact,
                  onPressed: () => showPennySheet<void>(
                    context,
                    title: 'Add a goal',
                    builder: (sheetContext) => _GoalForm(
                      studentId: student.id,
                      onDone: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                )
              : null,
        ),
        if (student.goals.isEmpty)
          Text(
            'No goals yet.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        for (final g in student.goals)
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
            trailing: [
              if (goals)
                PennyMenuButton(
                  tooltip: 'Actions for this goal',
                  items: [
                    for (final s in GoalStatus.values)
                      if (s != g.status)
                        PennyMenuItem(
                          label: switch (s) {
                            GoalStatus.active => 'Working on it again',
                            GoalStatus.achieved => 'Mark achieved',
                            GoalStatus.dropped => 'Drop',
                          },
                          onSelected: () => _run(
                            context,
                            () => actions.setGoalStatus(student.id, g.id, s),
                            'Goal updated',
                          ),
                        ),
                  ],
                ),
            ],
          ),
        const PennySectionHeader(title: 'Next lessons'),
        switch (upcoming) {
          AsyncData(:final value) =>
            value.isEmpty
                ? Text(
                    'No lessons booked.',
                    style: PennyText.body.copyWith(color: c.textSecondary),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final l in value.take(5))
                        PennyListRow(
                          title: lessonWhen(context, l, team.time),
                          subtitle: [
                            for (final t in l.tutors) t.name,
                          ].join(', '),
                          trailing: [
                            for (final b in lessonBadges(l)) StatusBadge(b),
                          ],
                          onTap: () => context.push(Paths.lesson(l.id)),
                        ),
                    ],
                  ),
          AsyncError() => Text(
            'Couldn\'t load their lessons.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
          _ => const PennySkeletonRow(),
        },
        if (manage && student.notes.isNotEmpty) ...[
          const PennySectionHeader(title: 'Notes'),
          Text(student.notes, style: PennyText.body.copyWith(color: c.text)),
        ],
        if (manage) ...[
          const SizedBox(height: PennySpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: PennyButton(
              label: student.archived ? 'Restore student' : 'Archive student',
              variant: student.archived
                  ? PennyButtonVariant.secondary
                  : PennyButtonVariant.danger,
              onPressed: () async {
                final yes =
                    student.archived ||
                    await showPennyConfirmation(
                      context,
                      title: 'Archive ${student.name}?',
                      body:
                          'They are no longer offered for new lessons. Their '
                          'lessons, payments and receipts are kept, and you can '
                          'restore them at any time.',
                      confirmLabel: 'Archive student',
                      destructive: true,
                    );
                if (!yes || !context.mounted) return;
                await _run(
                  context,
                  () => actions.update(
                    student.id,
                    StudentChanges(archived: !student.archived),
                  ),
                  student.archived ? 'Student restored' : 'Student archived',
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({required this.studentId, required this.onDone});

  final String studentId;
  final VoidCallback onDone;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _title = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter the goal.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(studentActionsProvider)
          .addGoal(widget.studentId, _title.text);
      widget.onDone();
    } on Failure catch (f) {
      setState(() => _error = failureText(f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PennyTextField(
          label: 'Goal',
          placeholder: 'Play Malaguena at 120 bpm',
          controller: _title,
          error: _error,
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Add goal',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: _busy ? null : _add,
        ),
      ],
    );
  }
}
