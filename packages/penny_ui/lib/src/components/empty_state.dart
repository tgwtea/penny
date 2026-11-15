import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// What a screen says when it has nothing to show: what is empty, what is
/// next, and the obvious next step.
///
/// Filtered-empty is different from empty: say "No lessons match these
/// filters" and offer "Clear filters".
class PennyEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const PennyEmptyState({
    super.key,
    required this.title,
    this.body,
    this.action,
    this.art,
  });

  /// What is empty, in plain words: "No lessons today".
  final String title;

  /// What is next or why: "Your next lesson is Friday at 15:30."
  final String? body;

  /// The obvious next step, usually a PennyButton.
  final Widget? action;

  /// Pixel art, 64 by 64, scaled by whole numbers. The one place pixel art
  /// appears inside the working UI. Leave it out until the art exists.
  final Widget? art;

  static const double _artSize = 64;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: PennySpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art != null) ...[
            SizedBox.square(dimension: _artSize, child: art),
            const SizedBox(height: PennySpace.s4),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              style: PennyText.heading.copyWith(color: c.text),
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: PennySpace.s1),
            Text(body!, style: PennyText.body.copyWith(color: c.textSecondary)),
          ],
          if (action != null) ...[
            const SizedBox(height: PennySpace.s4),
            action!,
          ],
        ],
      ),
    );
  }
}
