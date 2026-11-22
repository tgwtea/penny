// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// A row in a list of people or things: a leading avatar or icon, a title
/// with an optional short tag ("You"), a supporting line, and trailing
/// badges or actions. Rows sit on one surface, separated by PennyDivider,
/// never each in a card.
class PennyListRow extends StatelessWidget {
  /// Creates a row.
  const PennyListRow({
    super.key,
    this.leading,
    required this.title,
    this.tag,
    this.subtitle,
    this.trailing = const [],
    this.onTap,
  });

  /// An avatar or icon.
  final Widget? leading;

  /// The name: "Mei Lin Tan".
  final String title;

  /// A word after the title in `text-secondary`, such as "You".
  final String? tag;

  /// A supporting line, such as an email address.
  final String? subtitle;

  /// Badges, words or an action button, in order.
  final List<Widget> trailing;

  /// Opens the row's detail. Null for rows that only show.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PennySize.touchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PennySpace.s3),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: PennySpace.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: title),
                        if (tag != null)
                          TextSpan(
                            text: '  $tag',
                            style: PennyText.small.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    style: PennyText.bodyStrong.copyWith(color: c.text),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: PennyText.small.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            for (final t in trailing) ...[
              const SizedBox(width: PennySpace.s2),
              t,
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return PennyPressable(
      onPressed: onTap,
      contentColor: c.text,
      child: content,
    );
  }
}
