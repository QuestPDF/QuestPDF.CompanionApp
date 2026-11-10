import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/theme/app_theme.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element_layout_error_measurement.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure_page_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/element_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_search_state.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_layout_error_provider.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_layout.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_layout_error_notification.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_search.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_show_button.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_viewer_state_provider.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_layout.dart';
import 'package:questpdf_companion/areas/document_preview_with_hierarchy_view.dart';
import 'package:questpdf_companion/shared/keyboard_shortcuts.dart';
import 'package:questpdf_companion/shared/font_awesome_icons.dart';
import 'package:questpdf_companion/shared/pointer_over_application.dart';

Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('layout error navigation stays available with hidden hierarchy, selection and search changes', (
    tester,
  ) async {
    await (FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();
    final container = ProviderContainer();
    final application = applicationStateProviderInstance..changeMode(ApplicationMode.documentPreview);
    final hierarchy = documentHierarchyProviderInstance;
    final errors = documentLayoutErrorProviderInstance;
    final search = documentHierarchySearchStateInstance;
    final elements = [
      for (var page = 1; page <= 2; page++)
        DocumentHierarchyElement(
          'TextBlock',
          null,
          'needle $page',
          true,
          [PageLocation(pageNumber: page, left: 10, top: 10, right: 100, bottom: 100)],
          [
            DocumentHierarchyElementLayoutErrorMeasurement(
              page,
              ElementSize(width: 200, height: 670),
              null,
              SpacePlanType.wrap,
              'The available horizontal space is less than the minimum width.',
              true,
            ),
          ],
          [],
          null,
          [],
        ),
    ];
    hierarchy.setHierarchy(DocumentHierarchyElement('Document', null, null, false, [], [], [], null, elements));
    documentPreviewImageCacheStateInstance.updateDocumentStructure([
      DocumentStructurePageSize(600, 1000),
      DocumentStructurePageSize(600, 1000),
    ]);
    isPointerOverApplication.value = false;
    final summary = find.byType(DocumentHierarchyLayoutErrorNotification);
    Finder counter(String text) => find.descendant(of: summary, matching: find.text(text));
    void expectAlignedIcons() {
      double iconCenter(Finder parent, IconData icon) =>
          tester.getCenter(find.descendant(of: parent, matching: find.byIcon(icon))).dx;
      final details = find.byKey(const ValueKey('preview-selected-element-details'));
      final searchIconCenter = iconCenter(find.byType(DocumentHierarchySearch), FontAwesomeIcons.search);
      expect(iconCenter(details, FontAwesomeIcons.penLine), searchIconCenter);
      if (summary.evaluate().isNotEmpty) {
        expect(iconCenter(summary, FontAwesomeIcons.layoutError), searchIconCenter);
      }
    }

    void expectPersistentToggle() {
      final toggle = find.byType(DocumentHierarchyShowButton);
      expect(
        tester.widget<AnimatedOpacity>(find.descendant(of: toggle, matching: find.byType(AnimatedOpacity))).opacity,
        1,
      );
      expect(find.descendant(of: toggle, matching: find.byType(IconButton)).hitTestable(), findsOneWidget);
    }

    try {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.binding.setSurfaceSize(const Size(2200, 700));
        search.reset();
        if (application.showDocumentHierarchy) application.toggleDocumentHierarchyVisibility();
        errors.update();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildAppTheme(Brightness.dark),
              home: const Scaffold(body: Stack(children: [DocumentPreviewWithHierarchyView(), KeyboardShortcuts()])),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expect(find.descendant(of: find.byType(DocumentPreviewLayout), matching: summary), findsOneWidget);
        expect(counter('1 / 2'), findsOneWidget);
        expectPersistentToggle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byTooltip('Next layout error'));
        await tester.pumpAndSettle();
        expect(counter('2 / 2'), findsOneWidget);
        expect(hierarchy.selectedElement, same(elements.last));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(counter('1 / 2'), findsOneWidget);
        expect(hierarchy.selectedElement, same(elements.first));

        hierarchy.setSelectedElement(null);
        await tester.pumpAndSettle();
        expect(summary, findsOneWidget);
        expect(find.byTooltip('Previous occurrence'), findsNothing);
        expectPersistentToggle();
        await tester.tap(find.byTooltip('Next layout error'));
        await tester.pumpAndSettle();
        expect(hierarchy.selectedElement, same(elements.last));

        await tester.tap(find.descendant(of: find.byType(DocumentHierarchyShowButton), matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(DocumentHierarchyLayout), matching: summary), findsOneWidget);
        expect(find.descendant(of: find.byType(DocumentPreviewLayout), matching: summary), findsNothing);
        await shortcut(tester, LogicalKeyboardKey.keyB);
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expect(counter('2 / 2'), findsOneWidget);

        await shortcut(tester, LogicalKeyboardKey.keyF);
        expect(summary, findsOneWidget);
        expect(find.byType(DocumentHierarchySearch), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'needle');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Previous layout error'));
        await tester.pumpAndSettle();
        expect(counter('1 / 2'), findsOneWidget);
        expect(hierarchy.selectedElement, same(elements.first));
        expect(search.searchPhrase, 'needle');
        await tester.tap(find.byTooltip('Next layout error'));
        await tester.pumpAndSettle();
        expect(counter('2 / 2'), findsOneWidget);
        expect(hierarchy.selectedElement, same(elements.last));
        final errorRect = tester.getRect(summary);
        final searchRect = tester.getRect(find.byType(DocumentHierarchySearch));
        final detailsRect = tester.getRect(find.byTooltip('Previous occurrence'));
        expect(errorRect.bottom, lessThan(searchRect.top));
        expect(searchRect.bottom, lessThanOrEqualTo(detailsRect.top));
        expectAlignedIcons();
        expect(errorRect.width, 300);
        expect(searchRect.width, 360);
        expect(tester.getSize(find.byKey(const ValueKey('preview-selected-element-details'))).width, 1000);
        expect(tester.getSize(find.byKey(const ValueKey('preview-toolbar-divider'))), const Size(2200, 1));
        expect(tester.getSize(find.byKey(const ValueKey('preview-toolbar-divider-2'))), const Size(2200, 1));
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        final input = tester.widget<EditableText>(find.byType(EditableText));
        input.controller.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
        final value = input.controller.value;
        final searchWidgetState = tester.state(find.byType(DocumentHierarchySearch));
        for (final width in [2200.0, 1400.0, 800.0, 360.0, 280.0, 2200.0]) {
          await tester.binding.setSurfaceSize(Size(width, 700));
          await tester.pumpAndSettle();
          expect(summary, findsOneWidget);
          expect(counter('2 / 2'), findsOneWidget);
          final resizedError = tester.getRect(summary);
          final resizedSearch = tester.getRect(find.byType(DocumentHierarchySearch));
          final resizedDetails = tester.getRect(find.byKey(const ValueKey('preview-selected-element-details')));
          expect(resizedError.bottom, lessThan(resizedSearch.top));
          expect(resizedSearch.bottom, lessThan(resizedDetails.top));
          expect(resizedError.width, lessThanOrEqualTo(300));
          expect(resizedSearch.width, lessThanOrEqualTo(360));
          expect(resizedDetails.width, width < 1000 ? width : 1000);
          expect(tester.getSize(find.byKey(const ValueKey('preview-toolbar-divider'))), Size(width, 1));
          expect(tester.getSize(find.byKey(const ValueKey('preview-toolbar-divider-2'))), Size(width, 1));
          expect(tester.state(find.byType(DocumentHierarchySearch)), same(searchWidgetState));
          final currentInput = tester.widget<EditableText>(find.byType(EditableText));
          expect(currentInput.controller.value, value);
          expect(currentInput.focusNode.hasFocus, isTrue);
          expectPersistentToggle();
          expectAlignedIcons();
          expect(tester.takeException(), isNull);
        }

        errors.layoutErrors = [];
        errors.notifyListeners();
        await tester.pumpAndSettle();
        expect(summary, findsNothing);
        expect(find.byType(DocumentHierarchySearch), findsOneWidget);
        expectAlignedIcons();
        expect(tester.state(find.byType(DocumentHierarchySearch)), same(searchWidgetState));
        expect(tester.widget<EditableText>(find.byType(EditableText)).controller.value, value);
        expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
        errors.layoutErrors = [
          for (final element in elements) LayoutError(element, element.layoutErrorMeasurements.single),
        ];
        errors.notifyListeners();
        await tester.pumpAndSettle();
        expect(summary, findsOneWidget);
        expect(tester.state(find.byType(DocumentHierarchySearch)), same(searchWidgetState));
        expect(tester.widget<EditableText>(find.byType(EditableText)).controller.value, value);
        expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
        errors.layoutErrors = [];
        errors.notifyListeners();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchySearch), findsNothing);
        expect(summary, findsNothing);
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
      isPointerOverApplication.value = false;
      await tester.binding.setSurfaceSize(null);
    }
  });
}
