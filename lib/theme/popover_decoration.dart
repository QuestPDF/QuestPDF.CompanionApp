import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';

/// The look shared by every floating surface: the settings menu, the title bar cards and plain tooltips.
///
/// A menu is a [Material] with an elevation, which a tooltip or a decorated box cannot be, so the shadow is
/// painted the way [Material] paints its own: with [Canvas.drawShadow] at the same elevation and shadow color.
class PopoverDecoration extends Decoration {
  static const double elevation = 16;

  final AppColors colors;

  const PopoverDecoration(this.colors);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _PopoverDecorationPainter(this);
}

class _PopoverDecorationPainter extends BoxPainter {
  final PopoverDecoration decoration;

  _PopoverDecorationPainter(this.decoration);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.popover));
    final colors = decoration.colors;

    canvas.drawShadow(Path()..addRRect(shape), colors.shadow, PopoverDecoration.elevation, false);
    canvas.drawRRect(shape, Paint()..color = colors.popover);

    // the hairline sits inside the bounds, as the side of a Material shape does
    final border = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(shape.deflate(0.5), border);
  }
}
