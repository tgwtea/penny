// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// A setting that is on or off, such as "Charge for late cancellations":
/// a title, what it means, and a switch at the end. The whole row is the
/// target, and the switch's position and the words say the state, not
/// only its colour.
class PennyToggleRow extends StatelessWidget {
  /// Creates a toggle row.
  const PennyToggleRow({
    super.key,
    required this.title,
    this.body,
    required this.value,
    required this.onChanged,
  });

  /// The setting: "Charge for no-shows".
  final String title;

  /// What it means, in one sentence.
  final String? body;

  /// Whether it is on.
  final bool value;

  /// Called with the new value. Null disables the row.
  final ValueChanged<bool>? onChanged;

  static const double _trackWidth = 40;
  static const double _trackHeight = 24;
  static const double _thumb = 18;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final onChanged = this.onChanged;
    final track = AnimatedContainer(
      duration: PennyMotion.short,
      width: _trackWidth,
      height: _trackHeight,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: value ? c.ink : c.surfaceSunken,
        border: Border.all(color: value ? c.ink : c.borderControl),
        borderRadius: BorderRadius.circular(PennyRadius.full),
      ),
      child: AnimatedAlign(
        duration: PennyMotion.short,
        curve: PennyMotion.enter,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _thumb,
          height: _thumb,
          decoration: BoxDecoration(
            color: value ? c.onInk : c.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PennySize.touchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PennySpace.s3),
        child: Row(
          children: [
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
            const SizedBox(width: PennySpace.s3),
            ExcludeSemantics(child: track),
          ],
        ),
      ),
    );
    return Semantics(
      toggled: value,
      child: onChanged == null
          ? content
          : PennyPressable(
              onPressed: () => onChanged(!value),
              contentColor: c.text,
              isButton: false,
              child: content,
            ),
    );
  }
}
