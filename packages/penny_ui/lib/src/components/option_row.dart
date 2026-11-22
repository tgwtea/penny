// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// One answer in a single-choice question, such as onboarding's "Do you
/// teach on your own, or run a team?". The whole row is the target; the
/// selected row shows the filled option mark on an `ink-subtle` ground.
///
/// Group rows in a Column; exactly one should be [selected].
class PennyOptionRow extends StatelessWidget {
  /// Creates an option row.
  const PennyOptionRow({
    super.key,
    required this.title,
    this.body,
    required this.selected,
    required this.onSelected,
  });

  /// The answer: "I run a team".
  final String title;

  /// What choosing it means, in one sentence.
  final String? body;

  /// Whether this is the chosen answer.
  final bool selected;

  /// Chooses this answer. Null disables the row.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: PennyPressable(
        onPressed: onSelected,
        contentColor: c.text,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(PennySpace.s4),
          decoration: BoxDecoration(
            color: selected ? c.inkSubtle : c.surface,
            border: Border.all(
              color: selected ? c.inkSubtleEdge : c.borderControl,
            ),
            borderRadius: BorderRadius.circular(PennyRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? PennyIcons.optionOn : PennyIcons.optionOff,
                size: PennyIconSize.standard,
                color: selected ? c.ink : c.textSecondary,
              ),
              const SizedBox(width: PennySpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PennyText.bodyStrong.copyWith(color: c.text),
                    ),
                    if (body != null)
                      Text(
                        body!,
                        style: PennyText.small.copyWith(color: c.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
