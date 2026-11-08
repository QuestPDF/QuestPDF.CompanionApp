import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:questpdf_companion/shared/convert_layout_error_measurement_to_color.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/open_source_code_path_in_editor.dart';
import '../../../shared/source_code_visualization.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../application/state/application_state_provider.dart';
import '../../document_hierarchy/models/document_hierarchy_element.dart';
import '../../document_hierarchy/models/document_hierarchy_element_layout_error_measurement.dart';
import '../../document_hierarchy/models/element_size.dart';
import '../../document_hierarchy/models/page_location.dart';
import '../../document_hierarchy/state/document_hierarchy_provider.dart';
import '../../document_hierarchy/state/document_hierarchy_search_state.dart';
import '../../document_hierarchy/state/document_layout_error_provider.dart';
import '../../document_hierarchy/widgets/document_hierarchy_search.dart';
import '../../document_hierarchy/widgets/document_hierarchy_layout_error_notification.dart';
import '../../document_hierarchy/widgets/document_hierarchy_show_button.dart';
import 'document_preview_toolbar_layout.dart';

final isDocumentPreviewToolbarVisibleProvider = Provider<bool>((ref) {
  final hasSelectedElement = ref.watch(
    documentHierarchyProvider.select((x) => x.selectedElement != null && x.selectedElementPageLocationIndex != null),
  );

  if (hasSelectedElement) return true;

  // the search and the layout errors live in the hierarchy panel; the bar takes them over while the panel is hidden
  if (ref.watch(applicationStateProvider.select((x) => x.showDocumentHierarchy))) return false;

  return ref.watch(documentHierarchySearchStateProvider.select((x) => x.searchPhrase != null)) ||
      ref.watch(documentLayoutErrorProvider.select((x) => x.containsLayoutError));
});

class DocumentPreviewElementDetails extends ConsumerStatefulWidget {
  final Key? searchKey;

  const DocumentPreviewElementDetails({super.key, this.searchKey});

  @override
  DocumentPreviewElementDetailsState createState() => DocumentPreviewElementDetailsState();
}

class DocumentPreviewElementDetailsState extends ConsumerState<DocumentPreviewElementDetails> {
  bool showSourceCodePreview = false;

