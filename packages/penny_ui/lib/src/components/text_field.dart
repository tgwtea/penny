import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/icons.dart';
import '../tokens.g.dart';

/// A labelled single-line input.
///
/// The label is always visible above the field; the placeholder is never the
/// label. Validate on blur and on submit, never while the person is typing:
/// set [error] from [onEditingComplete] or the field's focus node.
class PennyTextField extends StatelessWidget {
  /// Creates a text field.
  const PennyTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.error,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.autofillHints,
    this.prefixIcon,
    this.tabularFigures = false,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
  });

  /// What the value is, shown above the field: "Email".
  final String label;

  /// Holds the text.
  final TextEditingController? controller;

  /// Focus for the input itself.
  final FocusNode? focusNode;

  /// Why the value is needed or where it goes. Replaced by [error].
  final String? hint;

  /// What to do to fix the value, starting with the action: "Enter an email
  /// address with an @". Shown with a warning icon.
  final String? error;

  /// Example text inside the empty field.
  final String? placeholder;

  /// Keyboard to show; numeric for phone numbers, amounts and times.
  final TextInputType? keyboardType;

  /// The keyboard's action key.
  final TextInputAction? textInputAction;

  /// Restricts what can be typed.
  final List<TextInputFormatter>? inputFormatters;

  /// Hides the text, for passwords.
  final bool obscureText;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Autofill hints such as [AutofillHints.email].
  final Iterable<String>? autofillHints;

  /// Optional icon inside the field's start, such as search.
  final IconData? prefixIcon;

  /// Use tabular figures, for times, amounts and phone numbers.
  final bool tabularFigures;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the person finishes editing (validate here).
  final VoidCallback? onEditingComplete;

  /// Called when the person submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final hasError = error != null;
    const radius = BorderRadius.all(Radius.circular(PennyRadius.md));

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );

    final valueStyle = PennyText.body.copyWith(
      color: enabled ? c.text : c.textTertiary,
      fontFeatures: tabularFigures
          ? const [FontFeature.tabularFigures()]
          : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          label: label,
          hint: error ?? hint,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            autofillHints: autofillHints,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            onSubmitted: onSubmitted,
            style: valueStyle,
            cursorColor: c.ink,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: enabled ? c.surface : c.surfaceSunken,
              hintText: placeholder,
              hintStyle: PennyText.body.copyWith(color: c.textTertiary),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(
                      prefixIcon,
                      size: PennyIconSize.standard,
                      color: c.textSecondary,
                    ),
              constraints: const BoxConstraints(
                minHeight: PennySize.controlHeight,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: PennySpace.s3,
                vertical: PennySpace.s3,
              ),
              border: border(c.borderControl, 1),
              enabledBorder: hasError
                  ? border(c.danger, 2)
                  : border(c.borderControl, 1),
              disabledBorder: border(c.hairline, 1),
              focusedBorder: border(hasError ? c.danger : c.focusRing, 2),
              errorBorder: border(c.danger, 2),
              focusedErrorBorder: border(c.danger, 2),
            ),
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
