import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny_ui/penny_ui.dart';

/// WCAG 2.2 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

typedef _Pairing = (
  String fg,
  Color Function(PennyColors) fgOf,
  String bg,
  Color Function(PennyColors) bgOf,
);

/// Every pairing the token usage notes promise (docs/design/tokens.json).
/// Text needs 4.5:1; control boundaries and the focus ring need 3:1.
final _text = <_Pairing>[
  for (final (name, bg) in <(String, Color Function(PennyColors))>[
    ('canvas', (c) => c.canvas),
    ('surface', (c) => c.surface),
    ('surface-sunken', (c) => c.surfaceSunken),
    ('surface-float', (c) => c.surfaceFloat),
    ('ink-subtle', (c) => c.inkSubtle),
    ('success-subtle', (c) => c.successSubtle),
    ('warning-subtle', (c) => c.warningSubtle),
    ('danger-subtle', (c) => c.dangerSubtle),
    ('copper-subtle', (c) => c.copperSubtle),
  ])
    ('text', (c) => c.text, name, bg),
  for (final (name, bg) in <(String, Color Function(PennyColors))>[
    ('canvas', (c) => c.canvas),
    ('surface', (c) => c.surface),
    ('surface-sunken', (c) => c.surfaceSunken),
    ('surface-float', (c) => c.surfaceFloat),
  ])
    ('text-secondary', (c) => c.textSecondary, name, bg),
  for (final (name, bg) in <(String, Color Function(PennyColors))>[
    ('canvas', (c) => c.canvas),
    ('surface', (c) => c.surface),
    ('surface-sunken', (c) => c.surfaceSunken),
  ])
    ('text-tertiary', (c) => c.textTertiary, name, bg),
  ('on-ink', (c) => c.onInk, 'ink', (c) => c.ink),
  ('copper-text', (c) => c.copperText, 'surface', (c) => c.surface),
  ('copper-text', (c) => c.copperText, 'canvas', (c) => c.canvas),
  ('copper-text', (c) => c.copperText, 'copper-subtle', (c) => c.copperSubtle),
  ('success', (c) => c.success, 'surface', (c) => c.surface),
  ('success', (c) => c.success, 'success-subtle', (c) => c.successSubtle),
  ('warning', (c) => c.warning, 'surface', (c) => c.surface),
  ('warning', (c) => c.warning, 'warning-subtle', (c) => c.warningSubtle),
  ('danger', (c) => c.danger, 'surface', (c) => c.surface),
  ('danger', (c) => c.danger, 'danger-subtle', (c) => c.dangerSubtle),
];

final _boundaries = <_Pairing>[
  ('border-control', (c) => c.borderControl, 'surface', (c) => c.surface),
  ('border-control', (c) => c.borderControl, 'canvas', (c) => c.canvas),
  ('focus-ring', (c) => c.focusRing, 'canvas', (c) => c.canvas),
  ('focus-ring', (c) => c.focusRing, 'surface', (c) => c.surface),
  ('focus-ring', (c) => c.focusRing, 'surface-sunken', (c) => c.surfaceSunken),
  ('focus-ring', (c) => c.focusRing, 'surface-float', (c) => c.surfaceFloat),
];

void main() {
  for (final (theme, colors) in [
    ('light', PennyColors.light),
    ('dark', PennyColors.dark),
  ]) {
    group('$theme theme', () {
      for (final (fg, fgOf, bg, bgOf) in _text) {
        test('$fg on $bg is at least 4.5:1', () {
          expect(
            contrast(fgOf(colors), bgOf(colors)),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
      for (final (fg, fgOf, bg, bgOf) in _boundaries) {
        test('$fg on $bg is at least 3:1', () {
          expect(contrast(fgOf(colors), bgOf(colors)), greaterThanOrEqualTo(3));
        });
      }
    });
  }
}
