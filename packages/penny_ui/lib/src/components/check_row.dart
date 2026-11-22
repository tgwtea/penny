// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// A row that can be ticked: a task on a lesson, or one of several
/// students picked for it. The whole row is the target; ticked rows keep
/// their text and show the filled check box, so the state never rests on
/// colour alone.
class PennyCheckRow extends StatelessWidget {
  /// Creates a check row.
  const PennyCheckRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.checked,
    required this.onChanged,
    this.trailing = const [],
  });

  /// What is ticked: "Practise the tremolo".
  final String title;

  /// A supporting line, such as who added it.
  final String? subtitle;

  /// Whether it is ticked.
  final bool checked;

  /// Called with the new state. Null shows the row read-only.
  final ValueChanged<bool>? onChanged;

  /// Actions after the text, such as a menu.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final onChanged = this.onChanged;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PennySize.touchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PennySpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: PennySpace.s1 / 2),
              child: Icon(
                checked ? PennyIcons.taskDone : PennyIcons.taskOpen,
                size: PennyIconSize.standard,
                color: checked ? c.ink : c.textSecondary,
              ),
            ),
            const SizedBox(width: PennySpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PennyText.body.copyWith(color: c.text)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: PennyText.small.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
            for (final t in trailing) ...[
              const SizedBox(width: PennySpace.s2),
              t,
            ],
          ],
        ),
      ),
    );
    return Semantics(
      checked: checked,
      child: onChanged == null
          ? content
          : PennyPressable(
              onPressed: () => onChanged(!checked),
              contentColor: c.text,
              isButton: false,
              child: content,
            ),
    );
  }
}
