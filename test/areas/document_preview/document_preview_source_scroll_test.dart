import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure_page_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/source_code_path.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_search_state.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_viewer_state_provider.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_element_details.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_layout.dart';
import 'package:questpdf_companion/shared/font_awesome_icons.dart';
import 'package:questpdf_companion/shared/source_code_visualization.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

final class SourceFile implements File {
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      List.generate(40, (index) => 'var value$index = $index;').join('\n');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('source preview stays open and scrolls inside a short viewport, including during search', (tester) async {
    await (FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();
    await tester.binding.setSurfaceSize(const Size(600, 456));
    final container = ProviderContainer();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(599, 455));
    final application = applicationStateProviderInstance;
    if (application.showDocumentHierarchy) application.toggleDocumentHierarchyVisibility();
    final search = documentHierarchySearchStateInstance;
    final selected = DocumentHierarchyElement(
      'TextBlock',
      null,
      'needle',
      true,
      [PageLocation(pageNumber: 1, left: 20, top: 20, right: 100, bottom: 100)],
      [],
      [],
      SourceCodePath('/example/Test.cs', 20),
      [],
    );
    documentHierarchyProviderInstance.setHierarchy(selected);
    documentPreviewImageCacheStateInstance.updateDocumentStructure([DocumentStructurePageSize(600, 1000)]);

    try {
      await IOOverrides.runZoned(() async {
        for (final searching in [false, true]) {
          search.update(searching ? 'needle' : null);
          documentHierarchyProviderInstance.setSelectedElementAndFocusOnIt(selected);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: buildAppTheme(Brightness.light),
                home: const Scaffold(body: DocumentPreviewLayout()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await mouse.moveTo(tester.getCenter(find.byIcon(FontAwesomeIcons.penLine)));
          await tester.pumpAndSettle();
          expect(find.byType(SourceCodeVisualization), findsOneWidget);
          final detailsRect = tester.getRect(find.byType(DocumentPreviewElementDetails));
          expect(detailsRect.bottom, lessThanOrEqualTo(456));

          final scrollView = find.descendant(
            of: find.byType(DocumentPreviewElementDetails),
            matching: find.byWidgetPredicate(
              (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.vertical,
            ),
          );
          final position = tester.getCenter(scrollView);
          await mouse.moveTo(position);
          await tester.pumpAndSettle();
          expect(
            find.byType(SourceCodeVisualization),
            findsOneWidget,
            reason: 'Moving into the snippet must keep it open',
          );
          await tester.sendEventToBinding(PointerScrollEvent(position: position, scrollDelta: const Offset(0, 600)));
          await tester.pumpAndSettle();
          final scrollable = tester.state<ScrollableState>(
            find.descendant(of: scrollView, matching: find.byType(Scrollable)).first,
          );
          expect(scrollable.position.pixels, greaterThan(0));
          expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
          expect(tester.takeException(), isNull);
          await mouse.moveTo(const Offset(700, 480));
          await tester.pumpAndSettle();
          expect(find.byType(SourceCodeVisualization), findsNothing);
        }
      }, createFile: (_) => SourceFile());
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      container.dispose();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
