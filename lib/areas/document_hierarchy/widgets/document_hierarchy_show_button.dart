import 'package:flutter/material.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/keyboard_shortcuts.dart';
import '../../../shared/pointer_over_application.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../application/state/application_state_provider.dart';

class DocumentHierarchyShowButton extends StatelessWidget {
  static const double size = 36;
  static const double inset = 10;

  // centers the button in the element details bar
  static const double detailsBarTop = (AppSizes.barHeight - size) / 2;

  const DocumentHierarchyShowButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // the theme uses compact density, which would otherwise shrink the button below the tile size
    final style = ButtonStyle(
      fixedSize: const WidgetStatePropertyAll(Size.square(size)),
      minimumSize: const WidgetStatePropertyAll(Size.square(size)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      visualDensity: VisualDensity.standard,
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control))),
      backgroundColor: WidgetStatePropertyAll(colors.chrome),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return colors.textPrimary.withAlpha(isDark ? 56 : 40);
        if (states.contains(WidgetState.hovered)) return colors.textPrimary.withAlpha(isDark ? 36 : 24);
        return null;
      }),
    );

    final button = IconButton(
      icon: Icon(FontAwesomeIcons.sidebar, size: 20, color: colors.textPrimary),
      style: style,
      tooltip: "Show document structure ($toggleDocumentHierarchyShortcutLabel)",
      onPressed: applicationStateProviderInstance.toggleDocumentHierarchyVisibility,
    );

    return ValueListenableBuilder(
      valueListenable: isPointerOverApplication,
      builder: (context, isVisible, child) => IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(opacity: isVisible ? 1 : 0, duration: const Duration(milliseconds: 150), child: child),
      ),
      child: button,
    );
  }
}
