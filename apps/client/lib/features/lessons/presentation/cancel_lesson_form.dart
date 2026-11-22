// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../shared/application/active_team.dart';
import '../../shared/application/clock.dart';
import '../../shared/presentation/async_action.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/lesson_providers.dart';
import '../domain/lesson.dart';
import '../domain/policy.dart';

/// Cancels a lesson: who called it off, why, and optionally a make-up.
/// Before confirming it says whether the lead tutor's policy makes this a
/// late cancellation, and whether that is charged (designs: "cancel with
/// make-up").
class CancelLessonForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const CancelLessonForm({
    super.key,
    required this.team,
    required this.lesson,
    required this.onDone,
  });

  /// The team.
  final ActiveTeam team;

  /// The lesson, with its policy.
  final Lesson lesson;

  /// Called with the snackbar message when done.
  final ValueChanged<String> onDone;

  @override
  ConsumerState<CancelLessonForm> createState() => _CancelLessonFormState();
}

class _CancelLessonFormState extends ConsumerState<CancelLessonForm>
    with AsyncAction {
  CancellationParty _party = CancellationParty.student;
  final _reason = TextEditingController();
  bool _makeup = false;
  late DateTime _makeupStart; // team wall clock

  @override
  void initState() {
    super.initState();
    _makeupStart = widget.team.time
        .wallClock(widget.lesson.startsAt)
        .add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final time = widget.team.time;
    final start = time.instant(_makeupStart);
    final ok = await run(
      () => ref
          .read(lessonActionsProvider)
          .cancel(
            widget.lesson,
            party: _party,
            reason: _reason.text,
            makeup: _makeup
                ? (startsAt: start, endsAt: start.add(widget.lesson.length))
                : null,
          ),
    );
    if (ok) {
      widget.onDone(
        _makeup ? 'Lesson cancelled, make-up booked' : 'Lesson cancelled',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final lead = widget.lesson.lead;
    final policy =
        widget.lesson.policy ??
        CancellationPolicy.defaultFor(lead?.membershipId ?? '');
    final late = isLateCancellation(
      policy,
      _party,
      widget.lesson.startsAt,
      now,
    );
    final charged = isBillable(
      policy,
      LessonStatus.cancelled,
      lateCancellation: late,
    );
    final failure = this.failure;
    final leadName = PennyFormat.firstName(lead?.name ?? 'the tutor');

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
        Text(
          'Who called it off?',
          style: PennyText.smallStrong.copyWith(
            color: PennyColors.of(context).text,
          ),
        ),
        const SizedBox(height: PennySpace.s2),
        PennyOptionRow(
          title: 'The student or their family',
          selected: _party == CancellationParty.student,
          onSelected: () => setState(() => _party = CancellationParty.student),
        ),
        const SizedBox(height: PennySpace.s2),
        PennyOptionRow(
          title: 'The tutor or the studio',
          body: 'Never charged.',
          selected: _party == CancellationParty.tutor,
          onSelected: () => setState(() => _party = CancellationParty.tutor),
        ),
        const SizedBox(height: PennySpace.s4),
        if (late)
          PennyNotice(
            tone: PennyNoticeTone.warning,
            title: 'This is a late cancellation under $leadName\'s policy.',
            body: charged
                ? 'The policy charges late cancellations, so the lesson stays billable.'
                : 'The policy does not charge late cancellations.',
          )
        else
          PennyNotice(
            title: _party == CancellationParty.tutor
                ? 'The family is not charged.'
                : 'This is within $leadName\'s notice period, so it is not charged.',
          ),
        const SizedBox(height: PennySpace.s4),
        PennyTextField(
          label: 'Reason',
          hint: 'Optional. Shown to the team.',
          controller: _reason,
        ),
        const SizedBox(height: PennySpace.s2),
        PennyToggleRow(
          title: 'Book a make-up lesson',
          body: 'Same tutors, students, place and fee.',
          value: _makeup,
          onChanged: (v) => setState(() => _makeup = v),
        ),
        if (_makeup) ...[
          const SizedBox(height: PennySpace.s2),
          Row(
            children: [
              Expanded(
                child: PennySelectField(
                  label: 'Make-up date',
                  value: PennyFormat.shortDate(_makeupStart),
                  icon: PennyIcons.calendar,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime(
                        _makeupStart.year,
                        _makeupStart.month,
                        _makeupStart.day,
                      ),
                      firstDate: DateTime(_makeupStart.year - 1),
                      lastDate: DateTime(_makeupStart.year + 2),
                    );
                    if (d != null) {
                      setState(
                        () => _makeupStart = DateTime.utc(
                          d.year,
                          d.month,
                          d.day,
                          _makeupStart.hour,
                          _makeupStart.minute,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: PennySpace.s3),
              Expanded(
                child: PennySelectField(
                  label: 'Starts',
                  value: PennyFormat.time(context, _makeupStart),
                  icon: PennyIcons.open,
                  tabularFigures: true,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: _makeupStart.hour,
                        minute: _makeupStart.minute,
                      ),
                    );
                    if (t != null) {
                      setState(
                        () => _makeupStart = DateTime.utc(
                          _makeupStart.year,
                          _makeupStart.month,
                          _makeupStart.day,
                          t.hour,
                          t.minute,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: PennySpace.s6),
        PennyButton(
          label: 'Cancel lesson',
          variant: PennyButtonVariant.danger,
          size: PennyButtonSize.large,
          expand: true,
          onPressed: busy ? null : _cancel,
        ),
      ],
    );
  }
}
