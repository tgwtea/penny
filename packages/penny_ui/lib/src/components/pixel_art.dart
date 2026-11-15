import 'package:flutter/widgets.dart';

/// Pixel art at a whole-number scale with nearest-neighbour sampling, so
/// pixel edges stay crisp (brand book, "Brand mark").
///
/// Pixel art appears only at brand moments: the app icon, splash, sign-in
/// and empty states. Never in buttons or navigation.
class PennyPixelArt extends StatelessWidget {
  /// Draws [image], whose native size is [pixels] by [pixels], at [scale].
  const PennyPixelArt({
    super.key,
    required this.image,
    required this.pixels,
    required this.scale,
    required this.semanticLabel,
  }) : assert(scale >= 1, 'Scale by whole numbers of at least 1.');

  /// The art at its native size.
  final ImageProvider image;

  /// The art's native width and height in pixels.
  final int pixels;

  /// The whole-number factor to draw it at.
  final int scale;

  /// What the art shows, for screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Logical pixels: at a device pixel ratio that is not a whole number the
    // art can still land between device pixels, which is why the brand book
    // asks for whole-number factors of the native grid.
    final size = (pixels * scale).toDouble();
    return Image(
      image: image,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      semanticLabel: semanticLabel,
    );
  }
}
