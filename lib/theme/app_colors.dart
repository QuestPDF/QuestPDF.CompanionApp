import 'package:flutter/material.dart';

enum StatusTone { info, error, warning, caution, success }

@immutable
class AppColors extends ThemeExtension<AppColors> {
  // title bar, side panels and toolbars
  final Color chrome;

  // document preview background
  final Color canvas;

  // popovers, cards and other floating surfaces
  final Color popover;

  // translucent fill of inset controls and code blocks
  final Color fill;

  final Color border;
  final Color hover;
  final Color shadow;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color accent;

  // emphasized labels and the preview selection
  final Color highlight;

  final Color treeSelection;

  // the sky blue of the QuestPDF logo
  final Color info;

  final Color error;
  final Color warning;
  final Color caution;
  final Color success;

  const AppColors({
    required this.chrome,
    required this.canvas,
    required this.popover,
    required this.fill,
    required this.border,
    required this.hover,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.highlight,
    required this.treeSelection,
    required this.info,
    required this.error,
    required this.warning,
    required this.caution,
    required this.success,
  });

  static const light = AppColors(
    chrome: Color(0xFFFFFFFF),
    canvas: Color(0xFFEBECEF),
    popover: Color(0xFFFFFFFF),
    fill: Color(0x0A000000),
    border: Color(0x17000000),
    hover: Color(0x0D000000),
    shadow: Color(0x48000000),
    textPrimary: Color(0xFF1F2328),
    textSecondary: Color(0x98000000),
    textMuted: Color(0x65000000),
    accent: Color(0xFF0E6BFB),
    highlight: Color(0xFF3163BC),
    treeSelection: Color(0xFFDCE2F9),
    info: Color(0xFF2196F3),
    error: Color(0xFFD92D20),
    warning: Color(0xFFDC6803),
    caution: Color(0xFFCA8A04),
    success: Color(0xFF079455),
  );

  static const dark = AppColors(
    chrome: Color(0xFF161719),
    canvas: Color(0xFF2B2C30),
    popover: Color(0xFF1F2022),
    fill: Color(0x0EFFFFFF),
    border: Color(0x17FFFFFF),
    hover: Color(0x0FFFFFFF),
    shadow: Color(0xA0000000),
    textPrimary: Color(0xFFDFE1E5),
    textSecondary: Color(0x9CFFFFFF),
    textMuted: Color(0x65FFFFFF),
    accent: Color(0xFF4C8DFF),
    highlight: Color(0xFF89AFFF),
    treeSelection: Color(0xFF404659),
    info: Color(0xFF2196F3),
    error: Color(0xFFF97066),
    warning: Color(0xFFFDB022),
    caution: Color(0xFFFACC15),
    success: Color(0xFF47CD89),
  );

  Color status(StatusTone tone) {
    return switch (tone) {
      StatusTone.info => info,
      StatusTone.error => error,
      StatusTone.warning => warning,
      StatusTone.caution => caution,
      StatusTone.success => success,
    };
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
