import 'package:json_annotation/json_annotation.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';

import 'document_hierarchy_element_layout_error_measurement.dart';
import 'element_property.dart';
import 'source_code_path.dart';

part 'document_hierarchy_element.g.dart';

@JsonSerializable()
class DocumentHierarchyElement {
  final String elementType;
  final String? hint;
  final String? searchableContent;
  final bool isSingleChildContainer;
  final List<PageLocation> pageLocations;
  final List<DocumentHierarchyElementLayoutErrorMeasurement> layoutErrorMeasurements;
  final List<ElementProperty> properties;
  final SourceCodePath? sourceCodeDeclarationPath;
  final List<DocumentHierarchyElement> children;

  @JsonKey(includeFromJson: false)
  DocumentHierarchyElement? parent;

  @JsonKey(includeFromJson: false)
  bool isExpanded = false;

  DocumentHierarchyElement(
    this.elementType,
    this.hint,
    this.searchableContent,
    this.isSingleChildContainer,
    this.pageLocations,
    this.layoutErrorMeasurements,
    this.properties,
    this.sourceCodeDeclarationPath,
    this.children,
  );

  factory DocumentHierarchyElement.fromJson(Map<String, dynamic> json) => _$DocumentHierarchyElementFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentHierarchyElementToJson(this);
}

// the element types that paint something themselves; every other element only lays out its children
const _visualElementTypes = {
  "TextBlock",
  "Background",
  "Border",
  "Image",
  "DynamicImage",
  "SvgImage",
  "DynamicSvgImage",
  "Line",
  "SvgPath",
};

extension DocumentHierarchyElementExtensions on DocumentHierarchyElement {
  bool get isVisual => _visualElementTypes.contains(elementType);

  bool get isFolder => !isSingleChildContainer && children.isNotEmpty;

  bool get isExpandable => isFolder || (parent?.isFolder ?? false);

  // this element first, then its children recursively
  List<DocumentHierarchyElement> get selfAndDescendants {
    final result = <DocumentHierarchyElement>[];

    void visit(DocumentHierarchyElement element) {
      result.add(element);
      element.children.forEach(visit);
    }

    visit(this);
    return result;
  }

  bool isVisibleOn(List<PageLocation> visibleLocations) {
    return visibleLocations.any((visible) => pageLocations.any((location) => location.intersects(visible)));
  }

  String? findProperty(String label) {
    return properties.where((x) => x.label == label).firstOrNull?.value;
  }

  String getProperty(String label) {
    return properties.firstWhere((x) => x.label == label).value;
  }
}
