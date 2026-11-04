import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questpdf_companion/shared/convert_layout_error_measurement_to_color.dart';

import '../../../shared/tree_view/tree_view.dart';
import '../../../shared/tree_view/tree_view_model.dart';
import '../../../theme/app_colors.dart';
import '../../document_preview/state/document_preview_visible_content_state.dart';
import '../models/document_hierarchy_element.dart';
import '../state/document_hierarchy_hovered_element_provider.dart';
import '../state/document_hierarchy_provider.dart';
import '../state/document_hierarchy_search_state.dart';
import '../state/document_layout_error_provider.dart';
import 'document_hierarchy_hide_button.dart';
import 'document_hierarchy_layout_error_notification.dart';
import 'document_hierarchy_search.dart';
import 'document_hierarchy_tree_presentation.dart';

class DocumentHierarchyLayout extends ConsumerStatefulWidget {
  const DocumentHierarchyLayout({super.key});

  @override
  ConsumerState<DocumentHierarchyLayout> createState() => _DocumentHierarchyLayoutState();
}

class _DocumentHierarchyLayoutState extends ConsumerState<DocumentHierarchyLayout> {
  // a notifier rather than widget state, so hovering the panel does not rebuild the tree
  final isPanelHovered = ValueNotifier(false);

  @override
  void dispose() {
    isPanelHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = ref.watch(documentHierarchyProvider);
    final layoutErrorState = ref.watch(documentLayoutErrorProvider);
    final showSearch = ref.watch(documentHierarchySearchStateProvider.select((x) => x.searchPhrase != null));
    final showLayoutErrors = layoutErrorState.containsLayoutError;

    return MouseRegion(
      onEnter: (_) => isPanelHovered.value = true,
      onExit: (_) => isPanelHovered.value = false,
      child: Container(
        color: context.appColors.chrome,
        child: Column(
          children: [
            if (showLayoutErrors) const DocumentHierarchyLayoutErrorNotification(),
            if (showSearch && showLayoutErrors) const Divider(),
            if (showSearch) const DocumentHierarchySearch(),
            if (showSearch || showLayoutErrors) const Divider(),
            Expanded(
              child: Stack(
                children: [
                  Padding(padding: const EdgeInsets.only(right: 4), child: buildTreeView(hierarchy, layoutErrorState)),
                  Positioned(top: 0, right: 0, child: DocumentHierarchyHideButton(isVisible: isPanelHovered)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTreeView(DocumentHierarchyState hierarchy, DocumentLayoutErrorProvider layoutErrorState) {
    final rootNode = buildTreeNode(hierarchy.root!, hierarchy, layoutErrorState)..updateHierarchy();

    return TreeView(
      onHover: documentHierarchyHoveredElementProviderInstance.setHoveredElement,
      rootNode: rootNode,
      selectedElementContent: hierarchy.selectedElement,
    );
  }

  TreeViewModel<DocumentHierarchyElement> buildTreeNode(
    DocumentHierarchyElement element,
    DocumentHierarchyState hierarchy,
    DocumentLayoutErrorProvider layoutErrorState,
  ) {
    return TreeViewModel<DocumentHierarchyElement>(
      label: element.treeLabel,
      hint: element.treeHint,
      isHintImportant: element.elementType == "TextBlock",
      annotationColor: getAnnotationColor(element, layoutErrorState),
      isHighlighted: element.isTreeHighlighted,
      isExpanded: element.isExpanded,
      isSelected: hierarchy.selectedElement == element,
      isDimmed: (x) => !x.isVisibleOn(documentPreviewVisibleContentStateInstance.visiblePageLocations),
      isSingleChildContainer: element.isSingleChildContainer,
      children: element.children.map((x) => buildTreeNode(x, hierarchy, layoutErrorState)).toList(),
      notifier: documentPreviewVisibleContentStateInstance,
      onClick: () => hierarchy.setSelectedElement(element),
      content: element,
    );
  }

  Color? getAnnotationColor(DocumentHierarchyElement element, DocumentLayoutErrorProvider layoutErrorState) {
    if (!layoutErrorState.containsLayoutError) return null;

    return layoutErrorState.findMeasurementOf(element).getAnnotationColor(context);
  }
}
