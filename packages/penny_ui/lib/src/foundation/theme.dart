import 'package:flutter/material.dart';

import '../tokens.g.dart';

/// Builds Penny's Material 3 themes from the design tokens.
///
/// Material supplies behaviour (text editing, scrolling, routes, dialogs);
/// the look comes from the tokens. Material's own colour roles are mapped so
/// any stock widget that slips through still looks like Penny, but feature
/// code should use penny_ui components and [PennyColors] directly.
abstract final class PennyTheme {
  /// The light theme.
  static ThemeData light() =>
      _build(Brightness.light, PennyColors.light, PennyShadows.light);

  /// The dark theme: the same token names with dark values, not an inversion.
  static ThemeData dark() =>
      _build(Brightness.dark, PennyColors.dark, PennyShadows.dark);

  static ThemeData _build(
    Brightness brightness,
    PennyColors c,
    PennyShadows shadows,
  ) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.onInk,
      primaryContainer: c.inkSubtle,
      onPrimaryContainer: c.text,
      secondary: c.ink,
      onSecondary: c.onInk,
      secondaryContainer: c.inkSubtle,
      onSecondaryContainer: c.text,
      tertiary: c.ink,
      onTertiary: c.onInk,
      error: c.danger,
      onError: c.onInk,
      errorContainer: c.dangerSubtle,
      onErrorContainer: c.text,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textSecondary,
      surfaceDim: c.canvas,
      surfaceBright: c.surface,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surfaceSunken,
      surfaceContainerHigh: c.surfaceFloat,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.borderControl,
      outlineVariant: c.hairline,
      shadow: Colors.black,
      scrim: c.scrim,
      inverseSurface: c.ink,
      onInverseSurface: c.onInk,
      inversePrimary: c.inkSubtle,
      // Material 3 tints raised surfaces with the primary colour. Penny's
      // surfaces stay flat and neutral.
      surfaceTint: Colors.transparent,
    );

    final textTheme = TextTheme(
      displaySmall: PennyText.display,
      headlineSmall: PennyText.title,
      titleLarge: PennyText.title,
      titleMedium: PennyText.heading,
      titleSmall: PennyText.bodyStrong,
      bodyLarge: PennyText.body,
      bodyMedium: PennyText.body,
      bodySmall: PennyText.small,
      labelLarge: PennyText.bodyStrong,
      labelMedium: PennyText.smallStrong,
      labelSmall: PennyText.caption,
    ).apply(bodyColor: c.text, displayColor: c.text);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PennyRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: PennyText.fontFamily,
      package: PennyText.fontPackage,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.surface,
      dividerColor: c.hairline,
      disabledColor: c.textTertiary,
      // No ripples: pressed and hovered states are 8% and 12% overlays of
      // the content colour, drawn by the components.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: c.text.withValues(alpha: 0.12),
      hoverColor: c.text.withValues(alpha: 0.08),
      // Components draw their own copper focus ring.
      focusColor: Colors.transparent,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [c, shadows],
      iconTheme: IconThemeData(color: c.textSecondary, size: 20),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.inkSubtle,
        selectionHandleColor: c.ink,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(PennyRadius.sm),
        ),
        textStyle: PennyText.small.copyWith(color: c.onInk),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: PennyText.body.copyWith(color: c.onInk),
        actionTextColor: c.onInk,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PennyRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceFloat,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PennyRadius.xl),
        ),
        titleTextStyle: PennyText.title.copyWith(color: c.text),
        contentTextStyle: PennyText.body.copyWith(color: c.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceFloat,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: c.borderControl,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PennyRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceFloat,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: PennyText.body.copyWith(color: c.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PennyRadius.lg),
          side: BorderSide(color: c.hairline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: PennyText.title.copyWith(color: c.text),
        shape: Border(bottom: BorderSide(color: c.hairline)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          c.borderControl.withValues(alpha: 0.6),
        ),
        radius: const Radius.circular(PennyRadius.full),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.ink,
        linearTrackColor: c.surfaceSunken,
      ),
      // Stock buttons are discouraged (use PennyButton); these keep any that
      // appear, such as inside dialogs, on brand.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          minimumSize: const Size(
            PennySize.touchTarget,
            PennySize.controlHeight,
          ),
          shape: controlShape,
          textStyle: PennyText.bodyStrong,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(
            PennySize.touchTarget,
            PennySize.controlHeight,
          ),
          shape: controlShape,
          textStyle: PennyText.bodyStrong,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(
            PennySize.touchTarget,
            PennySize.controlHeight,
          ),
          side: BorderSide(color: c.borderControl),
          shape: controlShape,
          textStyle: PennyText.bodyStrong,
        ),
      ),
    );
  }
}
