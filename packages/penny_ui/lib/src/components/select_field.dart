// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// A labelled field whose value is chosen rather than typed: a date, a
/// time, a tutor, a place. It looks like PennyTextField; tapping it opens
/// whatever picker [onTap] shows, such as showPennyChoice or the date
/// picker.
class PennySelectField extends StatelessWidget {
  /// Creates a select field.
  const PennySelectField({
    super.key,
    required this.label,
    this.value,
    this.placeholder,
    this.hint,
    this.error,
    required this.onTap,
    this.icon = PennyIcons.chevronDown,
    this.tabularFigures = false,
  });

  /// Always shown above the field.
  final String label;

  /// The chosen value, as words: "Thu 19 Nov". Null shows [placeholder].
  final String? value;

  /// What to show while nothing is chosen.
  final String? placeholder;

  /// Why the value is needed or what it does.
  final String? hint;

  /// What to fix; replaces [hint].
  final String? error;

  /// Opens the picker. Null disables the field.
  final VoidCallback? onTap;

  /// The mark at the end: a caret, or a calendar or clock.
  final IconData icon;

  /// Whether the value shows digits in a column, such as times and money.
  final bool tabularFigures;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final enabled = onTap != null;
    final hasError = error != null;
    final shown = value ?? placeholder ?? '';
    final box = Container(
      constraints: const BoxConstraints(minHeight: PennySize.controlHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: PennySpace.s3,
        vertical: PennySpace.s2,
      ),
      decoration: BoxDecoration(
        color: enabled ? c.surface : c.surfaceSunken,
        border: Border.all(
          color: hasError ? c.danger : (enabled ? c.borderControl : c.hairline),
          width: hasError ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(PennyRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              shown,
              style: PennyText.body.copyWith(
                color: value == null || !enabled ? c.textTertiary : c.text,
                fontFeatures: tabularFigures
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
          Icon(icon, size: PennyIconSize.standard, color: c.textSecondary),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: PennyText.smallStrong.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: PennySpace.s1),
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          value: value,
          hint: error ?? hint,
          child: ExcludeSemantics(
            child: enabled
                ? PennyPressable(
                    onPressed: onTap,
                    contentColor: c.text,
                    isButton: false,
                    child: box,
                  )
                : box,
          ),
        ),
        if (hasError || hint != null) ...[
          const SizedBox(height: PennySpace.s1),
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasError) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: PennySpace.s1 / 2),
                    child: Icon(
                      PennyIcons.warning,
                      size: PennyIconSize.badge,
                      color: c.danger,
                    ),
                  ),
                  const SizedBox(width: PennySpace.s1),
                ],
                Expanded(
                  child: Text(
                    error ?? hint!,
                    style: PennyText.small.copyWith(
                      color: hasError ? c.danger : c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
