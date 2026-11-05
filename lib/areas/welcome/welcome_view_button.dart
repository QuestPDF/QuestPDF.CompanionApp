import 'package:flutter/material.dart';

import '../../shared/font_awesome_icons.dart';
import '../../theme/app_colors.dart';

class WelcomeViewButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onClick;
  final IconData? trailingIcon;
  final bool showsTrailingIconOnHoverOnly;
  final StatusTone? tone;

  const WelcomeViewButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onClick,
    this.trailingIcon = FontAwesomeIcons.externalLink,
    this.showsTrailingIconOnHoverOnly = true,
    this.tone,
  });

  @override
  State<WelcomeViewButton> createState() => _WelcomeViewButtonState();
}

class _WelcomeViewButtonState extends State<WelcomeViewButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final tone = widget.tone;
    final toneColor = tone != null ? colors.status(tone) : null;

    final iconColor = theme.brightness == Brightness.dark ? Colors.white : colors.textPrimary;
    final showTrailingIcon = isHovered || !widget.showsTrailingIconOnHoverOnly;

    return InkWell(
      onTap: widget.onClick,
      onHover: (value) => setState(() => isHovered = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: toneColor ?? iconColor),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                widget.label,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400, color: toneColor),
              ),
            ),
            if (widget.trailingIcon != null)
              Opacity(
                opacity: showTrailingIcon ? 1 : 0,
                child: Icon(widget.trailingIcon, size: 16, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
