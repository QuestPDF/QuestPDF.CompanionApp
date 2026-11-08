import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure_page_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_viewer_state_provider.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_layout.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

void main() {
  testWidgets('native trackpad pan and pinch release the selection and move the viewport', (tester) async {
    final container = ProviderContainer();
    final hierarchy = documentHierarchyProviderInstance;
    final selected = DocumentHierarchyElement(
      'TextBlock',
      null,
      null,
      true,
      [PageLocation(pageNumber: 1, left: 500, top: 500, right: 600, bottom: 600)],
      [],
      [],
      null,
      [],
    );
    hierarchy.setHierarchy(selected);
    documentPreviewImageCacheStateInstance.updateDocumentStructure([DocumentStructurePageSize(2000, 3000)]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(body: DocumentPreviewLayout()),
        ),
      ),
    );
    await tester.pump();

    try {
      for (final pinch in [false, true]) {
        hierarchy.setSelectedElement(selected);
        await tester.pump();
        final state = tester.state<DocumentPreviewState>(find.byType(DocumentPreview));
        final before = state.translate;
        final scaleBefore = state.scale;
        const position = Offset(500, 350);
        await tester.sendEventToBinding(const PointerPanZoomStartEvent(pointer: 1, position: position));
        for (var step = 1; step <= 3; step++) {
          await tester.sendEventToBinding(
            PointerPanZoomUpdateEvent(
              pointer: 1,
              position: position,
              pan: pinch ? Offset.zero : Offset(0, -50.0 * step),
              panDelta: pinch ? Offset.zero : const Offset(0, -50),
              scale: pinch ? 1 + step * 0.2 : 1,
            ),
          );
          await tester.pump();
        }
        expect(hierarchy.selectedElement, isNull);
        if (pinch) {
          expect(state.scale, greaterThan(scaleBefore));
        } else {
          expect(state.translate.dy, lessThan(before.dy));
          expect(state.scale, scaleBefore);
        }
        await tester.sendEventToBinding(const PointerPanZoomEndEvent(pointer: 1, position: position));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      container.dispose();
    }
  });
}
