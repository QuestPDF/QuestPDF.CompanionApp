import '../../../shared/prettify_name.dart';
import '../models/document_hierarchy_element.dart';

// how a document element is shown as a row of the structure tree
extension DocumentHierarchyTreePresentation on DocumentHierarchyElement {
  String get treeLabel {
    return switch (elementType) {
      "SourceCodePointer" => findProperty("MethodName") ?? "",
      "DebugPointer" => findProperty("Label") ?? "",
      _ => prettifyName(elementType),
    };
  }

  // document structure elements (components, sections, pages, etc.) have a hint like "Component / Name",
  // which only repeats their label
  String? get treeHint => elementType == "DebugPointer" ? null : hint;

  bool get isTreeHighlighted {
    if (elementType != "DebugPointer") return false;

    const highlightedTypes = ["DocumentStructure", "Section", "UserDefined"];
    return highlightedTypes.contains(getProperty("Type"));
  }
}
