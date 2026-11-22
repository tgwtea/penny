// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_ui/penny_ui.dart';

/// "Back" at the top of a detail page: to where the person came from, or
/// to [fallback] when they arrived by a link.
class BackLink extends StatelessWidget {
  /// Creates the link.
  const BackLink({super.key, required this.fallback, this.label = 'Back'});

  /// Where to go without history.
  final String fallback;

  /// The words.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PennyButton(
        label: label,
        icon: PennyIcons.back,
        variant: PennyButtonVariant.quiet,
        size: PennyButtonSize.compact,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(fallback),
      ),
    );
  }
}
