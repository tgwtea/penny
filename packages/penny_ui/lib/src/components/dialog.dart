// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/motion.dart';
import '../tokens.g.dart';
import 'button.dart';

/// Asks the person to confirm an action before it happens (docs/design,
/// DESIGN.md "Usability": destructive actions say what will happen first).
///
/// [title] is the question ("Delete your account?"); [body] says exactly
/// what will happen; [confirmLabel] repeats the action's verb ("Delete
/// account"). Resolves to true only when the person confirms.
Future<bool> showPennyConfirmation(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final c = PennyColors.of(context);
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: c.scrim,
    transitionDuration: PennyMotion.standard,
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: PennyMotion.enter,
        reverseCurve: PennyMotion.exit,
      ),
      child: child,
    ),
    pageBuilder: (context, _, _) => PennyDialog(
      title: title,
      body: Text(
        body,
        style: PennyText.body.copyWith(color: PennyColors.of(context).text),
      ),
      actions: [
        PennyButton(
          label: cancelLabel,
          variant: PennyButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PennyButton(
          label: confirmLabel,
          variant: destructive
              ? PennyButtonVariant.danger
              : PennyButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A dialog: a `surface-float` panel with `radius-xl` and `shadow-overlay`
/// above the scrim, a heading, content and actions on the right. Use
/// [showPennyConfirmation] for yes-or-no questions.
class PennyDialog extends StatelessWidget {
  /// Creates a dialog.
  const PennyDialog({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  /// The heading: a question or the dialog's purpose.
  final String title;

  /// The content.
  final Widget body;

  /// Buttons, the main one last.
  final List<Widget> actions;

  /// The widest a dialog gets, so lines stay readable.
  static const double maxWidth = 440;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(PennySpace.s4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceFloat,
                    borderRadius: BorderRadius.circular(PennyRadius.xl),
                    boxShadow: PennyShadows.of(context).overlay,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(PennySpace.s6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: PennyText.heading.copyWith(color: c.text),
                        ),
                        const SizedBox(height: PennySpace.s3),
                        Flexible(child: SingleChildScrollView(child: body)),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: PennySpace.s6),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: PennySpace.s2,
                              runSpacing: PennySpace.s2,
                              children: actions,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
