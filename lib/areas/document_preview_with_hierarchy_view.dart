import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

import '../theme/app_colors.dart';
import 'application/state/application_state_provider.dart';
import 'document_hierarchy/state/document_hierarchy_provider.dart';
import 'document_hierarchy/state/document_hierarchy_search_state.dart';
import 'document_hierarchy/widgets/document_hierarchy_layout.dart';
import 'document_hierarchy/widgets/document_hierarchy_show_button.dart';
import 'document_preview/widgets/document_preview_layout.dart';

// the panel can be hidden in the settings, but the search lives in it and brings it back while active
final isDocumentHierarchyPanelVisibleProvider = Provider<bool>((ref) {
  final isShown = ref.watch(applicationStateProvider.select((x) => x.showDocumentHierarchy));
  final isSearchActive = ref.watch(documentHierarchySearchStateProvider.select((x) => x.searchPhrase != null));

  return isShown || isSearchActive;
});

class DocumentPreviewWithHierarchyView extends ConsumerWidget {
  static final documentPreviewKey = GlobalKey();

  const DocumentPreviewWithHierarchyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPanelVisible = ref.watch(isDocumentHierarchyPanelVisibleProvider);

    if (!isPanelVisible) {
      final hasElementDetails = ref.watch(
        documentHierarchyProvider.select((x) => x.selectedElement != null && x.selectedElementPageLocationIndex != null),
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          DocumentPreviewLayout(key: documentPreviewKey),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            top: hasElementDetails ? DocumentHierarchyShowButton.detailsBarTop : DocumentHierarchyShowButton.inset,
            left: DocumentHierarchyShowButton.inset,
            child: const DocumentHierarchyShowButton(),
          ),
        ],
      );
    }

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(dividerThickness: 1, dividerHandleBuffer: 4),
      child: MultiSplitView(
        // while hovered or dragged, the divider grows over the edge of the preview
        dividerBuilder: (axis, index, resizable, dragging, highlighted, themeData) {
          final isActive = dragging || highlighted;
          final width = isActive ? 2.0 : 1.0;

          return OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            child: ColoredBox(color: isActive ? context.appColors.highlight.withAlpha(128) : context.appColors.border),
          );
        },
        initialAreas: [
          Area(size: 300, min: 250, max: 600, builder: (context, area) => const DocumentHierarchyLayout()),
          Area(builder: (context, area) => DocumentPreviewLayout(key: documentPreviewKey)),
        ],
      ),
    );
  }
}
