import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

class ApplicationTitlebarWindowButtons extends StatelessWidget {
  const ApplicationTitlebarWindowButtons({super.key});

  // full-height rectangular caption buttons, following the Windows 11 convention
  static const double buttonWidth = 46;
  static const double iconSize = 16;
  static const closeHoverColor = Color(0xFFC42B1C);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // the title bar draws a 1px bottom border that the buttons should not cover
    final buttonSize = Size(buttonWidth, AppSizes.barHeight - 1);

    final buttonStyle = ButtonStyle(
      fixedSize: WidgetStatePropertyAll(buttonSize),
      minimumSize: WidgetStatePropertyAll(buttonSize),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: Duration.zero,
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? colors.hover : Colors.transparent,
      ),
      iconColor: WidgetStatePropertyAll(colors.textSecondary),
    );

    final closeButtonStyle = buttonStyle.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? closeHoverColor : Colors.transparent,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? Colors.white : colors.textSecondary,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(FontAwesomeIcons.minimize, size: iconSize),
          style: buttonStyle,
          onPressed: windowManager.minimize,
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.maximize, size: iconSize),
          style: buttonStyle,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.close, size: iconSize),
          style: closeButtonStyle,
          onPressed: windowManager.close,
        ),
      ],
    );
  }
}
