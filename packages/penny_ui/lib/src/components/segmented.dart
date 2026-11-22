// ignore: deprecated_member_use, see docs/adr/023-stay-on-the-sdk-material-library.md
import 'package:flutter/material.dart';

import '../foundation/motion.dart';
import '../foundation/pressable.dart';
import '../tokens.g.dart';

/// One option of a [PennySegmented].
@immutable
class PennySegment<T> {
  /// Creates a segment.
  const PennySegment({required this.value, required this.label});

  /// The value selected by this segment.
  final T value;

  /// One or two words: "Day", "Whole team".
  final String label;
}

/// Switches between two to four views of the same content (Day, Week,
/// Month). For moving between different things, use navigation instead.
class PennySegmented<T> extends StatelessWidget {
  /// Creates a segmented control.
  const PennySegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  }) : assert(
         segments.length >= 2 && segments.length <= 4,
         'Use two to four segments.',
       );

  /// The options, in order.
  final List<PennySegment<T>> segments;

  /// The value of the selected segment.
  final T selected;

  /// Called with the chosen value.
  final ValueChanged<T> onChanged;

  /// 36 px segments for laptop toolbars; 40 px otherwise.
  final bool compact;

  static const double _segmentHeight = 40;
  static const double _trackPadding = 2;

  @override
  Widget build(BuildContext context) {
    final c = PennyColors.of(context);
    final height = compact ? PennySize.controlHeightSm : _segmentHeight;
    const radius = BorderRadius.all(Radius.circular(PennyRadius.sm));

    return Container(
      padding: const EdgeInsets.all(_trackPadding),
      decoration: BoxDecoration(
        color: c.surfaceSunken,
        borderRadius: BorderRadius.circular(PennyRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final segment in segments)
            Flexible(
              child: PennyPressable(
                onPressed: segment.value == selected
                    ? () {}
                    : () => onChanged(segment.value),
                contentColor: c.text,
                borderRadius: radius,
                selected: segment.value == selected,
                // The track supplies the rest of the 48 px hit area.
                minHitSize: height,
                child: AnimatedContainer(
                  duration: PennyMotion.of(context, PennyMotion.short),
                  height: height - _trackPadding * 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: PennySpace.s3,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: segment.value == selected
                        ? c.surface
                        : Colors.transparent,
                    borderRadius: radius,
                    border: Border.all(
                      color: segment.value == selected
                          ? c.hairline
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PennyText.smallStrong.copyWith(
                      color: segment.value == selected
                          ? c.text
                          : c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
