import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'popover_decoration.dart';

const appFontFamily = 'Inter';
const codeFontFamily = 'JetBrains Mono';

// 14pt is the smallest size, as Flutter renders smaller text blurry on Windows
const _textTheme = TextTheme(
  headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.3),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.35),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.35),
  bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.4),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.4),
  bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.4),
  labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0),
  labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0),
  labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0),
);

// keeps live-updating numbers from shifting horizontally
const tabularFigures = [FontFeature.tabularFigures()];

class AppRadius {
  AppRadius._();

  static const double small = 4;
  static const double control = 6;
  static const double popover = 10;
}

class AppSizes {
  AppSizes._();

  // the title bar, the document structure panel headers and the element details bar
  static const double barHeight = 44;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.light.accent,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: colors.accent,
        onPrimary: Colors.white,
        error: colors.error,
        onError: Colors.white,
        surface: colors.chrome,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.textMuted,
        surfaceTint: Colors.transparent,
      );

  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control));

  return ThemeData(
    fontFamily: appFontFamily,
    textTheme: _textTheme,
    colorScheme: colorScheme,
    extensions: [colors],
    visualDensity: VisualDensity.compact,
    scaffoldBackgroundColor: colors.chrome,
    dividerColor: colors.border,
    hoverColor: colors.hover,
    splashFactory: NoSplash.splashFactory,
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        shape: WidgetStateProperty.all(controlShape),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.textMuted.withValues(alpha: colors.textMuted.a * 0.5)
              : colors.textSecondary,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: controlShape,
        side: BorderSide(color: colors.border),
        foregroundColor: colors.textPrimary,
      ),
    ),
    // the dark-mode accent is too light under white text, so both themes use the light-mode one
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: controlShape,
        backgroundColor: AppColors.light.accent,
        foregroundColor: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.popover,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.popover),
        side: BorderSide(color: colors.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      verticalOffset: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: PopoverDecoration(colors),
      textStyle: _textTheme.bodyMedium!.copyWith(fontFamily: appFontFamily, color: colors.textPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.popover)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.hovered) ? 8 : 6),
      radius: const Radius.circular(4),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => colors.textPrimary.withAlpha(states.contains(WidgetState.hovered) ? 100 : 64),
      ),
    ),
  );
}
