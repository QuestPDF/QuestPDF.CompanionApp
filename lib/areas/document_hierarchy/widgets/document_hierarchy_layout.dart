import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questpdf_companion/shared/convert_layout_error_measurement_to_color.dart';

import '../../../shared/tree_view/tree_view.dart';
import '../../../shared/tree_view/tree_view_model.dart';
import '../../../shared/tree_view_defaults/tree_view_default_highlighting.dart';
import '../../../shared/tree_view_defaults/tree_view_default_label.dart';
import '../../document_preview/state/document_preview_visible_content_state.dart';
import '../models/document_hierarchy_element.dart';
import '../state/document_hierarchy_hovered_element_provider.dart';
import '../state/document_hierarchy_provider.dart';
import '../state/document_hierarchy_search_state.dart';
import '../state/document_layout_error_provider.dart';
import 'document_hierarchy_layout_error_notification.dart';
import 'document_hierarchy_search.dart';

class DocumentHierarchyLayout extends ConsumerWidget {
  const DocumentHierarchyLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hierarchy = ref.watch(documentHierarchyProvider);
    final hoverState = ref.read(documentHierarchyHoveredElementProvider);
    final layoutErrorState = ref.watch(documentLayoutErrorProvider);
    final showSearch = ref.watch(documentHierarchySearchStateProvider.select((x) => x.searchPhrase != null));

    Color? getAnnotationColor(DocumentHierarchyElement element) {
      if (!layoutErrorState.containsLayoutError) return null;

      final currentLayoutErrorPageNumber = layoutErrorState.currentlySelectedLayoutError.measurement.pageNumber;

      return element.layoutErrorMeasurements
          .where((x) => x.pageNumber == currentLayoutErrorPageNumber)
          .firstOrNull
          .getAnnotationColor();
    }

    Widget buildTreeView() {
      TreeViewModel<DocumentHierarchyElement> buildTreeContent() {
        TreeViewModel<DocumentHierarchyElement> buildTreeContentFromElement(DocumentHierarchyElement element) {
          return TreeViewModel<DocumentHierarchyElement>(
            label: getDefaultTreeViewLabel(element.elementType, element.properties) ?? "",
            hint: element.hint,
            isHintImportant: element.elementType == "TextBlock",
            annotationColor: getAnnotationColor(element),
            isHighlighted: getDefaultTreeViewHighlighting(element.elementType, element.properties),
            isExpanded: element.isExpanded,
            isSelected: hierarchy.selectedElement == element,
            isDimmed: (x) => !x.isVisibleOn(documentPreviewVisibleContentStateInstance.visiblePageLocations),
            isSingleChildContainer: element.isSingleChildContainer,
            children: element.children.map(buildTreeContentFromElement).toList(),
            notifier: documentPreviewVisibleContentStateInstance,
            onClick: () => hierarchy.setSelectedElement(element),
            content: element,
          );
        }

        final result = buildTreeContentFromElement(hierarchy.root!);
        result.updateHierarchy();
        return result;
      }

      return TreeView(
        onHover: (hoveredElement) => hoverState.setHoveredElement(hoveredElement),
        rootNode: buildTreeContent(),
        selectedElementContent: hierarchy.selectedElement,
      );
    }

    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Visibility(visible: showSearch, child: DocumentHierarchySearch()),
          Visibility(visible: layoutErrorState.containsLayoutError, child: DocumentHierarchyLayoutErrorNotification()),
          if (showSearch || layoutErrorState.containsLayoutError)
            Divider(height: 1, color: Theme.of(context).dividerColor.withAlpha(64)),
          Expanded(
            child: Padding(padding: EdgeInsetsGeometry.only(right: 4), child: buildTreeView()),
          ),
        ],
      ),
    );
  }
}
