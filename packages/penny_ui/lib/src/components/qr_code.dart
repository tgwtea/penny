// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../tokens.g.dart';

/// A QR code for [data], such as a PayNow payload, drawn in modules of
/// whole pixels with the four-module quiet zone scanners need.
///
/// It is always dark on light, in both themes: banking apps read a light
/// ground most reliably, so in the dark theme the code keeps the light
/// theme's `text` on `surface` and shows as a light square.
class PennyQrCode extends StatelessWidget {
  /// Creates a code for [data], [size] logical pixels square including the
  /// quiet zone, read out to screen readers as [semanticLabel].
  const PennyQrCode({
    super.key,
    required this.data,
    required this.semanticLabel,
    this.size = defaultSize,
  });

  /// What the code holds.
  final String data;

  /// What a screen reader says: "PayNow code for S$ 240.00".
  final String semanticLabel;

  /// The side of the square, quiet zone included.
  final double size;

  /// A size that scans from a phone held at arm's length on another
  /// screen, and still fits a phone's column with room around it.
  static const double defaultSize = 240;

  /// Modules of empty light space around the code (ISO 18004).
  static const int quietZone = 4;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _QrPainter(
              image,
              dark: PennyColors.light.text,
              light: PennyColors.light.surface,
            ),
          ),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image, {required this.dark, required this.light});

  final QrImage image;
  final Color dark;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final modules = image.moduleCount + 2 * PennyQrCode.quietZone;
    // Whole pixels per module, so edges stay sharp; the rest of the space
    // is shared out as extra margin.
    final module = (size.shortestSide / modules).floorToDouble().clamp(
      1.0,
      double.infinity,
    );
    final drawn = module * image.moduleCount;
    final origin = Offset(
      ((size.width - drawn) / 2).roundToDouble(),
      ((size.height - drawn) / 2).roundToDouble(),
    );
    final paint = Paint()
      ..color = dark
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
              origin.dx + col * module,
              origin.dy + row * module,
              module,
              module,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.dark != dark || old.light != light || old.image != image;
}
