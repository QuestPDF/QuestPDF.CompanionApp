import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document_hierarchy_element.dart';
import '../models/page_location.dart';
import 'document_layout_error_provider.dart';

final documentHierarchyProviderInstance = DocumentHierarchyState();
final documentHierarchyProvider = ChangeNotifierProvider((ref) => documentHierarchyProviderInstance);

class DocumentHierarchyState extends ChangeNotifier {
  DocumentHierarchyElement? root;
  DocumentHierarchyElement? selectedElement;
  int? selectedElementPageLocationIndex;

  void setHierarchy(DocumentHierarchyElement newRoot) {
    _linkParents(newRoot);
    _expandClosestChildrenHelper(newRoot);

    root = newRoot;
    _expandDocumentContentHelper();
    selectedElement = null;

    notifyListeners();
  }

  void _linkParents(DocumentHierarchyElement item) {
    for (final element in item.children) {
      element.parent = item;
      _linkParents(element);
    }
  }

  void _expandDocumentContentHelper() {
    if (root == null) return;

    final documentContent = root!.children.firstOrNullWhere(
      (x) => x.properties.where((y) => y.value == "Content").isNotEmpty,
    );

    if (documentContent != null) _expandChildrenSmartHelper(documentContent);
  }

  void _expandClosestChildrenHelper(DocumentHierarchyElement item) {
    item.isExpanded = true;

    if (item.isFolder) return;

    item.children.forEach(_expandClosestChildrenHelper);
  }

  void _expandAllChildrenHelper(DocumentHierarchyElement item) {
    for (final element in item.selfAndDescendants) {
      element.isExpanded = true;
    }
  }

  void _collapseAllChildrenHelper(DocumentHierarchyElement item) {
    for (final element in item.selfAndDescendants) {
      element.isExpanded = !element.isExpandable;
    }
  }

  void _expandChildrenSmartHelper(DocumentHierarchyElement item) {
    if (item.selfAndDescendants.length < 32) {
      _expandAllChildrenHelper(item);
    } else {
      _expandClosestChildrenHelper(item);
    }
  }

  void _expandToShowElementHelper(DocumentHierarchyElement? element) {
    while (element != null) {
      element.isExpanded = true;
      element = element.parent;
    }
  }

  void setSelectedElement(DocumentHierarchyElement? newState) {
    if (selectedElement == null && newState == null) return;

    if (selectedElement == newState && selectedElement!.isExpandable && selectedElement!.isExpanded) {
      _collapseAllChildrenHelper(selectedElement!);
      notifyListeners();
      return;
    }

    selectedElement = newState;
    selectedElementPageLocationIndex = 0;

    if (selectedElement != null && selectedElement!.isExpandable) {
      _expandToShowElementHelper(selectedElement!);
      _expandChildrenSmartHelper(selectedElement!);
    }

    notifyListeners();
  }

  // selects the element and resets the expansion of its subtree, so the tree shows it with its closest children
  void setSelectedElementAndFocusOnIt(DocumentHierarchyElement element) {
    if (element == selectedElement) return;

    selectedElement = element;
    selectedElementPageLocationIndex = 0;

    _collapseAllChildrenHelper(element);
    _expandToShowElementHelper(element);
    _expandChildrenSmartHelper(element);
    notifyListeners();
  }

  void changeSelectedElementPageNumberVisibility(int direction) {
    if (selectedElement == null) return;

    selectedElementPageLocationIndex =
        (selectedElementPageLocationIndex! + direction) % selectedElement!.pageLocations.length;
    notifyListeners();
  }

  void findPreviewClickedElement(int pageNumber, double x, double y) {
    if (root == null) return;

    // the smallest leaf or visual element under the pointer, together with the page location that was clicked
    final clicked = root!.selfAndDescendants
        .where((node) => node.children.isEmpty || node.isVisual)
        .expand(
          (element) => element.pageLocations
              .mapIndexed((index, location) => (element: element, location: location, index: index))
              .where((candidate) => candidate.location.contains(pageNumber, x, y)),
        )
        .minBy((candidate) => candidate.location.area);

    if (clicked == null) return;

    selectedElement = clicked.element;
    selectedElementPageLocationIndex = clicked.index;
    _collapseAllChildrenHelper(root!);
    _expandToShowElementHelper(selectedElement!);
    _expandChildrenSmartHelper(selectedElement!);
    notifyListeners();
  }

  List<LayoutError> listLayoutErrors() {
    if (root == null) return [];

    return root!.selfAndDescendants
        .expand(
          (element) =>
              element.layoutErrorMeasurements.where((x) => x.isLayoutErrorRootCause).map((x) => LayoutError(element, x)),
        )
        .toList();
  }

  // the closest ancestor (or the element itself) that knows where it was declared
  SourceCodeLocation? findSourceCodeLocationOf(DocumentHierarchyElement? element) {
    for (var current = element; current != null; current = current.parent) {
      final sourceCodePath = current.sourceCodeDeclarationPath;

      if (sourceCodePath != null) {
        return SourceCodeLocation(filePath: sourceCodePath.filePath, lineNumber: sourceCodePath.lineNumber);
      }

      if (current.elementType == "SourceCodePointer") {
        final filePath = current.getProperty("FilePath");
        final lineNumber = int.tryParse(current.getProperty("LineNumber"));

        if (filePath.isEmpty || lineNumber == null) return null;

        return SourceCodeLocation(filePath: filePath, lineNumber: lineNumber);
      }
    }

    return null;
  }

  DocumentHierarchyElement? findClickableLink(int pageNumber, double x, double y) {
    if (root == null) return null;

    return root!.selfAndDescendants.firstOrNullWhere((node) {
      final isLink = node.elementType == "SectionLink" || node.elementType == "Hyperlink";
      final isClicked = node.pageLocations.any((location) => location.contains(pageNumber, x, y));

      return isLink && isClicked;
    });
  }

  void openClickableLink(DocumentHierarchyElement element) {
    void openHyperlink(DocumentHierarchyElement element) {
      var url = element.getProperty("Url");

      if (url.isNullOrEmpty) return;

      if (!url.startsWith("http")) {
        url = "https://$url";
      }

      launchUrl(Uri.parse(url));
    }

    void openSectionLink(DocumentHierarchyElement element) {
      final sectionName = element.getProperty("SectionName");

      final targetSection = root!.selfAndDescendants.firstOrNullWhere(
        (node) => node.elementType == "Section" && node.getProperty("SectionName") == sectionName,
      );

      if (targetSection == null) return;

      setSelectedElementAndFocusOnIt(targetSection);
    }

    if (element.elementType == "Hyperlink") {
      openHyperlink(element);
    } else if (element.elementType == "SectionLink") {
      openSectionLink(element);
    }
  }
}

class SourceCodeLocation {
  final String filePath;
  final int lineNumber;

  SourceCodeLocation({required this.filePath, required this.lineNumber});
}
