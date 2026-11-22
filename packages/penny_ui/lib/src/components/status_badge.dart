// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../tokens.g.dart';

/// Every status and tag Penny shows. The icon, word and colours come from
/// here, never from the caller (brand book, "Status").
///
/// Scheduled lessons have no entry: scheduled is the default and needs no
/// label. To add a status, add it here and to the brand book's status table.
enum PennyStatus {
  /// A completed lesson.
  done('Done', PennyIcons.check, _Tone.success),

  /// A cancelled lesson.
  cancelled('Cancelled', PennyIcons.cancelled, _Tone.neutral),

  /// A student did not come.
  noShow('No-show', PennyIcons.noShow, _Tone.warning),

  /// A tutor or student is booked into overlapping lessons.
  clash('Clash', PennyIcons.warning, _Tone.danger),

  /// A lesson replacing a cancelled one.
  makeUp('Make-up', PennyIcons.makeUp, _Tone.neutral),

  /// A lesson with several tutors.
  shared('Shared', PennyIcons.shared, _Tone.neutral),

  /// A payment request that has been paid.
  paid('Paid', PennyIcons.check, _Tone.success),

  /// A payment request not yet paid and not yet due.
  open('Open', PennyIcons.open, _Tone.neutral),

  /// A payment request past its due date.
  overdue('Overdue', PennyIcons.warning, _Tone.danger),

  /// A payment request not sent yet.
  draft('Draft', PennyIcons.edit, _Tone.neutral),

  /// A payment request taken back before it was paid.
  withdrawn('Withdrawn', PennyIcons.cancelled, _Tone.neutral),

  /// A receipt that was voided; a correction, if any, replaces it.
  voided('Void', PennyIcons.voided, _Tone.neutral),

  /// A team member who has not signed in yet.
  invited('Invited', PennyIcons.pending, _Tone.neutral);

  const PennyStatus(this.word, this.icon, this._tone);

  /// The word shown beside the icon.
  final String word;

  /// The icon.
  final IconData icon;

  final _Tone _tone;

  /// The ground colour behind the badge.
  Color groundOf(PennyColors c) => switch (_tone) {
    _Tone.success => c.successSubtle,
    _Tone.warning => c.warningSubtle,
    _Tone.danger => c.dangerSubtle,
    _Tone.neutral => c.surfaceSunken,
  };

  /// The colour of the icon and word.
  Color contentOf(PennyColors c) => switch (_tone) {
    _Tone.success => c.success,
    _Tone.warning => c.warning,
    _Tone.danger => c.danger,
    _Tone.neutral => c.textSecondary,
  };
}

enum _Tone { success, warning, danger, neutral }

/// A status as icon plus word, never colour alone.
class StatusBadge extends StatelessWidget {
  /// Creates a badge for [status].
  const StatusBadge(this.status, {super.key});

  /// The status shown.
  final PennyStatus status;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final content = status.contentOf(c);
    return Container(
      constraints: const BoxConstraints(minHeight: _height),
      padding: const EdgeInsets.symmetric(horizontal: PennySpace.s2),
      decoration: BoxDecoration(
        color: status.groundOf(c),
        borderRadius: BorderRadius.circular(PennyRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: PennyIconSize.badge, color: content),
          const SizedBox(width: PennySpace.s1),
          Text(
            status.word,
            style: PennyText.smallStrong.copyWith(color: content),
          ),
        ],
      ),
    );
  }

  static const double _height = 24;
}
