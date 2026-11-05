import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/document_hierarchy_element.dart';

final documentHierarchyHoveredElementProviderInstance = DocumentHierarchyHoveredElementProvider();
final documentHierarchyHoveredElementProvider = ChangeNotifierProvider(
  (ref) => documentHierarchyHoveredElementProviderInstance,
);

class DocumentHierarchyHoveredElementProvider extends ChangeNotifier {
  DocumentHierarchyElement? hoveredElement;

  void setHoveredElement(DocumentHierarchyElement? newState) {
    hoveredElement = newState;
    notifyListeners();
  }
}
