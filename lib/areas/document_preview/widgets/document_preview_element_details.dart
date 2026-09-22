import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/shared/convert_layout_error_measurement_to_color.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/open_source_code_path_in_editor.dart';
import '../../../shared/source_code_visualization.dart';
import '../../../typography.dart';
import '../../document_hierarchy/models/document_hierarchy_element.dart';
import '../../document_hierarchy/models/document_hierarchy_element_layout_error_measurement.dart';
import '../../document_hierarchy/models/element_size.dart';
import '../../document_hierarchy/state/document_hierarchy_provider.dart';
import '../../document_hierarchy/state/document_layout_error_provider.dart';

class DocumentPreviewElementDetails extends ConsumerStatefulWidget {
  const DocumentPreviewElementDetails({super.key});

  @override
  DocumentPreviewElementDetailsState createState() => DocumentPreviewElementDetailsState();
}

class DocumentPreviewElementDetailsState extends ConsumerState<DocumentPreviewElementDetails> {
  bool showSourceCodePreview = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(0),
      shape: const Border(),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [buildTopBar(context), buildSourceCodePreview(context)],
      ),
    );
  }

  Widget buildTopBar(BuildContext context) {
    final theme = Theme.of(context);

    final selectedElement = ref.watch(documentHierarchyProvider.select((x) => x.selectedElement));
    final selectedElementPageLocationIndex = ref.watch(
      documentHierarchyProvider.select((x) => x.selectedElementPageLocationIndex),
    );
    final layoutError = ref.watch(documentLayoutErrorProvider);

    if (selectedElement == null || selectedElementPageLocationIndex == null) return const SizedBox();

    final hasLayoutErrors = layoutError.layoutErrors.isNotEmpty;

    final navigationSection = buildNavigationSection(context, selectedElement);

    final layoutSection = buildLayoutSection(theme, selectedElement, selectedElementPageLocationIndex);
    final layoutErrorSection = buildLayoutErrorMeasurementSection(theme, layoutError, selectedElement);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        direction: Axis.horizontal,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 48,
        runSpacing: 16,
        children: [navigationSection, ...(hasLayoutErrors ? layoutErrorSection : layoutSection)],
      ),
    );
  }

  Widget buildDetailsSection(IconData icon, String value, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 12), Text(value)]),
    );
  }

  List<Widget> buildLayoutSection(
    ThemeData theme,
    DocumentHierarchyElement selectedElement,
    int selectedElementPageLocationIndex,
  ) {
    final location = selectedElement.pageLocations[selectedElementPageLocationIndex];

    String formatPages() {
      final pages = selectedElement.pageLocations.map((x) => x.pageNumber).toList();

      final current = location.pageNumber.toString();
      final min = pages.reduce((a, b) => a < b ? a : b);
      final max = pages.reduce((a, b) => a > b ? a : b);

      return "$current ($min-$max)";
    }

    String formatSize() {
      return "${location.width.toStringAsFixed(1)} x ${location.height.toStringAsFixed(1)}";
    }

    String formatPosition() {
      return "${location.left.toStringAsFixed(1)} / ${location.top.toStringAsFixed(1)}";
    }

    return [
      buildDetailsSection(
        FontAwesomeIcons.elementPage,
        formatPages(),
        "Selected element page visibility:\ncurrent page (min-max)",
      ),
      buildDetailsSection(FontAwesomeIcons.elementPosition, formatPosition(), "Selected element position"),
      buildDetailsSection(FontAwesomeIcons.elementSize, formatSize(), "Selected element size"),
    ];
  }

  Widget buildSourceCodeFilePath(ThemeData theme, String filePath) {
    final bodyTextStyle = theme.textTheme.bodyMedium;

    final primaryStyle = bodyTextStyle?.copyWith(fontWeight: FontWeightOptimizedForOperatingSystem.bold);
    final secondaryTextStyle = bodyTextStyle?.copyWith(
      color: bodyTextStyle.color?.withAlpha(160),
      fontWeight: FontWeightOptimizedForOperatingSystem.semibold,
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: path.dirname(filePath), style: secondaryTextStyle),
          TextSpan(text: path.separator, style: secondaryTextStyle),
          TextSpan(text: path.basename(filePath), style: primaryStyle),
        ],
      ),
    );
  }

  Widget buildSourceCodePreview(BuildContext context) {
    if (!showSourceCodePreview) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final location = documentHierarchyProviderInstance.findSourceCodeLocationOf(
      documentHierarchyProviderInstance.selectedElement,
    );

    if (location == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.colorScheme.onSecondaryContainer.withAlpha(128), height: 0),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSourceCodeFilePath(theme, location.filePath),
              const SizedBox(height: 12),
              SourceCodeVisualization(
                filePath: location.filePath,
                highlightLineNumber: location.lineNumber,
                showLinesBuffer: 9,
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                highlightColor: theme.colorScheme.secondaryContainer,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildNavigationSection(BuildContext context, DocumentHierarchyElement selectedElement) {
    final enablePositionButtons = selectedElement.pageLocations.length != 1;
    final showElementName = !ref.watch(applicationStateProvider.select((x) => x.showDocumentHierarchy));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => showSourceCodePreview = true),
          onExit: (_) => setState(() => showSourceCodePreview = false),
          child: IconButton(
            icon: Icon(FontAwesomeIcons.penLine, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: () => tryToOpenInCodeEditor(context),
          ),
        ),
        IconButton(
          icon: Icon(FontAwesomeIcons.arrowUp, size: 16),
          visualDensity: VisualDensity.compact,
          tooltip: "Previous occurrence",
          onPressed: enablePositionButtons
              ? () => documentHierarchyProviderInstance.changeSelectedElementPageNumberVisibility(-1)
              : null,
        ),
        IconButton(
          icon: Icon(FontAwesomeIcons.arrowDown, size: 16),
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

  tryToOpenInCodeEditor(BuildContext context) async {
    final location = documentHierarchyProviderInstance.findSourceCodeLocationOf(
      documentHierarchyProviderInstance.selectedElement,
    );

    if (location == null) return;

    tryOpenSourceCodePathInEditor(
      context,
      applicationStateProviderInstance.defaultCodeEditor,
      location.filePath,
      location.lineNumber,
    );
  }

  Iterable<Widget> buildLayoutErrorMeasurementSection(
    ThemeData theme,
    DocumentLayoutErrorProvider layoutErrorState,
    DocumentHierarchyElement element,
  ) {
    if (!layoutErrorState.containsLayoutError) return [];

    final currentLayoutErrorPageNumber = layoutErrorState.currentlySelectedLayoutError.measurement.pageNumber;

    final measurement = element.layoutErrorMeasurements
        .where((x) => x.pageNumber == currentLayoutErrorPageNumber)
        .firstOrNull;

    String formatSize(ElementSize? size) {
      if (size == null) return "-";
      return "${size.width.toStringAsFixed(1)} x ${size.height.toStringAsFixed(1)}";
    }

    String formatSpacePlanType() {
      if (measurement == null) return "Not measured";
      if (measurement.isLayoutErrorRootCause) return "Layout error root cause";
      if (measurement.spacePlanType == SpacePlanType.wrap) return "Wrap";
      if (measurement.spacePlanType == SpacePlanType.partialRender) return "Partial render";
      if (measurement.spacePlanType == SpacePlanType.fullRender) return "Full render";
      if (measurement.spacePlanType == SpacePlanType.empty) return "Empty";

      return "Not measured";
    }

    Widget buildIndicator() {
      const indicatorSize = 16.0;

      return Container(
        width: indicatorSize,
        height: indicatorSize,
        margin: EdgeInsets.only(left: 5),
        decoration: BoxDecoration(
          color: measurement.getAnnotationColor(),
          borderRadius: const BorderRadius.all(Radius.circular(indicatorSize)),
          border: Border.all(color: Colors.black, width: 0.5),
        ),
      );
    }

    Widget buildMeasurementStatus() {
      final hasWrapReason = measurement?.wrapReason != null && measurement!.wrapReason!.isNotEmpty;
      final spacePlanTypeStyle = hasWrapReason ? theme.textTheme.bodySmall : null;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildIndicator(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatSpacePlanType(), style: spacePlanTypeStyle),
              if (hasWrapReason) Text(measurement?.wrapReason ?? "", style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      );
    }

    Widget? buildAvailableSpace() {
      if (measurement == null) return null;

      return buildDetailsSection(
        FontAwesomeIcons.elementAvailableSpace,
        formatSize(measurement.availableSpace),
        "Available space for selected element",
      );
    }

    Widget? buildRequestedSpace() {
      if (measurement == null) return null;
      if (measurement.spacePlanType == SpacePlanType.wrap) return null;

      return buildDetailsSection(
        FontAwesomeIcons.elementRequiredSpace,
        formatSize(measurement.measurementSize),
        "Requested space for selected element",
      );
    }

    return [buildAvailableSpace(), buildRequestedSpace(), buildMeasurementStatus()].whereNotNull();
  }
}
