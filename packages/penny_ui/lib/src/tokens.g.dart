// GENERATED CODE. Do not edit by hand.
//
// Source: docs/design/tokens.json
// Generator: tools/design/bin/generate_tokens.dart
// Regenerate with `task gen:tokens`.

import 'package:flutter/material.dart';

/// Penny's colour tokens for one theme (ink and copper, ADR 020).
///
/// Read them with `PennyColors.of(context)`. Never write a colour
/// literal outside penny_ui.
@immutable
class PennyColors extends ThemeExtension<PennyColors> {
  /// Creates a colour set. Use [light] or [dark] instead.
  const PennyColors({
    required this.canvas,
    required this.surface,
    required this.surfaceSunken,
    required this.surfaceFloat,
    required this.hairline,
    required this.borderControl,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.ink,
    required this.onInk,
    required this.inkSubtle,
    required this.inkSubtleEdge,
    required this.copper,
    required this.copperText,
    required this.copperSubtle,
    required this.focusRing,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.scrim,
  });

  /// App background behind content: the page on phone, the area around panels on
  /// laptop.
  final Color canvas;

  /// Lists, panels, the timetable grid, inputs. Free timetable slots are plain
  /// surface: that is what makes them read as free.
  final Color surface;

  /// Recessed areas: segmented-control track, cancelled lesson blocks, neutral
  /// badges, notices.
  final Color surfaceSunken;

  /// Things that float: menus, sheets, dialogs, popovers. Always with
  /// shadow-float or shadow-overlay.
  final Color surfaceFloat;

  /// Decorative dividers and timetable grid lines. Never the only boundary of a
  /// control.
  final Color hairline;

  /// Boundaries of controls (inputs, secondary buttons, checkboxes). 3:1 or
  /// better on surface and canvas in both themes.
  final Color borderControl;

  /// Primary text on canvas, surface, surface-sunken, surface-float, ink-subtle
  /// and every *-subtle tint.
  final Color text;

  /// Supporting text (locations, counts, hints) on canvas, surface,
  /// surface-sunken and surface-float.
  final Color textSecondary;

  /// Least important text: timestamps, hour labels, placeholders, cancelled
  /// lessons. 4.5:1 on canvas, surface and surface-sunken in both themes.
  final Color textTertiary;

  /// The working colour: primary buttons, the active navigation item's icon,
  /// selected states.
  final Color ink;

  /// Text and icons on an ink fill.
  final Color onInk;

  /// Scheduled lesson blocks, selected rows, active navigation background,
  /// avatars.
  final Color inkSubtle;

  /// 1px edge of a scheduled lesson block so blocks stay distinct on the grid.
  final Color inkSubtleEdge;

  /// The penny. Only for now and today: the current-time line, today's date
  /// marker, and the brand mark. Never for buttons, links or status.
  final Color copper;

  /// Copper words: the current-time label and today's date. On surface, canvas
  /// and copper-subtle.
  final Color copperText;

  /// Background of today's column header and today's date in pickers.
  final Color copperSubtle;

  /// 2px keyboard focus ring, offset 2px. 3:1 or better on every surface in both
  /// themes.
  final Color focusRing;

  /// Completed lessons and paid requests, always with a check icon and a word.
  /// Text on surface and success-subtle.
  final Color success;

  /// Background of completed lesson blocks and paid badges.
  final Color successSubtle;

  /// No-shows and payments due soon, always with an icon and a word. Text on
  /// surface and warning-subtle.
  final Color warning;

  /// Background of no-show blocks and warning notices.
  final Color warningSubtle;

  /// Clashes, overdue payments, destructive actions, field errors, always with
  /// an icon and a word. Text on surface and danger-subtle.
  final Color danger;

  /// Background of clash badges, overdue badges and error notices.
  final Color dangerSubtle;

  /// Backdrop behind sheets and dialogs.
  final Color scrim;

