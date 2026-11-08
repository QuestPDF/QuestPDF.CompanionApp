import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

// a tinted pill with an icon and a short label
class ApplicationTitlebarIndicator extends StatelessWidget {
  static const double height = 28;

  final IconData icon;
  final StatusTone tone;
  final String label;
  final bool showLabel;
  final VoidCallback? onPressed;

  const ApplicationTitlebarIndicator({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    this.showLabel = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.status(tone);

    // capitals stay legible below the 14pt minimum
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      fontFeatures: const [FontFeature('cpsp')],
    );

    return Semantics(
      label: showLabel ? null : label,
      child: SizedBox(
        height: height,
        child: Material(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            // a pill without an action still lights up on hover, as hovering opens its card
            onTap: onPressed ?? () {},
            mouseCursor: onPressed == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
            highlightColor: onPressed == null ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(AppRadius.control),
            hoverColor: color.withAlpha(36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  if (showLabel) ...[const SizedBox(width: 8), Text(label.toUpperCase(), style: textStyle)],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
