import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/keyboard_shortcuts.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../application/state/application_state_provider.dart';

// floats over the top right corner of the tree while the pointer is over the panel
class DocumentHierarchyHideButton extends StatelessWidget {
  final ValueListenable<bool> isVisible;

  const DocumentHierarchyHideButton({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // masks the tree rows scrolling under the button
    final button = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.chrome,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(AppRadius.popover)),
            ),
          ),
        ),
        Padding(
          // the right inset matches the close button of the search bar above
          padding: const EdgeInsets.only(left: 6, top: 10, right: 8, bottom: 6),
          child: IconButton(
            icon: const Icon(FontAwesomeIcons.close, size: 16),
            tooltip: "Hide document structure ($toggleDocumentHierarchyShortcutLabel)",
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: applicationStateProviderInstance.toggleDocumentHierarchyVisibility,
          ),
        ),
      ],
    );

    return ValueListenableBuilder(
      valueListenable: isVisible,
      builder: (context, isVisible, child) => IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(opacity: isVisible ? 1 : 0, duration: const Duration(milliseconds: 150), child: child),
      ),
      child: button,
    );
  }
}
