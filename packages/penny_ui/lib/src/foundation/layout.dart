import 'package:flutter/widgets.dart';

/// Layout breakpoints from the brand book, "Layout".
abstract final class PennyLayout {
  /// From this width up: sidebar navigation, content capped at
  /// `content-max`, detail in a side panel. Below it: bottom navigation, one
  /// column, sheets for creating and editing.
  static const double wideBreakpoint = 600;

  /// Whether [context] is at tablet or laptop width.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;
}
