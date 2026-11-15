import 'package:flutter/material.dart';

import '../foundation/layout.dart';
import '../foundation/motion.dart';
import '../tokens.g.dart';

/// Brief confirmations after an action, through the app's single
/// ScaffoldMessenger. One at a time: a new one replaces the current one.
abstract final class PennySnackbar {
  /// The width of a snackbar on laptop, where it sits bottom left of the
  /// content instead of spanning the screen.
  static const double _laptopWidth = 400;

  /// Shows [message], which repeats the action's verb in the past tense:
  /// "Lesson marked done". Pass [onUndo] for anything that changed or removed
  /// data; Undo then stays available for six seconds.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    VoidCallback? onUndo,
  }) {
    final c = PennyColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = PennyLayout.isWide(context);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: PennyText.body.copyWith(color: c.onInk)),
        action: onUndo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                textColor: c.onInk,
                onPressed: onUndo,
              ),
        duration: onUndo == null
            ? const Duration(seconds: 4)
            : PennyMotion.undoWindow,
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PennyRadius.lg),
        ),
        margin: wide
            ? EdgeInsets.only(
                left: PennySize.sidebarWidth + PennySpace.s8,
                right:
                    (width -
                            PennySize.sidebarWidth -
                            PennySpace.s8 -
                            _laptopWidth)
                        .clamp(PennySpace.s8, double.infinity),
                bottom: PennySpace.s6,
              )
            : const EdgeInsets.fromLTRB(
                PennySpace.s4,
                0,
                PennySpace.s4,
                PennySpace.s4,
              ),
      ),
    );
  }
}