  @override
  Widget build(BuildContext context) {
    // a bar that disappears from under the pointer never reports onExit,
    // so clearing the selection has to close the snippet as well
    ref.listen(documentHierarchyProvider.select((x) => x.selectedElement), (_, selectedElement) {
      if (selectedElement == null) setState(() => showSourceCodePreview = false);
    });

    if (!ref.watch(isDocumentPreviewToolbarVisibleProvider)) return const SizedBox.shrink();

    final selectedElement = ref.watch(documentHierarchyProvider.select((x) => x.selectedElement));
    final selectedElementPageLocationIndex = ref.watch(
      documentHierarchyProvider.select((x) => x.selectedElementPageLocationIndex),
    );

    final hasDetails = selectedElement != null && selectedElementPageLocationIndex != null;
    final isHierarchyHidden = !ref.watch(applicationStateProvider.select((x) => x.showDocumentHierarchy));
    final showSearch =
        isHierarchyHidden && ref.watch(documentHierarchySearchStateProvider.select((x) => x.searchPhrase != null));
    final showLayoutErrors =
        isHierarchyHidden && ref.watch(documentLayoutErrorProvider.select((x) => x.containsLayoutError));

    final items = <DocumentPreviewToolbarItem>[];
    void addControl(Widget child, double width) {
      // Reserve the same toggle gutter on every row so their leading icons align.
      const inset = DocumentHierarchyShowButton.barLeadingSpace;
      items.add(
        DocumentPreviewToolbarItem(
          child: Padding(
            padding: EdgeInsets.only(left: inset),
            child: child,
          ),
          maxWidth: width + inset,
        ),
      );
    }

    if (showLayoutErrors) {
      addControl(const DocumentHierarchyLayoutErrorNotification(), DocumentPreviewToolbarLayout.layoutErrorWidth);
    }
    if (showSearch) {
      addControl(DocumentHierarchySearch(key: widget.searchKey), DocumentPreviewToolbarLayout.searchWidth);
    }
    if (hasDetails) {
      items.add(
        DocumentPreviewToolbarItem(
          maxWidth: isHierarchyHidden ? DocumentPreviewToolbarLayout.detailsWidth : null,
          child: buildTopBar(selectedElement, selectedElementPageLocationIndex, isHierarchyHidden),
        ),
      );
    }

    final colors = context.appColors;

    return MouseRegion(
      // Keep the snippet open while the pointer moves into it to scroll.
      onExit: (_) => setState(() => showSourceCodePreview = false),
      child: Material(
        color: colors.chrome,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DocumentPreviewToolbarLayout(items: items, dividerColor: colors.border),
            if (hasDetails)
              Flexible(
                child: SingleChildScrollView(
                  // every element starts with a freshly loaded snippet, scrolled to the top
                  key: ObjectKey(selectedElement),
                  primary: false,
                  child: buildSourceCodePreview(),
                ),
              ),
            // the translucent divider would vanish over the chrome, so it is drawn over the canvas below the bar
            ColoredBox(color: colors.canvas, child: const Divider()),
          ],
        ),
      ),
    );
  }

  Widget buildTopBar(
    DocumentHierarchyElement selectedElement,
    int selectedElementPageLocationIndex,
    bool isHierarchyHidden,
  ) {
    final layoutErrorState = ref.watch(documentLayoutErrorProvider);

    final sections = [
      // the hierarchy panel names the selected element; without it, the bar does
      buildNavigationSection(selectedElement, showElementName: isHierarchyHidden),
      if (layoutErrorState.containsLayoutError)
        ...buildLayoutErrorMeasurementSection(layoutErrorState, selectedElement)
      else
        ...buildLayoutSection(selectedElement, selectedElementPageLocationIndex),
    ];

    // on narrow windows, every wrapped line is as tall as the bar
    Widget buildRowItem(Widget child) {
      return SizedBox(
        height: AppSizes.barHeight,
        child: Align(widthFactor: 1, child: child),
      );
    }

    return Container(
      key: const ValueKey('preview-selected-element-details'),
      alignment: Alignment.centerLeft,
      // The first IconButton adds 8px of its own inset, matching the other rows' 16px padding.
      padding: EdgeInsets.only(left: (isHierarchyHidden ? DocumentHierarchyShowButton.barLeadingSpace : 0) + 8, right: 8),
      child: Wrap(spacing: 36, children: sections.map(buildRowItem).toList()),
    );
  }

  Widget buildDetail(IconData icon, String value, String tooltip) {
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontFeatures: tabularFigures);

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.appColors.textSecondary),
          const SizedBox(width: 12),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  List<Widget> buildLayoutSection(DocumentHierarchyElement selectedElement, int selectedElementPageLocationIndex) {
    if (selectedElementPageLocationIndex < 0 || selectedElementPageLocationIndex >= selectedElement.pageLocations.length) {
      return [];
    }

    final location = selectedElement.pageLocations[selectedElementPageLocationIndex];

    String formatPages() {
      final pages = selectedElement.pageLocations.map((x) => x.pageNumber).toList();

      final current = location.pageNumber.toString();
      final min = pages.reduce((a, b) => a < b ? a : b);
      final max = pages.reduce((a, b) => a > b ? a : b);

      return "$current ($min-$max)";
    }

    final size = "${location.width.toStringAsFixed(1)} × ${location.height.toStringAsFixed(1)}";
    final position = "${location.left.toStringAsFixed(1)} / ${location.top.toStringAsFixed(1)}";

    return [
      buildDetail(
        FontAwesomeIcons.elementPage,
        formatPages(),
        "Selected element page visibility:\ncurrent page (min-max)",
      ),
      buildDetail(FontAwesomeIcons.elementPosition, position, "Selected element position"),
      buildDetail(FontAwesomeIcons.elementSize, size, "Selected element size"),
    ];
  }

  Widget buildSourceCodeFilePath(String filePath) {
    final bodyTextStyle = Theme.of(context).textTheme.bodySmall;

    final primaryStyle = bodyTextStyle?.copyWith(color: context.appColors.textPrimary, fontWeight: FontWeight.w600);
    final secondaryTextStyle = bodyTextStyle?.copyWith(color: context.appColors.textSecondary);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: path.dirname(filePath) + path.separator, style: secondaryTextStyle),
          TextSpan(text: path.basename(filePath), style: primaryStyle),
        ],
      ),
    );
  }

  Widget buildSourceCodePreview() {
    if (!showSourceCodePreview) return const SizedBox.shrink();

    final location = documentHierarchyProviderInstance.findSourceCodeLocationOf(
      documentHierarchyProviderInstance.selectedElement,
    );

    if (location == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSourceCodeFilePath(location.filePath),
              const SizedBox(height: 12),
              SourceCodeVisualization(
                filePath: location.filePath,
                highlightLineNumber: location.lineNumber,
                showLinesBuffer: 9,
                backgroundColor: context.appColors.chrome,
                highlightColor: context.appColors.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNavigationSection(DocumentHierarchyElement selectedElement, {required bool showElementName}) {
    final enablePositionButtons = selectedElement.pageLocations.length > 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => showSourceCodePreview = true),
          child: IconButton(
            icon: const Icon(FontAwesomeIcons.penLine, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: tryToOpenInCodeEditor,
          ),
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.arrowUp, size: 16),
          visualDensity: VisualDensity.compact,
          tooltip: "Previous occurrence",
          onPressed: enablePositionButtons
              ? () => documentHierarchyProviderInstance.changeSelectedElementPageNumberVisibility(-1)
              : null,
        ),
        IconButton(
          icon: const Icon(FontAwesomeIcons.arrowDown, size: 16),
          visualDensity: VisualDensity.compact,
          tooltip: "Next occurrence",
          onPressed: enablePositionButtons
              ? () => documentHierarchyProviderInstance.changeSelectedElementPageNumberVisibility(1)
              : null,
        ),
        if (showElementName) ...[
          const SizedBox(width: 12),
          Text(selectedElement.elementType, style: Theme.of(context).textTheme.titleSmall),
        ],
      ],
    );
  }

  Future<void> tryToOpenInCodeEditor() async {
    final location = documentHierarchyProviderInstance.findSourceCodeLocationOf(
      documentHierarchyProviderInstance.selectedElement,
    );

    if (location == null) return;

    await tryOpenSourceCodePathInEditor(
      context,
      applicationStateProviderInstance.defaultCodeEditor,
      location.filePath,
      location.lineNumber,
    );
  }

  List<Widget> buildLayoutErrorMeasurementSection(
    DocumentLayoutErrorProvider layoutErrorState,
    DocumentHierarchyElement element,
  ) {
    final measurement = layoutErrorState.findMeasurementOf(element);

    String formatSize(ElementSize? size) {
      if (size == null) return "-";
      return "${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)}";
    }

    String formatMeasurementStatus() {
      if (measurement == null) return "Not measured";
      if (measurement.isLayoutErrorRootCause) return "Root cause";

      return switch (measurement.spacePlanType) {
        SpacePlanType.wrap => "Wrap",
        SpacePlanType.partialRender => "Partial render",
        SpacePlanType.fullRender => "Full render",
        SpacePlanType.empty => "Empty",
        null => "Not measured",
      };
    }

    Widget buildIndicator() {
      const indicatorSize = 10.0;

      // lines up with the icon inside the icon button above
      const buttonIconInset = 12.0;

      return Container(
        width: indicatorSize,
        height: indicatorSize,
        margin: const EdgeInsets.only(left: buttonIconInset),
        decoration: BoxDecoration(color: measurement.getAnnotationColor(context), shape: BoxShape.circle),
      );
    }

    Widget buildMeasurementStatus() {
      final theme = Theme.of(context);
      final wrapReason = measurement?.wrapReason;

      final statusStyle = theme.textTheme.bodyMedium?.copyWith(
        color: context.appColors.textPrimary,
        fontWeight: FontWeight.w500,
      );
      final wrapReasonStyle = theme.textTheme.bodyMedium?.copyWith(color: context.appColors.textSecondary);

      return Tooltip(
        message: wrapReason ?? "",
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildIndicator(),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatMeasurementStatus(), style: statusStyle),
                    if (wrapReason != null && wrapReason.isNotEmpty) ...[
                      const WidgetSpan(child: SizedBox(width: 8)),
                      TextSpan(text: wrapReason, style: wrapReasonStyle),
                    ],
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return [
      if (measurement != null)
        buildDetail(
          FontAwesomeIcons.elementAvailableSpace,
          formatSize(measurement.availableSpace),
          "Available space for selected element",
        ),
      if (measurement != null && measurement.spacePlanType != SpacePlanType.wrap)
        buildDetail(
          FontAwesomeIcons.elementRequiredSpace,
          formatSize(measurement.measurementSize),
          "Requested space for selected element",
        ),
      buildMeasurementStatus(),
    ];
  }
}
