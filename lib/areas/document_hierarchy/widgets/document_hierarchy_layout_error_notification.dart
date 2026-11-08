import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/emboldened_icon.dart';
import '../../../shared/font_awesome_icons.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../state/document_layout_error_provider.dart';

class DocumentHierarchyLayoutErrorNotification extends ConsumerWidget {
  const DocumentHierarchyLayoutErrorNotification({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutErrorState = ref.watch(documentLayoutErrorProvider);
    if (!layoutErrorState.containsLayoutError) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = context.appColors;

    final titleStyle = theme.textTheme.labelLarge?.copyWith(color: colors.error, fontWeight: FontWeight.w600);
    final counterStyle = theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary, fontFeatures: tabularFigures);

    return Container(
      height: AppSizes.barHeight,
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          EmboldenedIcon(icon: FontAwesomeIcons.layoutError, color: colors.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text("Layout error", style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(
                  "${layoutErrorState.currentlySelectedLayoutErrorIndex + 1} / ${layoutErrorState.numberOfLayoutErrors}",
                  style: counterStyle,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowUp, size: 16),
            tooltip: "Previous layout error",
            visualDensity: VisualDensity.compact,
            onPressed: () => layoutErrorState.changeSelectedErrorLayoutPage(-1),
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowDown, size: 16),
            tooltip: "Next layout error",
            visualDensity: VisualDensity.compact,
            onPressed: () => layoutErrorState.changeSelectedErrorLayoutPage(1),
          ),
        ],
      ),
    );
  }
}
