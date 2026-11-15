import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// How much weight a [PennyButton] carries.
enum PennyButtonVariant {
  /// Ink fill: the one thing a screen is for. At most one per screen.
  primary,

  /// Outlined: an alternative beside a primary.
  secondary,

  /// No fill: row-level and toolbar actions, icon plus word.
  quiet,

  /// Danger text and edge: destructive actions, always confirmed after.
  danger,
}

/// The height of a [PennyButton].
enum PennyButtonSize {
  /// 44 px, `control-height`. The default.
  standard,

  /// 48 px, for the main action in sheets on phone.
  large,

  /// 36 px, `control-height-sm`. Laptop toolbars only.
  compact,
}

/// One action, named by its verb in sentence case: "Add lesson", never "OK"
/// or "Submit".
class PennyButton extends StatelessWidget {
  /// Creates a button. A null [onPressed] disables it.
  const PennyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PennyButtonVariant.primary,
    this.size = PennyButtonSize.standard,
    this.icon,
    this.expand = false,
  });

  /// The verb, for example "Mark done".
  final String label;

  /// Called when the button is activated. Null disables it.
  final VoidCallback? onPressed;

  /// Visual weight.
  final PennyButtonVariant variant;

  /// Height.
  final PennyButtonSize size;

  /// Optional leading icon, from PennyIcons.
  final IconData? icon;

  /// Fill the available width. Only inside sheets on phone.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final enabled = onPressed != null;

    final (Color fill, Color content, Color? edge) = switch (variant) {
      PennyButtonVariant.primary =>
        enabled
            ? (c.ink, c.onInk, null)
            : (c.surfaceSunken, c.textTertiary, null),
      PennyButtonVariant.secondary => (
        c.surface,
        enabled ? c.text : c.textTertiary,
        enabled ? c.borderControl : c.hairline,
      ),
      PennyButtonVariant.quiet => (
        Colors.transparent,
        enabled ? c.text : c.textTertiary,
        null,
      ),
      PennyButtonVariant.danger => (
        c.surface,
        enabled ? c.danger : c.textTertiary,
        enabled ? c.danger : c.hairline,
      ),
    };

    final (double height, double padding) = switch (size) {
      PennyButtonSize.standard => (PennySize.controlHeight, PennySpace.s4),
      PennyButtonSize.large => (PennySize.touchTarget, PennySpace.s5),
      PennyButtonSize.compact => (PennySize.controlHeightSm, PennySpace.s3),
    };
    final quietPadding = variant == PennyButtonVariant.quiet
        ? PennySpace.s3
        : padding;
    const radius = BorderRadius.all(Radius.circular(PennyRadius.md));

    final labelText = Text(
      label,
      style: PennyText.bodyStrong.copyWith(color: content),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return PennyPressable(
      onPressed: onPressed,
      contentColor: content,
      borderRadius: radius,
      child: Container(
        constraints: BoxConstraints(
          minHeight: height,
          minWidth: expand ? double.infinity : 0,
        ),
        padding: EdgeInsets.symmetric(horizontal: quietPadding),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: edge == null ? null : Border.all(color: edge),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: PennyIconSize.standard, color: content),
              const SizedBox(width: PennySpace.s2),
            ],
            Flexible(child: labelText),
          ],
        ),
      ),
    );
  }
}

/// A square button showing only an icon. The tooltip doubles as the
/// semantic label, so both are always present.
class PennyIconButton extends StatelessWidget {
  /// Creates an icon-only button. A null [onPressed] disables it.
  const PennyIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  /// The icon, from PennyIcons.
  final IconData icon;

  /// What the button does, for example "Mark done". Shown on hover and long
  /// press, and read by screen readers.
  final String tooltip;

  /// Called when the button is activated. Null disables it.
  final VoidCallback? onPressed;

  /// Icon colour. Defaults to `text-secondary`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final content = onPressed == null
        ? c.textTertiary
        : (color ?? c.textSecondary);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: PennyPressable(
        onPressed: onPressed,
        contentColor: content,
        semanticLabel: tooltip,
        child: SizedBox.square(
          dimension: PennySize.controlHeight,
          child: Icon(icon, size: PennyIconSize.standard, color: content),
        ),
      ),
    );
  }
}
