import 'package:flutter/material.dart';

/// Draws a Font Awesome Light glyph with an outline on top so it reads like a heavier weight.
/// The bundled font ships only the Light style.
class EmboldenedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double strokeWidth;

  const EmboldenedIcon({super.key, required this.icon, required this.color, required this.size, this.strokeWidth = 0.8});

  @override
  Widget build(BuildContext context) {
    final outlineStyle = TextStyle(
      fontFamily: icon.fontFamily,
      fontSize: size,
      height: 1,
      decoration: TextDecoration.none,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: size),
          // icons ignore text scaling, so the outline must too, or it would drift from the glyph it traces
          Text(String.fromCharCode(icon.codePoint), style: outlineStyle, textScaler: TextScaler.noScaling),
        ],
      ),
    );
  }
}
