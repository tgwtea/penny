// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/pressable.dart';
import '../tokens.g.dart';
import 'avatar.dart';

/// One choice of a [PennyChips].
@immutable
class PennyChip<T> {
  /// Creates a chip.
  const PennyChip({required this.value, required this.label, this.person});

  /// The value the chip stands for.
  final T value;

  /// One or two words: "Mei", "Everyone".
  final String label;

  /// Shows a small avatar for this person before the label.
  final String? person;
}

/// A row of chips for picking tutors: one at a time (the phone timetable's
/// tutor switcher) or several (the team timetable's filter).
///
/// The chips report taps; the caller decides whether a tap selects one
/// chip or toggles it. Selected chips are `ink` with `on-ink` text, like a
/// selected segment. With [scrollable] the chips stay on one line and the
/// row, never the page, scrolls sideways; otherwise they wrap.
class PennyChips<T> extends StatelessWidget {
  /// Creates a chip row.
  const PennyChips({
    super.key,
    required this.chips,
    required this.selected,
    required this.onTap,
    this.scrollable = false,
    this.label,
  });

  /// The chips, in order.
  final List<PennyChip<T>> chips;

  /// The values of the selected chips.
  final Set<T> selected;

  /// Called with a tapped chip's value.
  final ValueChanged<T> onTap;

  /// One line that scrolls sideways (phone), instead of wrapping.
  final bool scrollable;

  /// What the row chooses, for assistive technology: "Tutors".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final chip in chips)
        _Chip(
          chip: chip,
          selected: selected.contains(chip.value),
          onTap: () => onTap(chip.value),
        ),
    ];
    final row = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: PennySpace.s2),
                  c,
                ],
              ],
            ),
          )
        : Wrap(
            spacing: PennySpace.s2,
            runSpacing: PennySpace.s1,
            children: children,
          );
    return Semantics(container: true, label: label, child: row);
  }
}

class _Chip<T> extends StatelessWidget {
  const _Chip({
    required this.chip,
    required this.selected,
    required this.onTap,
  });

  final PennyChip<T> chip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final content = selected ? c.onInk : c.text;
    const radius = BorderRadius.all(Radius.circular(PennyRadius.md));
    return PennyPressable(
      onPressed: onTap,
      contentColor: content,
      borderRadius: radius,
      selected: selected,
      child: Container(
        height: PennySize.controlHeightSm,
        padding: EdgeInsets.only(
          left: chip.person == null ? PennySpace.s3 : PennySpace.s1,
          right: PennySpace.s3,
        ),
        decoration: BoxDecoration(
          color: selected ? c.ink : c.surface,
          borderRadius: radius,
          border: Border.all(color: selected ? c.ink : c.borderControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chip.person != null) ...[
              ExcludeSemantics(
                child: PennyAvatar(
                  name: chip.person!,
                  size: PennyAvatarSize.small,
                ),
              ),
              const SizedBox(width: PennySpace.s2),
            ],
            Text(
              chip.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PennyText.smallStrong.copyWith(color: content),
            ),
          ],
        ),
      ),
    );
  }
}
