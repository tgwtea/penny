import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../tokens.g.dart';

/// The interaction layer shared by every tappable Penny component.
///
/// It gives [child] the behaviour the brand book asks of every control:
///
/// - hover and pressed states as an 8% and 12% overlay of [contentColor],
///   never a colour change or a ripple;
/// - a solid 2 px copper focus ring, offset 2 px, shown only when focus
///   came from the keyboard;
/// - a hit area of at least [PennySize.touchTarget] even when the visual
///   is smaller;
/// - activation with Enter and Space, a click cursor, and button semantics.
class PennyPressable extends StatefulWidget {
  /// Wraps [child], which draws the control's resting look.
  const PennyPressable({
    super.key,
    required this.child,
    required this.onPressed,
    required this.contentColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(PennyRadius.md)),
    this.semanticLabel,
    this.selected,
    this.isButton = true,
    this.focusNode,
    this.autofocus = false,
    this.minHitSize = PennySize.touchTarget,
  });

  /// The control's resting look. Its size is the visual size.
  final Widget child;

  /// Called on tap, Enter or Space. Null disables the control.
  final VoidCallback? onPressed;

  /// The label or icon colour; overlays are drawn in it.
  final Color contentColor;

  /// The shape of the overlay and the focus ring.
  final BorderRadius borderRadius;

  /// Replaces the semantics of [child] when it has no readable text, such as
  /// an icon-only button.
  final String? semanticLabel;

  /// Whether the control is the selected one of a group (navigation items,
  /// segments). Null for controls that are never selected.
  final bool? selected;

  /// Whether assistive technology should announce this as a button.
  final bool isButton;

  /// Optional focus node, for callers that move focus themselves.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The smallest hit area in each direction. The visual is centred in it.
  final double minHitSize;

  @override
  State<PennyPressable> createState() => _PennyPressableState();
}

class _PennyPressableState extends State<PennyPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  void didUpdateWidget(PennyPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PennyColors.of(context);
    final overlayAlpha = !_enabled
        ? 0.0
        : _pressed
        ? 0.12
        : _hovered
        ? 0.08
        : 0.0;

    Widget visual = CustomPaint(
      foregroundPainter: _InteractionPainter(
        overlay: widget.contentColor.withValues(alpha: overlayAlpha),
        focusRing: _focused ? colors.focusRing : null,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );

    if (widget.minHitSize > 0) {
      visual = _MinHitArea(minSize: widget.minHitSize, child: visual);
    }

    return FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _activate(),
        ),
      },
      child: Semantics(
        button: widget.isButton,
        enabled: _enabled,
        selected: widget.selected,
        label: widget.semanticLabel,
        excludeSemantics: widget.semanticLabel != null,
        onTap: _enabled ? _activate : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: _enabled ? _activate : null,
          child: visual,
        ),
      ),
    );
  }
}

class _InteractionPainter extends CustomPainter {
  const _InteractionPainter({
    required this.overlay,
    required this.focusRing,
    required this.borderRadius,
  });

  final Color overlay;
  final Color? focusRing;
  final BorderRadius borderRadius;

  static const double _ringWidth = 2;
  static const double _ringOffset = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (overlay.a > 0) {
      canvas.drawRRect(borderRadius.toRRect(rect), Paint()..color = overlay);
    }
    final ring = focusRing;
    if (ring != null) {
      // The stroke is centred on its path, so inflate by offset plus half
      // the width to leave a clear 2 px gap.
      const inflate = _ringOffset + _ringWidth / 2;
      final outer = borderRadius.toRRect(rect).inflate(inflate);
      canvas.drawRRect(
        outer,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_InteractionPainter old) =>
      old.overlay != overlay ||
      old.focusRing != focusRing ||
      old.borderRadius != borderRadius;
}

/// Grows the hit area to at least [minSize] square without changing how the
/// child is laid out: the child gets the parent's constraints as they are,
/// is centred, and taps in the margin around it reach it too.
class _MinHitArea extends SingleChildRenderObjectWidget {
  const _MinHitArea({required this.minSize, required Widget super.child});

  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinHitArea(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMinHitArea renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

class _RenderMinHitArea extends RenderShiftedBox {
  _RenderMinHitArea(this._minSize) : super(null);

  double _minSize;
  set minSize(double value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(
        child.size.width < _minSize ? _minSize : child.size.width,
        child.size.height < _minSize ? _minSize : child.size.height,
      ),
    );
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(
      size - child.size as Offset,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height) ?? 0).clamp(
        _minSize,
        double.infinity,
      );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height) ?? 0).clamp(
        _minSize,
        double.infinity,
      );

  @override
  double computeMinIntrinsicHeight(double width) =>
      (child?.getMinIntrinsicHeight(width) ?? 0).clamp(
        _minSize,
        double.infinity,
      );

  @override
  double computeMaxIntrinsicHeight(double width) =>
      (child?.getMaxIntrinsicHeight(width) ?? 0).clamp(
        _minSize,
        double.infinity,
      );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childSize = child?.getDryLayout(constraints) ?? Size.zero;
    return constraints.constrain(
      Size(
        childSize.width < _minSize ? _minSize : childSize.width,
        childSize.height < _minSize ? _minSize : childSize.height,
      ),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final child = this.child!;
    final offset = (child.parentData! as BoxParentData).offset;
    // Inside the child: an ordinary hit test, so nested controls still work.
    if ((offset & child.size).contains(position)) {
      if (super.hitTest(result, position: position)) return true;
    }
    // In the margin: count it as a tap on the child's centre.
    final center = child.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, position) => child.hitTest(result, position: center),
    );
  }
}
