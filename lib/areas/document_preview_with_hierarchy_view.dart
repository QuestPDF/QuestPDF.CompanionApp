import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';

import '../theme/app_colors.dart';
import 'application/state/application_state_provider.dart';
import 'document_hierarchy/widgets/document_hierarchy_layout.dart';
import 'document_hierarchy/widgets/document_hierarchy_show_button.dart';
import 'document_preview/widgets/document_preview_element_details.dart';
import 'document_preview/widgets/document_preview_layout.dart';

class DocumentPreviewWithHierarchyView extends ConsumerStatefulWidget {
  const DocumentPreviewWithHierarchyView({super.key});

  @override
  ConsumerState<DocumentPreviewWithHierarchyView> createState() => _DocumentPreviewWithHierarchyViewState();
}

class _DocumentPreviewWithHierarchyViewState extends ConsumerState<DocumentPreviewWithHierarchyView> {
  final documentPreviewKey = GlobalKey();
  final searchKey = GlobalKey();

  // the split view calls its area builders on every layout, so a fresh widget instance would rebuild the whole
  // structure tree on each resize frame and each divider move; identical instances are skipped by the framework
  late final hierarchyLayout = DocumentHierarchyLayout(searchKey: searchKey);
  late final previewLayout = DocumentPreviewLayout(key: documentPreviewKey, searchKey: searchKey);

  @override
  Widget build(BuildContext context) {
    final isPanelVisible = ref.watch(applicationStateProvider.select((x) => x.showDocumentHierarchy));

    if (!isPanelVisible) {
      final hasTopBar = ref.watch(isDocumentPreviewToolbarVisibleProvider);

      return Stack(
        fit: StackFit.expand,
        children: [
          previewLayout,
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            top: hasTopBar ? DocumentHierarchyShowButton.detailsBarTop : DocumentHierarchyShowButton.inset,
            left: DocumentHierarchyShowButton.inset,
            child: DocumentHierarchyShowButton(alwaysVisible: hasTopBar),
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
          Area(size: 300, min: 250, max: 600, builder: (context, area) => hierarchyLayout),
          Area(builder: (context, area) => previewLayout),
        ],
      ),
    );
  }
}