  /// The light theme.
  static const light = PennyColors(
    canvas: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEEF0F3),
    surfaceFloat: Color(0xFFFFFFFF),
    hairline: Color(0xFFE1E4E9),
    borderControl: Color(0xFF848D9A),
    text: Color(0xFF16202B),
    textSecondary: Color(0xFF4A5565),
    textTertiary: Color(0xFF5F6979),
    ink: Color(0xFF1C2B3A),
    onInk: Color(0xFFFFFFFF),
    inkSubtle: Color(0xFFE6EBF1),
    inkSubtleEdge: Color(0xFFC3CCD7),
    copper: Color(0xFFB4532A),
    copperText: Color(0xFF9C4420),
    copperSubtle: Color(0xFFF8EAE2),
    focusRing: Color(0xFFB4532A),
    success: Color(0xFF25704A),
    successSubtle: Color(0xFFE6F2EB),
    warning: Color(0xFF8A5A00),
    warningSubtle: Color(0xFFFAF0D9),
    danger: Color(0xFFB42318),
    dangerSubtle: Color(0xFFFCEBE9),
    scrim: Color(0x66101828),
  );

  /// The dark theme.
  static const dark = PennyColors(
    canvas: Color(0xFF0F141A),
    surface: Color(0xFF161C23),
    surfaceSunken: Color(0xFF1C232C),
    surfaceFloat: Color(0xFF1E252E),
    hairline: Color(0xFF2A333E),
    borderControl: Color(0xFF6E7887),
    text: Color(0xFFECEFF3),
    textSecondary: Color(0xFFAEB6C2),
    textTertiary: Color(0xFF8C95A3),
    ink: Color(0xFFE6EBF1),
    onInk: Color(0xFF16202B),
    inkSubtle: Color(0xFF232D39),
    inkSubtleEdge: Color(0xFF3A4655),
    copper: Color(0xFFE07A4A),
    copperText: Color(0xFFEE9468),
    copperSubtle: Color(0xFF3A2219),
    focusRing: Color(0xFFE07A4A),
    success: Color(0xFF5CC48A),
    successSubtle: Color(0xFF16301F),
    warning: Color(0xFFE0B04A),
    warningSubtle: Color(0xFF33270F),
    danger: Color(0xFFF2766B),
    dangerSubtle: Color(0xFF3B1A18),
    scrim: Color(0x99000000),
  );

  /// The colours of the nearest Penny theme.
  static PennyColors of(BuildContext context) =>
      Theme.of(context).extension<PennyColors>()!;

  @override
  PennyColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSunken,
    Color? surfaceFloat,
    Color? hairline,
    Color? borderControl,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? ink,
    Color? onInk,
    Color? inkSubtle,
    Color? inkSubtleEdge,
    Color? copper,
    Color? copperText,
    Color? copperSubtle,
    Color? focusRing,
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    Color? scrim,
  }) {
    return PennyColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceFloat: surfaceFloat ?? this.surfaceFloat,
      hairline: hairline ?? this.hairline,
      borderControl: borderControl ?? this.borderControl,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      inkSubtle: inkSubtle ?? this.inkSubtle,
      inkSubtleEdge: inkSubtleEdge ?? this.inkSubtleEdge,
      copper: copper ?? this.copper,
      copperText: copperText ?? this.copperText,
      copperSubtle: copperSubtle ?? this.copperSubtle,
      focusRing: focusRing ?? this.focusRing,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  PennyColors lerp(PennyColors? other, double t) {
    if (other == null) return this;
    return PennyColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceFloat: Color.lerp(surfaceFloat, other.surfaceFloat, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      borderControl: Color.lerp(borderControl, other.borderControl, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      inkSubtle: Color.lerp(inkSubtle, other.inkSubtle, t)!,
      inkSubtleEdge: Color.lerp(inkSubtleEdge, other.inkSubtleEdge, t)!,
      copper: Color.lerp(copper, other.copper, t)!,
      copperText: Color.lerp(copperText, other.copperText, t)!,
      copperSubtle: Color.lerp(copperSubtle, other.copperSubtle, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Only things that float get a shadow. Lists, rows, panels and lesson blocks
/// are flat.
@immutable
class PennyShadows extends ThemeExtension<PennyShadows> {
  /// Creates a shadow set. Use [light] or [dark] instead.
  const PennyShadows({required this.float, required this.overlay});

  /// Menus, popovers, snackbars.
  final List<BoxShadow> float;

  /// Sheets and dialogs, above scrim.
  final List<BoxShadow> overlay;

  /// The light theme.
  static const light = PennyShadows(
    float: [
      BoxShadow(
        offset: Offset(0, 4),
        blurRadius: 12,
        spreadRadius: 0,
        color: Color(0x1A101828),
      ),
      BoxShadow(
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: 1,
        color: Color(0x0F101828),
      ),
    ],
    overlay: [
      BoxShadow(
        offset: Offset(0, 16),
        blurRadius: 40,
        spreadRadius: 0,
        color: Color(0x2E101828),
      ),
    ],
  );

  /// The dark theme.
  static const dark = PennyShadows(
    float: [
      BoxShadow(
        offset: Offset(0, 4),
        blurRadius: 12,
        spreadRadius: 0,
        color: Color(0x73000000),
      ),
      BoxShadow(
        offset: Offset(0, 0),
        blurRadius: 0,
        spreadRadius: 1,
        color: Color(0x0FFFFFFF),
      ),
    ],
    overlay: [
      BoxShadow(
        offset: Offset(0, 16),
        blurRadius: 40,
        spreadRadius: 0,
        color: Color(0x99000000),
      ),
    ],
  );

  /// The shadows of the nearest Penny theme.
  static PennyShadows of(BuildContext context) =>
      Theme.of(context).extension<PennyShadows>()!;

  @override
  PennyShadows copyWith({List<BoxShadow>? float, List<BoxShadow>? overlay}) {
    return PennyShadows(
      float: float ?? this.float,
      overlay: overlay ?? this.overlay,
    );
  }

  @override
  PennyShadows lerp(PennyShadows? other, double t) {
    if (other == null) return this;
    return PennyShadows(
      float: BoxShadow.lerpList(float, other.float, t)!,
      overlay: BoxShadow.lerpList(overlay, other.overlay, t)!,
    );
  }
}

/// Penny's type scale: IBM Plex Sans at weights 400 and 600.
///
/// Styles carry no colour; text takes it from the theme or the
/// component. Times and amounts use tabular figures.
abstract final class PennyText {
  /// The font family bundled with penny_ui.
  static const fontFamily = 'IBM Plex Sans';

  /// The package that bundles [fontFamily].
  static const fontPackage = 'penny_ui';

  /// One per screen at most: the date on Today, the screen title on laptop.
  /// Sample: "Thursday 19 November".
  static const display = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 28,
    height: 1.2143,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Screen titles on phone, sheet and dialog titles. Sample: "Lesson details".
  static const title = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Section headings inside a screen. Sample: "This afternoon".
  static const heading = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 17,
    height: 1.4118,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Default text, field values, notes. Sample: "Bring the scale book next
  /// week.".
  static const body = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 15,
    height: 1.4667,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Names in rows, button labels. Sample: "Mei Lin Tan".
  static const bodyStrong = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 15,
    height: 1.4667,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Supporting text: locations, hints, counts. Sample: "Studio room 2, Bukit
  /// Timah".
  static const small = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 13,
    height: 1.3846,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Badges, field labels, segmented control labels, names inside lesson blocks.
  /// Sample: "Completed".
  static const smallStrong = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 13,
    height: 1.3846,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Timetable hour labels, timestamps, bottom navigation labels. Sample:
  /// "Updated 2 min ago".
  static const caption = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 12,
    height: 1.3333,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Lesson times in rows. Always tabular figures (font-feature tnum). Sample:
  /// "16:30".
  static const time = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 15,
    height: 1.4667,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// The time spine on Today. Tabular figures. Sample: "16:30".
  static const timeLg = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Money. Tabular figures, currency prefix, two decimals. Sample: "S$ 240.00".
  static const amount = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 17,
    height: 1.4118,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Spacing on the 4 px grid. `s4` is the `space-4` token (16 px).
abstract final class PennySpace {
  /// `space-1`: Icon-to-label gap inside badges; gap between stacked avatars'
  /// rings.
  static const double s1 = 4;

  /// `space-2`: Gap between icon and label in buttons; inner padding of lesson
  /// blocks.
  static const double s2 = 8;

  /// `space-3`: Input side padding; gap between related controls.
  static const double s3 = 12;

  /// `space-4`: Screen side margins on phone; row padding; button side padding.
  static const double s4 = 16;

  /// `space-5`: Large button side padding.
  static const double s5 = 20;

  /// `space-6`: Gap between sections; panel padding on laptop.
  static const double s6 = 24;

  /// `space-8`: Screen side margins on laptop; gap before a screen's first
  /// section.
  static const double s8 = 32;

  /// `space-12`: Empty-state top padding.
  static const double s12 = 48;

  /// `space-16`: Largest gap; separates unrelated blocks on wide screens.
  static const double s16 = 64;
}

/// Corner radii, by hierarchy: badges, blocks, controls, panels, dialogs,
/// avatars.
abstract final class PennyRadius {
  /// `radius-xs`: Badges, tags.
  static const double xs = 4;

  /// `radius-sm`: Lesson blocks, segmented-control segments, menu items.
  static const double sm = 6;

  /// `radius-md`: Buttons, inputs, navigation items, notices.
  static const double md = 8;

  /// `radius-lg`: Panels on laptop, snackbars, popovers.
  static const double lg = 12;

  /// `radius-xl`: Dialogs; top corners of bottom sheets.
  static const double xl = 16;

  /// `radius-full`: Avatars and the now-line dot. Nothing else is fully round.
  static const double full = 9999;
}

/// Fixed dimensions shared by several components.
abstract final class PennySize {
  /// `touch-target`: Minimum tap area for anything interactive, even when the
  /// visual is smaller.
  static const double touchTarget = 48;

  /// `control-height`: Inputs and standard buttons.
  static const double controlHeight = 44;

  /// `control-height-sm`: Compact buttons and segmented control on laptop only.
  static const double controlHeightSm = 36;

  /// `bottom-nav-height`: Phone bottom navigation, plus the device safe area.
  static const double bottomNavHeight = 64;

  /// `sidebar-width`: Laptop sidebar.
  static const double sidebarWidth = 232;

  /// `timetable-hour`: Height of one hour in day and week timetables (16px per
  /// 15 minutes).
  static const double timetableHour = 64;

  /// `timetable-gutter`: Width of the hour-label column.
  static const double timetableGutter = 56;

  /// `content-max`: Maximum width of list and form content on wide screens. The
  /// timetable is not capped.
  static const double contentMax = 880;
}
