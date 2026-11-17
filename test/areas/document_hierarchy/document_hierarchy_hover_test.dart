import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure_page_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_hovered_element_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_viewer_state_provider.dart';
import 'package:questpdf_companion/areas/document_preview_with_hierarchy_view.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

DocumentHierarchyElement buildDocument(String name, int textBlockCount) {
  return DocumentHierarchyElement('Document', null, null, false, [], [], [], null, [
    for (var i = 0; i < textBlockCount; i++)
      DocumentHierarchyElement(
        'TextBlock',
        '$name $i',
        null,
        true,
        [PageLocation(pageNumber: 1, left: 10, top: 30.0 + i * 50, right: 100, bottom: 60.0 + i * 50)],
        [],
        [],
        null,
        [],
      ),
  ]);
}

void main() {
  final application = applicationStateProviderInstance;
  final hierarchy = documentHierarchyProviderInstance;
  final hovered = documentHierarchyHoveredElementProviderInstance;

  test('hiding the hierarchy clears the hovered element', () {
    if (!application.showDocumentHierarchy) application.toggleDocumentHierarchyVisibility();

    hovered.setHoveredElement(DocumentHierarchyElement('Image', null, null, true, [], [], [], null, []));
    application.toggleDocumentHierarchyVisibility();

    expect(application.showDocumentHierarchy, isFalse);
    expect(hovered.hoveredElement, isNull);
  });

  group('with the pointer resting on a tree row', () {
    const outsideTree = Offset(900, 600);
    late TestGesture mouse;

    // not disposed: the providers expose global instances, which the container would dispose for the next test
    final container = ProviderContainer();

    Future<void> hoverThirdTextBlock(WidgetTester tester) async {
      final font = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      await font.load();
      await tester.binding.setSurfaceSize(const Size(1400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      if (!application.showDocumentHierarchy) application.toggleDocumentHierarchyVisibility();
      application.changeMode(ApplicationMode.documentPreview);
      hierarchy.setHierarchy(buildDocument('old', 6));
      documentPreviewImageCacheStateInstance.updateDocumentStructure([DocumentStructurePageSize(600, 1000)]);

      mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: outsideTree);
      addTearDown(mouse.removePointer);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final mode = ref.watch(applicationStateProvider.select((x) => x.currentMode));
                  return mode == ApplicationMode.documentPreview
                      ? const DocumentPreviewWithHierarchyView()
                      : const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await mouse.moveTo(tester.getCenter(find.text('old 2')));
      await tester.pumpAndSettle();
      expect(hovered.hoveredElement?.hint, 'old 2');
    }

    testWidgets('a new document moves the hover to the row that is now under the pointer', (tester) async {
      await hoverThirdTextBlock(tester);

      final newDocument = buildDocument('new', 6);
      hierarchy.setHierarchy(newDocument);
      await tester.pumpAndSettle();

      expect(hovered.hoveredElement, same(newDocument.children[2]));
    });

    testWidgets('a new document without a row under the pointer clears the hover', (tester) async {
      await hoverThirdTextBlock(tester);

      hierarchy.setHierarchy(buildDocument('new', 1));
      await tester.pumpAndSettle();

      expect(hovered.hoveredElement, isNull);
    });

    testWidgets('the hover of a previous document does not return with the preview', (tester) async {
      await hoverThirdTextBlock(tester);

      application.changeMode(ApplicationMode.genericException);
      await tester.pumpAndSettle();
      await mouse.moveTo(outsideTree);
      await tester.pumpAndSettle();

      hierarchy.setHierarchy(buildDocument('new', 6));
      application.changeMode(ApplicationMode.documentPreview);
      await tester.pumpAndSettle();

      expect(hovered.hoveredElement, isNull);
    });
  });
}
