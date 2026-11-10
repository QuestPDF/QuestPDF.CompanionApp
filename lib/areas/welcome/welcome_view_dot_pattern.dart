import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// the dot wings of the QuestPDF website: a dot grid on each side of the view, seen in perspective,
// whose dots grow towards the edge of the window
class WelcomeViewDotPattern extends StatelessWidget {
  const WelcomeViewDotPattern({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).brightness == Brightness.dark ? _DotStyle.dark : _DotStyle.light;

    return CustomPaint(painter: _DotWingsPainter(style), size: Size.infinite);
  }
}

// a dot is solid up to the core radius and fades out towards the edge radius
class _DotStyle {
  static const double spriteSize = 64;
  static const spriteArea = Rect.fromLTWH(0, 0, spriteSize, spriteSize);

  static final light = _DotStyle(color: const Color(0x8DFFFFFF), coreRadius: 1.25, edgeRadius: 2.25);
  static final dark = _DotStyle(color: const Color(0x24A2CAE6), coreRadius: 1, edgeRadius: 1.5);

  final Color color;
  final double coreRadius;
  final double edgeRadius;

  _DotStyle({required this.color, required this.coreRadius, required this.edgeRadius});

  // a single enlarged dot, drawn scaled down for every dot of the wings;
  // painted on first use and kept for the lifetime of the application
  late final ui.Image sprite = _paintSprite();

  ui.Image _paintSprite() {
    const center = Offset(spriteSize / 2, spriteSize / 2);

    final recorder = ui.PictureRecorder();
    final gradient = ui.Gradient.radial(center, spriteSize / 2, [color, color.withAlpha(0)], [coreRadius / edgeRadius, 1]);
    Canvas(recorder).drawPaint(Paint()..shader = gradient);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(spriteSize.toInt(), spriteSize.toInt());
    picture.dispose();

    return image;
  }
}

class _DotWingsPainter extends CustomPainter {
  static const double spacing = 24;

  // the wings sit this much lower than on the website, where they start right below the navigation bar
  static const double offsetY = 50;

  // the wings end at this height and stay clear of the content column with its margins
  static const double height = 420;
  static const double maxWidthFraction = 0.28;
  static const double contentClearance = 416;

  // the dot rows converge on this line, the middle of the hero title on the website
  static const double horizon = 102;

  // the distance to the vanishing point, in wing widths
  static const double perspective = 2.5;

  // a column is scaled by its distance to the vanishing point: 1 at the window edge, this much at the inner edge
  static const double innerScale = 1 - 1 / perspective;

  // the dot radius in edge radii: the minimum at the inner edge, growing quadratically towards the window edge
  static const double minRadiusFactor = 0.55;
  static const double radiusGrowthFactor = 1.75;

  // the last columns fade out over this distance from the inner edge
  static const double columnFadeWidth = 0.6 * spacing;

  // the wings dissolve around a point on the window edge, placed slightly below their top:
  // dots are opaque near it and turn transparent over the outer part of the fade radii
  static const double fadeCenterY = 0.08 * height;
  static const double fadeRadiusY = 0.85 * height;
  static const double fadeFalloff = 0.6;

  final _DotStyle style;

  _DotWingsPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width * maxWidthFraction, (size.width - contentClearance) / 2);

    if (width <= 0) return;

    // every dot is the same sprite with its own placement and opacity, so a wing is painted with a single call
    final (:placements, :opacities) = layOutLeftWing(width);
    final sprites = List.filled(placements.length, _DotStyle.spriteArea);
    final paint = Paint()..filterQuality = FilterQuality.low;

    void paintWing() {
      canvas.drawAtlas(style.sprite, placements, sprites, opacities, BlendMode.modulate, null, paint);
    }

    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, offsetY);
    paintWing();

    // the right wing mirrors the left one
    canvas.translate(size.width, 0);
    canvas.scale(-1, 1);
    paintWing();
  }

  // places the dots of the left wing: x is the distance from the window edge, y is measured as on the website
  ({List<RSTransform> placements, List<Color> opacities}) layOutLeftWing(double width) {
    final placements = <RSTransform>[];
    final opacities = <Color>[];

    // a column at a given depth is scaled by distance / depth
    final distance = perspective * width;

    // the columns are evenly spaced in depth, and the first one lies half a step away from the window edge
    final firstDepth = distance / (1 - spacing / 2 / distance);

    for (var depth = firstDepth; ; depth += spacing) {
      final scale = distance / depth;
      final x = distance * (1 - scale);

      if (x >= width) break;

      final growth = (scale - innerScale) / (1 - innerScale);
      final radius = style.edgeRadius * (minRadiusFactor + radiusGrowthFactor * growth * growth);
      final columnOpacity = ((width - x) / columnFadeWidth).clamp(0.0, 1.0);

      // the rows keep their spacing at the window edge and close in on the horizon further away
      double yOfRow(int row) => horizon + (spacing / 2 + row * spacing - horizon) * scale;
      double rowOfY(double y) => (horizon + (y - horizon) / scale - spacing / 2) / spacing;

      // from the top of the view down to the end of the wings
      final firstRow = rowOfY(-offsetY - radius).ceil();
      final lastRow = rowOfY(height + radius).floor();

      for (var row = firstRow; row <= lastRow; row++) {
        final y = yOfRow(row);
        final opacity = columnOpacity * fadeAt(x, y, width);

        if (opacity <= 0) continue;

        placements.add(RSTransform(2 * radius / _DotStyle.spriteSize, 0, x - radius, y - radius));
        opacities.add(Color.fromRGBO(255, 255, 255, opacity));
      }
    }

    return (placements: placements, opacities: opacities);
  }

  // the distance from the fade center in fade radii, turned into an opacity
  double fadeAt(double x, double y, double width) {
    final distanceX = x / (2 * width);
    final distanceY = (y - fadeCenterY) / fadeRadiusY;
    final distance = math.sqrt(distanceX * distanceX + distanceY * distanceY);

    return ((1 - distance) / fadeFalloff).clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(_DotWingsPainter oldDelegate) => oldDelegate.style != style;
}
