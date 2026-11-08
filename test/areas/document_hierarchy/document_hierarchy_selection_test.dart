import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';

DocumentHierarchyElement element(List<PageLocation> locations) =>
    DocumentHierarchyElement('TextBlock', null, null, true, locations, [], [], null, []);

void main() {
  test('navigating an undrawn selection preserves it without dividing by zero', () {
    final state = DocumentHierarchyState();
    addTearDown(state.dispose);
    final selected = element([]);
    state.setSelectedElement(selected);
    state.changeSelectedElementPageNumberVisibility(1);
    state.changeSelectedElementPageNumberVisibility(-1);
    expect(state.selectedElement, same(selected));
    expect(state.selectedElementPageLocationIndex, 0);
  });

  test('occurrence navigation still wraps in both directions', () {
    final state = DocumentHierarchyState();
    addTearDown(state.dispose);
    state.setSelectedElement(
      element([
        for (var page = 1; page <= 3; page++) PageLocation(pageNumber: page, left: 0, top: 0, right: 100, bottom: 100),
      ]),
    );
    state.changeSelectedElementPageNumberVisibility(-1);
    expect(state.selectedElementPageLocationIndex, 2);
    state.changeSelectedElementPageNumberVisibility(1);
    expect(state.selectedElementPageLocationIndex, 0);
    state.changeSelectedElementPageNumberVisibility(1);
    expect(state.selectedElementPageLocationIndex, 1);
  });
}
