// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// A `hairline` rule between content, optionally with a word in the middle
/// ("or" between sign-in methods). Separate content with space first; use a
/// divider when space alone does not group it.
class PennyDivider extends StatelessWidget {
  /// Creates a divider.
  const PennyDivider({super.key, this.label});

  /// A short word centred on the rule.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final rule = Expanded(child: Container(height: 1, color: c.hairline));
    if (label == null) return Row(children: [rule]);
    return Row(
      children: [
        rule,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PennySpace.s3),
          child: Text(
            label!,
            style: PennyText.small.copyWith(color: c.textSecondary),
          ),
        ),
        rule,
      ],
    );
  }
}
