import 'package:flutter/material.dart';

// the dot grid of the QuestPDF website, fading out from the top right corner
class WelcomeViewDotPattern extends StatelessWidget {
  const WelcomeViewDotPattern({super.key});

  static const lightDotColor = Color(0x5C227DCD);
  static const darkDotColor = Color(0x1CDFDFD6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const RadialGradient(
        center: Alignment.topRight,
        radius: 1.1,
        colors: [Colors.black, Colors.transparent],
        stops: [0, 0.8],
      ).createShader(bounds),
      child: CustomPaint(painter: _DotPatternPainter(isDark ? darkDotColor : lightDotColor), size: Size.infinite),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  static const double spacing = 24;
  static const double dotRadius = 1.25;

  final Color color;

  _DotPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) => oldDelegate.color != color;
}
