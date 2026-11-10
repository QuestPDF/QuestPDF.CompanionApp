import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview.dart';

import '../../document_hierarchy/state/document_hierarchy_hovered_element_provider.dart';
import '../../document_hierarchy/state/document_hierarchy_manual_measurement.dart';
import '../../document_hierarchy/state/document_hierarchy_provider.dart';
import '../state/document_viewer_state_provider.dart';
import 'document_preview_element_details.dart';

class DocumentPreviewLayout extends ConsumerWidget {
  final Key? searchKey;

  const DocumentPreviewLayout({super.key, this.searchKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final structure = ref.watch(documentPreviewImageCacheStateProvider);
    final selectedElement = ref.watch(documentHierarchyProvider.select((x) => x.selectedElement));
    final selectedElementPageLocationIndex = ref.watch(
      documentHierarchyProvider.select((x) => x.selectedElementPageLocationIndex),
    );
    final hoveredElement = ref.watch(documentHierarchyHoveredElementProvider);
    final documentHierarchyManualMeasurement = ref.watch(documentHierarchyManualMeasurementProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        DocumentPreview(
          pages: structure.pages,
          hoveredElement: hoveredElement.hoveredElement,
          selectedElement: selectedElement,
          selectedElementLocationIndex: selectedElementPageLocationIndex,
          manualMeasurementResult: documentHierarchyManualMeasurement.manualMeasurementResult,
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: DocumentPreviewElementDetails(searchKey: searchKey),
          ),
        ),
      ],
    );
  }
}
