// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../lessons/domain/lesson.dart';
import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../../students/application/student_providers.dart';
import '../../team/application/team_controller.dart';
import '../../../core/capability.dart';
import '../../team/domain/team_member.dart';
import '../application/payment_providers.dart';
import '../domain/payment.dart';
import 'payee_account_section.dart';
import 'payment_views.dart';

/// Asks for payment (build plan, Phase 8): a student, the lessons of
/// theirs that the payee led and nobody has billed yet, any other lines, a
/// due day and a note. Owners choose who is paid; teachers bill for
/// themselves. One Idempotency-Key per opened form, so a retry after a
/// lost answer makes no second request.
class NewRequestForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const NewRequestForm({
    super.key,
    required this.team,
    required this.onDone,
    this.studentId,
  });

  /// The team.
  final ActiveTeam team;

  /// Called with the request made.
  final ValueChanged<SentPaymentRequest> onDone;

  /// A student to start with, as from their page.
  final String? studentId;

  @override
  ConsumerState<NewRequestForm> createState() => _NewRequestFormState();
}

class _ExtraLineFields {
  final description = TextEditingController();
  final amount = TextEditingController();
  String? error;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _NewRequestFormState extends ConsumerState<NewRequestForm>
    with AsyncAction {
  final _key = newIdempotencyKey();
  late String? _studentId = widget.studentId;
  late String _payeeId = widget.team.membershipId;
  late DateTime _due = widget.team.time
      .dateOf(ref.read(clockProvider)())
      .add(const Duration(days: 14));
  final _unchecked = <String>{};
  final _extras = <_ExtraLineFields>[];
  final _note = TextEditingController();
  String? _studentError;

  @override
  void dispose() {
    for (final e in _extras) {
      e.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final today = widget.team.time.dateOf(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_due.year, _due.month, _due.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) {
      setState(
        () => _due = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _create(List<BillableLesson> lessons) async {
    var ok = true;
    final extras = <ExtraLine>[];
    setState(() {
      _studentError = _studentId == null ? 'Choose whose lessons.' : null;
      for (final e in _extras) {
        final description = e.description.text.trim();
        final cents = parseMoney(e.amount.text);
        e.error = description.isEmpty && e.amount.text.trim().isEmpty
            ? null
            : description.isEmpty
            ? 'Say what this line is for.'
            : cents == null || cents <= 0
            ? 'Enter an amount such as 18.90.'
            : null;
        if (e.error != null) ok = false;
        if (description.isNotEmpty && cents != null && cents > 0) {
          extras.add(ExtraLine(description: description, amountCents: cents));
        }
      }
    });
    if (_studentError != null || !ok) return;
    final lessonIds = [
      for (final l in lessons)
        if (!_unchecked.contains(l.lessonId)) l.lessonId,
    ];
    SentPaymentRequest? made;
    final done = await run(() async {
      made = await ref
          .read(paymentActionsProvider)
          .create(
            PaymentRequestDraft(
              studentId: _studentId!,
              payeeId: _payeeId,
              dueOn: _due,
              lessonIds: lessonIds,
              extraLines: extras,
              note: _note.text,
            ),
            idempotencyKey: _key,
          );
    });
    if (done && made != null) widget.onDone(made!);
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final team = widget.team;
    final students =
        ref.watch(studentsProvider((search: '', archived: false))).value ??
        const [];
    final staff = canBillForOthers(team) && !team.isTeamOfOne
        ? [
            for (final m
                in ref.watch(teamMembersProvider).value ?? const <TeamMember>[])
              if (m.status == MemberStatus.active &&
                  (m.role == TeamRole.owner || m.role == TeamRole.teacher))
                m,
          ]
        : const <TeamMember>[];
    final account = ref.watch(payeeAccountProvider(_payeeId));
    final ready = account.value?.verified ?? false;
    final studentId = _studentId;
    final lessons = studentId == null
        ? const AsyncData<List<BillableLesson>>([])
        : ref.watch(
            billableLessonsProvider((studentId: studentId, payeeId: _payeeId)),
          );
    final lessonList = lessons.value ?? const <BillableLesson>[];
    final total =
        lessonList
            .where((l) => !_unchecked.contains(l.lessonId))
            .fold<int>(0, (s, l) => s + l.feeCents) +
        _extras.fold<int>(0, (s, e) => s + (parseMoney(e.amount.text) ?? 0));
    final payeeName = _payeeId == team.membershipId
        ? 'you'
        : staff.where((m) => m.id == _payeeId).firstOrNull?.name ?? '';
    final failure = this.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          PennyNotice(
            tone: PennyNoticeTone.danger,
            title: failureText(failure),
          ),
          const SizedBox(height: PennySpace.s4),
        ],
        PennySelectField(
          label: 'Student',
          value: students.where((s) => s.id == studentId).firstOrNull?.name,
          placeholder: 'Choose a student',
          error: _studentError,
          onTap: () async {
            final id = await showPennyChoice<String>(
              context,
              title: 'Whose lessons?',
              selected: studentId,
              choices: [
                for (final s in students)
                  PennyChoice(value: s.id, label: s.name),
              ],
            );
            if (id != null) {
              setState(() {
                _studentId = id;
                _studentError = null;
                _unchecked.clear();
              });
            }
          },
        ),
        if (staff.isNotEmpty) ...[
          const SizedBox(height: PennySpace.s4),
          PennySelectField(
            label: 'Pays',
            hint: 'The lead tutor of each lesson is paid for it.',
            value: _payeeId == team.membershipId
                ? 'You'
                : staff.where((m) => m.id == _payeeId).firstOrNull?.name,
            onTap: () async {
              final id = await showPennyChoice<String>(
                context,
                title: 'Who is paid?',
                selected: _payeeId,
                choices: [
                  for (final m in staff)
                    PennyChoice(
                      value: m.id,
                      label: m.id == team.membershipId ? 'You' : m.name,
                    ),
                ],
              );
              if (id != null) {
                setState(() {
                  _payeeId = id;
                  _unchecked.clear();
                });
              }
            },
          ),
        ],
        if (account.hasValue && !ready) ...[
          const SizedBox(height: PennySpace.s4),
          PennyNotice(
            tone: PennyNoticeTone.warning,
            title: _payeeId == team.membershipId
                ? 'Set up and check your PayNow first.'
                : 'Their PayNow is not set up and checked yet.',
            body: 'The request\'s code would have nowhere to pay.',
            action: _payeeId == team.membershipId
                ? PennyButton(
                    label: account.value == null
                        ? 'Set up PayNow'
                        : 'Change PayNow',
                    variant: PennyButtonVariant.quiet,
                    onPressed: () =>
                        openPayeeAccountForm(context, _payeeId, account.value),
                  )
                : null,
          ),
        ],
        if (studentId != null) ...[
          PennySectionHeader(title: 'Lessons'),
          switch (lessons) {
            AsyncData(:final value) when value.isEmpty => Text(
              'No lessons to bill: none of theirs that $payeeName led is done '
              'and not on a request already.',
              style: PennyText.body.copyWith(color: c.textSecondary),
            ),
            AsyncData(:final value) => Column(
              children: [
                for (final l in value)
                  PennyCheckRow(
                    title: _describe(l),
                    subtitle: l.coTaught
                        ? 'Shared: the split is arranged outside Penny'
                        : null,
                    checked: !_unchecked.contains(l.lessonId),
                    trailing: [
                      Text(
                        money(l.feeCents, l.currency),
                        style: PennyText.amount.copyWith(color: c.text),
                      ),
                    ],
                    onChanged: (on) => setState(
                      () => on
                          ? _unchecked.remove(l.lessonId)
                          : _unchecked.add(l.lessonId),
                    ),
                  ),
              ],
            ),
            AsyncError(:final error) => PennyNotice(
              tone: PennyNoticeTone.danger,
              title: 'Couldn\'t load the lessons.',
              body: error is Failure ? failureText(error) : null,
            ),
            _ => const PennySkeletonRow(),
          },
        ],
        PennySectionHeader(
          title: 'Other lines',
          action: PennyButton(
            label: 'Add a line',
            icon: PennyIcons.add,
            variant: PennyButtonVariant.quiet,
            size: PennyButtonSize.compact,
            onPressed: () => setState(() => _extras.add(_ExtraLineFields())),
          ),
        ),
        if (_extras.isEmpty)
          Text(
            'A book, an exam fee: anything that is not a lesson.',
            style: PennyText.body.copyWith(color: c.textSecondary),
          ),
        for (final e in _extras) ...[
          PennyTextField(
            label: 'What it is',
            controller: e.description,
            error: e.error,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: PennySpace.s2),
          PennyTextField(
            label: 'Amount (S\$)',
            controller: e.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            tabularFigures: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: PennySpace.s4),
        ],
        const SizedBox(height: PennySpace.s4),
        PennySelectField(
          label: 'Due',
          value: PennyFormat.longDate(_due),
          icon: PennyIcons.calendar,
          onTap: _pickDue,
        ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Note for the family',
          hint: 'Optional. Shown on the request and its email.',
          controller: _note,
        ),
        const SizedBox(height: PennySpace.s6),
        Row(
          children: [
            Expanded(
              child: Text(
                'Total',
                style: PennyText.bodyStrong.copyWith(color: c.text),
              ),
            ),
            Text(money(total), style: PennyText.amount.copyWith(color: c.text)),
          ],
        ),
        const SizedBox(height: PennySpace.s4),
        PennyButton(
          label: account.value?.sendAutomatically ?? false
              ? 'Send request'
              : 'Save draft',
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy || !ready ? null : () => _create(lessonList),
        ),
      ],
    );
  }

  String _describe(BillableLesson l) {
    final day = PennyFormat.shortDate(widget.team.time.wallClock(l.startsAt));
    final what = l.title.isEmpty ? 'Lesson' : l.title;
    return switch (l.status) {
      LessonStatus.noShow => '$what, $day (missed)',
      LessonStatus.cancelled => '$what, $day (late cancellation)',
      _ => '$what, $day',
    };
  }
}
