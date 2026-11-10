import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element_layout_error_measurement.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/element_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_layout_error_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_search_state.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_element_details.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await font.load();
  });

  testWidgets('an undrawn element retains code navigation and disables occurrence buttons', (tester) async {
    final hierarchy = DocumentHierarchyState()
      ..setSelectedElement(DocumentHierarchyElement('TextBlock', null, null, true, [], [], [], null, []));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentHierarchyProvider.overrideWith((ref) => hierarchy),
          documentLayoutErrorProvider.overrideWith((ref) => DocumentLayoutErrorProvider()),
          applicationStateProvider.overrideWith((ref) => ApplicationStateProvider()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: DocumentPreviewElementDetails()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
    expect(buttons, hasLength(3));
    expect(buttons.first.onPressed, isNotNull);
    expect(buttons[1].onPressed, isNull);
    expect(buttons[2].onPressed, isNull);
  });

  for (final searchActive in [false, true]) {
    testWidgets('a narrow layout error row reveals its explanation ${searchActive ? 'during search' : 'without search'}', (
      tester,
    ) async {
      const reason =
          'The available space is too small to render this element. '
          'The requested content cannot fit within the remaining page height.\n'
          'Increase the available space or reduce the size of the content.';
      final measurement = DocumentHierarchyElementLayoutErrorMeasurement(
        1,
        ElementSize(width: 100, height: 20),
        null,
        SpacePlanType.wrap,
        reason,
        true,
      );
      final element = DocumentHierarchyElement('TextBlock', null, null, true, [], [measurement], [], null, []);
      final hierarchy = DocumentHierarchyState()..setSelectedElement(element);
      final layoutErrors = DocumentLayoutErrorProvider()..layoutErrors = [LayoutError(element, measurement)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentHierarchyProvider.overrideWith((ref) => hierarchy),
            documentLayoutErrorProvider.overrideWith((ref) => layoutErrors),
            applicationStateProvider.overrideWith(
              (ref) => ApplicationStateProvider()..showDocumentHierarchy = !searchActive,
            ),
            documentHierarchySearchStateProvider.overrideWith(
              (ref) => DocumentHierarchySearchState()..searchPhrase = searchActive ? "" : null,
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: 280, child: DocumentPreviewElementDetails()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final status = find.byWidgetPredicate(
        (widget) => widget is Text && (widget.textSpan?.toPlainText().contains(reason) ?? false),
      );
      expect(status, findsOneWidget);
      final statusText = tester.widget<Text>(status);
      expect(statusText.maxLines, 1);
      expect(statusText.overflow, TextOverflow.ellipsis);
      final statusParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: status, matching: find.byType(RichText)),
      );
      expect(statusParagraph.didExceedMaxLines, isTrue);
      final rowHeight = tester.getSize(find.byType(DocumentPreviewElementDetails)).height;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(status));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      final explanation = find.text(reason);
      expect(explanation, findsOneWidget);
      final explanationParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: explanation, matching: find.byType(RichText)),
      );
      expect(explanationParagraph.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.byType(DocumentPreviewElementDetails)).height, rowHeight);
      expect(tester.takeException(), isNull);
    });
  }
}
