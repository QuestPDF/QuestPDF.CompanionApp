import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';

import '../models/document_hierarchy_element_layout_error_measurement.dart';
import 'document_hierarchy_provider.dart';

final documentLayoutErrorProviderInstance = DocumentLayoutErrorProvider();
final documentLayoutErrorProvider = ChangeNotifierProvider((ref) => documentLayoutErrorProviderInstance);

class LayoutError {
  final DocumentHierarchyElement element;
  final DocumentHierarchyElementLayoutErrorMeasurement measurement;

  LayoutError(this.element, this.measurement);
}

class DocumentLayoutErrorProvider extends ChangeNotifier {
  List<LayoutError> layoutErrors = [];
  int currentlySelectedLayoutErrorIndex = 0;

  bool get containsLayoutError => numberOfLayoutErrors > 0;

  int get numberOfLayoutErrors => layoutErrors.length;

  LayoutError get currentlySelectedLayoutError => layoutErrors[currentlySelectedLayoutErrorIndex];

  // how the element was measured on the page of the selected layout error
  DocumentHierarchyElementLayoutErrorMeasurement? findMeasurementOf(DocumentHierarchyElement element) {
    if (!containsLayoutError) return null;

    final pageNumber = currentlySelectedLayoutError.measurement.pageNumber;
    return element.layoutErrorMeasurements.where((x) => x.pageNumber == pageNumber).firstOrNull;
  }

  void update() {
    layoutErrors = documentHierarchyProviderInstance.listLayoutErrors();
    currentlySelectedLayoutErrorIndex = 0;
    changeSelectedErrorLayoutPage(0);
    notifyListeners();
  }

  void changeSelectedErrorLayoutPage(int direction) {
    if (!containsLayoutError) return;

    currentlySelectedLayoutErrorIndex = (currentlySelectedLayoutErrorIndex + direction) % numberOfLayoutErrors;
    documentHierarchyProviderInstance.setSelectedElementAndFocusOnIt(currentlySelectedLayoutError.element);
    notifyListeners();
  }
}
