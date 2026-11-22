// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// The sizes an avatar comes in.
enum PennyAvatarSize {
  /// 24 px: inside lesson blocks and dense rows.
  small(24, PennyText.caption),

  /// 32 px: list rows and column headers.
  medium(32, PennyText.smallStrong),

  /// 40 px: the account in the top bar and sidebar.
  large(40, PennyText.bodyStrong);

  const PennyAvatarSize(this.dimension, this.textStyle);

  /// Diameter in logical pixels.
  final double dimension;

  /// Style of the initials.
  final TextStyle textStyle;
}

/// A person as initials in a circle.
///
/// Every avatar uses the same colours: people are not colour-coded, because
/// colour in Penny means status. An avatar is never the only way to identify
/// someone; a name sits beside it, and it carries the name for screen readers.
class PennyAvatar extends StatelessWidget {
  /// Creates an avatar for [name].
  const PennyAvatar({
    super.key,
    required this.name,
    this.size = PennyAvatarSize.medium,
  });

  /// The person's full name.
  final String name;

  /// The diameter.
  final PennyAvatarSize size;

  /// Two initials from the first and last name parts, one for a single word.
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    if (parts.length == 1) return first.toUpperCase();
    return (first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size.dimension,
        height: size.dimension,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.inkSubtle, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: size.textStyle.copyWith(color: c.text, height: 1),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

/// Several people on one lesson: avatars overlapping by 6 px, each with a
/// 2 px `surface` ring. Always shown next to the names in text.
class PennyAvatarStack extends StatelessWidget {
  /// Creates a stack of avatars for [names].
  const PennyAvatarStack({
    super.key,
    required this.names,
    this.size = PennyAvatarSize.small,
  });

  /// Full names, in display order.
  final List<String> names;

  /// The diameter of each avatar.
  final PennyAvatarSize size;

  static const double _overlap = 6;
  static const double _ring = 2;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final step = size.dimension + _ring * 2 - _overlap;
    return SizedBox(
      height: size.dimension + _ring * 2,
      width: names.isEmpty
          ? 0
          : step * (names.length - 1) + size.dimension + _ring * 2,
      child: Stack(
        children: [
          for (var i = 0; i < names.length; i++)
            Positioned(
              left: step * i,
              child: Container(
                padding: const EdgeInsets.all(_ring),
                decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                ),
                child: PennyAvatar(name: names[i], size: size),
              ),
            ),
        ],
      ),
    );
  }
}
