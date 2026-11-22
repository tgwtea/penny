// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/icons.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// The look of every demo-only control (DemoPersonaSwitcher guideline): a
/// dashed `warning` edge on `warning-subtle`, a flask and the words "Demo
/// data", so it can never be mistaken for part of the product.
///
/// [label] says what it does or shows ("Viewing as Daniel Koh").
class PennyDemoChip extends StatelessWidget {
  /// Creates a chip. Without [onPressed] it is a label only.
  const PennyDemoChip({super.key, required this.label, this.onPressed});

  /// What the chip shows after "Demo data".
  final String label;

  /// Opens the demo control, such as the persona list.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final content = CustomPaint(
      painter: _DashedBorder(color: c.warning, radius: PennyRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PennySpace.s3,
          vertical: PennySpace.s2,
        ),
        decoration: BoxDecoration(
          color: c.warningSubtle,
          borderRadius: BorderRadius.circular(PennyRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PennyIcons.demo, size: PennyIconSize.standard, color: c.text),
            const SizedBox(width: PennySpace.s2),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Demo data',
                      style: PennyText.smallStrong.copyWith(color: c.text),
                    ),
                    TextSpan(
                      text: '\n$label',
                      style: PennyText.small.copyWith(color: c.text),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onPressed != null) ...[
              const SizedBox(width: PennySpace.s2),
              Icon(
                PennyIcons.chevronDown,
                size: PennyIconSize.standard,
                color: c.text,
              ),
            ],
          ],
        ),
      ),
    );
    if (onPressed == null) return content;
    return PennyPressable(
      onPressed: onPressed,
      contentColor: c.text,
      child: content,
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;
  static const double _width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(_width / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
