import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// A placeholder shaped like the content that is loading, in
/// `surface-sunken`. Lists show skeleton rows, never spinners. It does not
/// shimmer: Penny has no looping motion.
class PennySkeleton extends StatelessWidget {
  /// A block of the given size.
  const PennySkeleton({super.key, this.width, required this.height});

  /// Width; null fills the available width.
  final double? width;

  /// Height.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PennyColors.of(context).surfaceSunken,
        borderRadius: BorderRadius.circular(PennyRadius.xs),
      ),
    );
  }
}

/// A loading row shaped like a LessonRow: a time on the left and two lines
/// of text.
class PennySkeletonRow extends StatelessWidget {
  /// Creates a skeleton row.
  const PennySkeletonRow({super.key});

  static const double _timeWidth = 48;
  static const double _lineHeight = 14;
  static const double _timeHeight = 20;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: PennySpace.s4,
          vertical: PennySpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PennySkeleton(width: _timeWidth, height: _timeHeight),
            SizedBox(width: PennySpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: PennySkeleton(height: _lineHeight),
                  ),
                  SizedBox(height: PennySpace.s2),
                  FractionallySizedBox(
                    widthFactor: 0.4,
                    child: PennySkeleton(height: _lineHeight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
