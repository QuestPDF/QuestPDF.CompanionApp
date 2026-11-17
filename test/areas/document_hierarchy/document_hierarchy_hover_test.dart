import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_hovered_element_provider.dart';

void main() {
  test('hiding the hierarchy clears the hovered element', () {
    final application = applicationStateProviderInstance;
    final hovered = documentHierarchyHoveredElementProviderInstance;

    if (!application.showDocumentHierarchy) application.toggleDocumentHierarchyVisibility();

    hovered.setHoveredElement(DocumentHierarchyElement('Image', null, null, true, [], [], [], null, []));
    application.toggleDocumentHierarchyVisibility();

    expect(application.showDocumentHierarchy, isFalse);
    expect(hovered.hoveredElement, isNull);
  });
}
