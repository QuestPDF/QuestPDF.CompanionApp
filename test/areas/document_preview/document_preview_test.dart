import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure_page_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_preview_pointer_location_state.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_viewer_state_provider.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

DocumentHierarchyElement element(List<PageLocation> locations) =>
    DocumentHierarchyElement('TextBlock', null, null, true, locations, [], [], null, []);

Future<DocumentPreviewState> showPreview(
  WidgetTester tester, {
  DocumentHierarchyElement? selected,
  int? locationIndex = 0,
  List<DocumentStructurePageSize>? pages,
}) async {
  documentPreviewImageCacheStateInstance.updateDocumentStructure(pages ?? [DocumentStructurePageSize(2000, 3000)]);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: SizedBox.expand(
          child: DocumentPreview(
            pages: documentPreviewImageCacheStateInstance.pages,
            hoveredElement: null,
            selectedElement: selected,
            selectedElementLocationIndex: locationIndex,
            manualMeasurementResult: null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.state<DocumentPreviewState>(find.byType(DocumentPreview));
}

Future<void> scroll(WidgetTester tester, Offset delta) async {
  await tester.sendEventToBinding(PointerScrollEvent(position: const Offset(400, 300), scrollDelta: delta));
  await tester.pump();
}

void previewTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      // The preview defers pointer notifications to the next event-loop turn.
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}

void main() {
  previewTest('an undrawn selection does not crash or move the viewport', (tester) async {
    final state = await showPreview(tester, selected: element([]));
    expect(tester.takeException(), isNull);
    expect(state.scale, 1);
    expect(state.translate, Offset.zero);
  });

  previewTest('a document without pages is safe', (tester) async {
    final state = await showPreview(tester, pages: []);
    expect(tester.takeException(), isNull);
    expect(state.pagePositions, isEmpty);
    expect(state.scale.isFinite, isTrue);
    documentPreviewPointerLocationStateInstance.update(PointerLocation(pageNumber: 1, x: 10, y: 10));
    state.zoomOnPage();
    expect(tester.takeException(), isNull);
  });

  previewTest('stale occurrence and page indexes are ignored', (tester) async {
    final selection = element([PageLocation(pageNumber: 2, left: 10, top: 10, right: 100, bottom: 100)]);
    final state = await showPreview(tester, selected: selection, locationIndex: 5);
    expect(tester.takeException(), isNull);
    state.zoomOnElement(selection, -1);
    state.zoomOnElement(selection, 0);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(state.scale, 1);
  });

  previewTest('a selection without an occurrence index is safe', (tester) async {
    await showPreview(tester, selected: element([]), locationIndex: null);
    expect(tester.takeException(), isNull);
  });

  previewTest('valid occurrences still focus the selected page', (tester) async {
    final selection = element([PageLocation(pageNumber: 1, left: 100, top: 100, right: 200, bottom: 200)]);
    final state = await showPreview(tester, selected: selection);
    expect(tester.takeException(), isNull);
    expect(state.scale, 3);
    expect(state.getVisiblePageFragments().any((fragment) => fragment.pageNumber == 1), isTrue);
  });

  for (final entry in {
    'horizontal': (const Offset(120, 0), const Offset(-75, 0)),
    'vertical': (const Offset(0, 120), const Offset(0, -75)),
    'diagonal': (const Offset(120, 240), const Offset(-75, -150)),
  }.entries) {
    previewTest('${entry.key} scroll input pans without changing zoom', (tester) async {
      final state = await showPreview(tester);
      await scroll(tester, entry.value.$1);
      expect(state.translate, entry.value.$2);
      expect(state.scale, 1);
    });
  }

  for (final delta in [const Offset(0, 120), const Offset(120, 0)]) {
    previewTest('Shift pans horizontally with input $delta', (tester) async {
      final state = await showPreview(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await scroll(tester, delta);
      expect(state.translate, const Offset(-75, 0));
      expect(state.scale, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    });
  }

  previewTest('Ctrl and vertical wheel input still zoom around the pointer', (tester) async {
    final state = await showPreview(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await scroll(tester, const Offset(0, -120));
    expect(state.scale, closeTo(exp(0.25), 0.000001));
    expect(state.translate.dy, closeTo(300 * (1 - exp(0.25)), 0.000001));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });
}
