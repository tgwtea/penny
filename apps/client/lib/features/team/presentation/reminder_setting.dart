// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny_ui/penny_ui.dart';

import '../../../core/failure.dart';
import '../../shared/presentation/failure_text.dart';
import '../application/team_controller.dart';

/// How far ahead the team reminds contacts of lessons (build plan, Phase 7).
/// Owners only; the server refuses anyone else.
class ReminderSetting extends ConsumerStatefulWidget {
  /// Creates the setting, showing [hours], the team's current value.
  const ReminderSetting({super.key, required this.hours});

  /// The team's current setting; 0 is off.
  final int hours;

  @override
  ConsumerState<ReminderSetting> createState() => _ReminderSettingState();
}

/// The choices offered. The API accepts any whole number up to 168.
const reminderChoices = [0, 2, 12, 24, 48];

/// "24 hours before", or "Off".
String reminderLabel(int hours) => switch (hours) {
  0 => 'Off',
  1 => '1 hour before',
  _ => '$hours hours before',
};

class _ReminderSettingState extends ConsumerState<ReminderSetting> {
  bool _busy = false;

  Future<void> _choose() async {
    final hours = await showPennyChoice<int>(
      context,
      title: 'Remind contacts',
      selected: widget.hours,
      choices: [
        for (final h in reminderChoices)
          PennyChoice(
            value: h,
            label: reminderLabel(h),
            description: h == 0
                ? 'No lesson reminders are emailed.'
                : h == 24
                ? 'The usual choice: the day before.'
                : null,
          ),
      ],
    );
    if (hours == null || hours == widget.hours || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(teamSettingsActionsProvider).setReminderHours(hours);
      if (mounted) {
        PennySnackbar.show(
          context,
          message: hours == 0
              ? 'Lesson reminders turned off'
              : 'Reminders now go ${reminderLabel(hours)}',
        );
      }
    } on Failure catch (f) {
      if (mounted) PennySnackbar.show(context, message: failureText(f));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.hours == 0
              ? 'Contacts get no lesson reminders. They still get payment '
                    'requests and receipts.'
              : 'Each student\'s contacts get an email ${reminderLabel(widget.hours)} '
                    'each lesson, with the time, place and your cancellation '
                    'policy.',
          style: PennyText.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: PennySpace.s3),
        PennySelectField(
          label: 'Remind contacts',
          value: reminderLabel(widget.hours),
          onTap: _busy ? () {} : _choose,
        ),
      ],
    );
  }
}
