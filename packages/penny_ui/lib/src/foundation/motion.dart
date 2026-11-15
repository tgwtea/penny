import 'package:flutter/widgets.dart';

/// Motion tokens (brand book, "Motion"). Motion only answers an action: a
/// sheet rising, a lesson moving, a row collapsing. Nothing animates on load
/// and nothing loops.
abstract final class PennyMotion {
  /// Small changes: a badge appearing, a hover.
  static const Duration short = Duration(milliseconds: 150);

  /// The default for moving and resizing.
  static const Duration standard = Duration(milliseconds: 200);

  /// Sheets and dialogs.
  static const Duration sheet = Duration(milliseconds: 250);

  /// How long Undo stays available after a change.
  static const Duration undoWindow = Duration(seconds: 6);

  /// Curve for things entering.
  static const Curve enter = Curves.easeOut;

  /// Curve for things leaving.
  static const Curve exit = Curves.easeIn;

  /// [duration], or zero when the platform asks for reduced motion, which
  /// cuts straight to the end state.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
