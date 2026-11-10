import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// the page canvas of the QuestPDF website: a tinted base, three blue glows along the top
// and, in the dark theme only, a grain tile that keeps the glows from banding
class WelcomeViewBackground extends StatelessWidget {
  const WelcomeViewBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      painter: _GlowPainter(isDark: isDark),
      child: isDark
          ? const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/grain-dark.png'),
                  repeat: ImageRepeat.repeat,
                  alignment: Alignment.topLeft,
                ),
              ),
            )
          : null,
    );
  }
}

// an elliptical glow that fades out at 70% of its radii, like the radial gradients of the website
class _Glow {
  // a fraction of the page width
  final double centerX;

  // a distance from the top of the page
  final double centerY;

  final double radiusX;
  final double radiusY;

  final Color lightColor;
  final Color darkColor;

  const _Glow({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
    required this.lightColor,
    required this.darkColor,
  });
}

class _GlowPainter extends CustomPainter {
  static const lightBaseColor = Color(0xFFF6F8FC);
  static const darkBaseColor = Color(0xFF0E1014);

  // the website starts its canvas behind the navigation bar, the view starts below the title bar
  static const double navigationBarHeight = 64;

  // listed from the bottom layer to the top one
  static const glows = [
    _Glow(
      centerX: 0,
      centerY: 80,
      radiusX: 800,
      radiusY: 450,
      lightColor: Color(0x244DA3FF),
      darkColor: Color(0x1F2196F3),
    ),
    _Glow(
      centerX: 0.3,
      centerY: 0,
      radiusX: 1000,
      radiusY: 500,
      lightColor: Color(0x244DA3FF),
      darkColor: Color(0x122196F3),
    ),
    _Glow(
      centerX: 0.92,
      centerY: 0,
      radiusX: 1400,
      radiusY: 700,
      lightColor: Color(0x5C4DA3FF),
      darkColor: Color(0x332196F3),
    ),
  ];

  final bool isDark;

  _GlowPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(area, Paint()..color = isDark ? darkBaseColor : lightBaseColor);

    for (final glow in glows) {
      final color = isDark ? glow.darkColor : glow.lightColor;
      final centerX = glow.centerX * size.width;
      final centerY = glow.centerY - navigationBarHeight;

      // a unit circle stretched to the radii of the ellipse and moved to its center
      final ellipse = Matrix4.diagonal3Values(glow.radiusX, glow.radiusY, 1)..setTranslationRaw(centerX, centerY, 0);
      final colors = [color, color.withAlpha(0)];

      final shader = ui.Gradient.radial(Offset.zero, 1, colors, const [0, 0.7], TileMode.clamp, ellipse.storage);
      canvas.drawRect(area, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.isDark != isDark;
}
