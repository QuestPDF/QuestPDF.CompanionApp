import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_hide_button.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_layout.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_search.dart';
import 'package:questpdf_companion/areas/document_hierarchy/widgets/document_hierarchy_show_button.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_viewer_state_provider.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_layout.dart';
import 'package:questpdf_companion/areas/document_preview_with_hierarchy_view.dart';
import 'package:questpdf_companion/shared/keyboard_shortcuts.dart';
import 'package:questpdf_companion/shared/pointer_over_application.dart';
import 'package:questpdf_companion/shared/source_code_visualization.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

final class PreviewSourceFile implements File {
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => '// Document source';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> controlShortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS && Platform.isMacOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search stays usable above the preview while the hierarchy is hidden on desktop', (tester) async {
    final font = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await font.load();
    final container = ProviderContainer();
    final application = applicationStateProviderInstance..changeMode(ApplicationMode.documentPreview);
    final hierarchy = documentHierarchyProviderInstance;
    final search = documentHierarchySearchStateInstance;
    void expectToggleVisible(bool visible) {
      final toggle = find.byType(DocumentHierarchyShowButton);
      final fade = tester.widget<AnimatedOpacity>(find.descendant(of: toggle, matching: find.byType(AnimatedOpacity)));
      expect(fade.opacity, visible ? 1 : 0);
      final button = find.descendant(of: toggle, matching: find.byType(IconButton));
      expect(button.hitTestable(), visible ? findsOneWidget : findsNothing);
    }

    Future<void> expectToggleVisibleAfterPointerExit() async {
      isPointerOverApplication.value = true;
      await tester.pumpAndSettle();
      expectToggleVisible(true);
      isPointerOverApplication.value = false;
      await tester.pumpAndSettle();
      expectToggleVisible(true);
    }

    final matches = [
      for (var i = 0; i < 2; i++)
        DocumentHierarchyElement(
          'TextBlock',
          null,
          'needle $i',
          true,
          [PageLocation(pageNumber: 1, left: 10, top: 30.0 + i * 100, right: 100, bottom: 60.0 + i * 100)],
          [],
          [],
          SourceCodePath('/app/Document.cs', 1),
          [],
        ),
    ];
    hierarchy.setHierarchy(DocumentHierarchyElement('Document', null, null, false, [], [], [], null, matches));
    documentPreviewImageCacheStateInstance.updateDocumentStructure([DocumentStructurePageSize(600, 1000)]);
    isPointerOverApplication.value = true;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(900, 600));

    try {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        await tester.binding.setSurfaceSize(const Size(1400, 700));
        search.reset();
        if (application.showDocumentHierarchy) application.toggleDocumentHierarchyVisibility();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildAppTheme(Brightness.light),
              home: const Scaffold(body: Stack(children: [DocumentPreviewWithHierarchyView(), KeyboardShortcuts()])),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expectToggleVisible(true);
        isPointerOverApplication.value = false;
        await tester.pumpAndSettle();
        expectToggleVisible(false);

        await controlShortcut(tester, LogicalKeyboardKey.keyF);
        expect(application.showDocumentHierarchy, isFalse);
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expect(
          find.descendant(of: find.byType(DocumentPreviewLayout), matching: find.byType(DocumentHierarchySearch)),
          findsOneWidget,
        );
        expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
        expect(tester.getSize(find.byType(DocumentHierarchySearch)).width, lessThanOrEqualTo(360));
        expect(find.byKey(const ValueKey('preview-toolbar-divider')), findsNothing);
        await expectToggleVisibleAfterPointerExit();

        await tester.enterText(find.byType(TextField), 'needle');
        await tester.pumpAndSettle();
        expect(find.text('1 / 2'), findsOneWidget);
        expect(hierarchy.selectedElement, same(matches.first));
        final wideSearchRect = tester.getRect(find.byType(DocumentHierarchySearch));
        final wideDetailsRect = tester.getRect(find.byTooltip('Previous occurrence'));
        expect(wideSearchRect.bottom, lessThanOrEqualTo(wideDetailsRect.top));
        expect(tester.getSize(find.byKey(const ValueKey('preview-selected-element-details'))).width, 1000);
        expect(wideSearchRect.height, AppSizes.barHeight);
        expect(wideSearchRect.width, 360);
        final wideDivider = tester.getRect(find.byKey(const ValueKey('preview-toolbar-divider')));
        expect(wideDivider.size, const Size(1400, 1));
        expect(wideDivider.top, wideSearchRect.bottom);
        expect(wideDivider.bottom, lessThanOrEqualTo(wideDetailsRect.top));
        await expectToggleVisibleAfterPointerExit();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(find.text('2 / 2'), findsOneWidget);
        expect(hierarchy.selectedElement, same(matches.last));
        final searchButtons = find.descendant(of: find.byType(DocumentHierarchySearch), matching: find.byType(IconButton));
        await tester.tap(searchButtons.first);
        await tester.pumpAndSettle();
        expect(hierarchy.selectedElement, same(matches.first));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchySearch), findsNothing);
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expect(hierarchy.selectedElement, same(matches.first));

        await expectToggleVisibleAfterPointerExit();
        await controlShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.enterText(find.byType(TextField), 'needle');
        await tester.pumpAndSettle();
        final searchWidgetState = tester.state(find.byType(DocumentHierarchySearch));
        final previewState = tester.state<DocumentPreviewState>(find.byType(DocumentPreview));
        final input = tester.widget<EditableText>(find.byType(EditableText));
        input.controller.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
        final editingValue = input.controller.value;

        void expectPreservedSearch() {
          expect(tester.state(find.byType(DocumentHierarchySearch)), same(searchWidgetState));
          final currentInput = tester.widget<EditableText>(find.byType(EditableText));
          expect(currentInput.controller.value, editingValue);
          expect(currentInput.focusNode.hasFocus, isTrue);
          expect(tester.state<DocumentPreviewState>(find.byType(DocumentPreview)), same(previewState));
          expect(search.searchPhrase, 'needle');
          expect(search.searchResults, matches);
          expect(tester.takeException(), isNull);
        }

        await IOOverrides.runZoned(() async {
          // The code button is the first button in the selected element's navigation section.
          final navigation = find.ancestor(of: find.byTooltip('Previous occurrence'), matching: find.byType(Row)).first;
          final code = find.descendant(of: navigation, matching: find.byType(IconButton)).first;
          await mouse.moveTo(tester.getCenter(code));
          await tester.pumpAndSettle();
          final source = find.byType(SourceCodeVisualization);
          expect(source, findsOneWidget);
          expect(tester.getSize(source).width, closeTo(1400 - 24, 0.01));
          expect(tester.getTopLeft(source).dy, greaterThan(AppSizes.barHeight));
          expectPreservedSearch();
          await mouse.moveTo(const Offset(900, 600));
          await tester.pumpAndSettle();
          expect(source, findsNothing);
        }, createFile: (_) => PreviewSourceFile());

        await tester.tap(find.descendant(of: find.byType(DocumentHierarchyShowButton), matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchyLayout), findsOneWidget);
        expect(
          find.descendant(of: find.byType(DocumentHierarchyLayout), matching: find.byType(DocumentHierarchySearch)),
          findsOneWidget,
        );
        expectPreservedSearch();

        final hideButton = find.descendant(
          of: find.byType(DocumentHierarchyHideButton),
          matching: find.byType(IconButton),
        );
        await mouse.moveTo(tester.getCenter(hideButton));
        await tester.pumpAndSettle();
        await tester.tap(hideButton);
        await tester.pumpAndSettle();
        expect(application.showDocumentHierarchy, isFalse);
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expectPreservedSearch();

        await controlShortcut(tester, LogicalKeyboardKey.keyB);
        expect(find.byType(DocumentHierarchyLayout), findsOneWidget);
        expectPreservedSearch();
        await controlShortcut(tester, LogicalKeyboardKey.keyB);
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expectPreservedSearch();

        await tester.binding.setSurfaceSize(const Size(360, 700));
        await tester.pumpAndSettle();
        final searchRect = tester.getRect(find.byType(DocumentHierarchySearch));
        final detailsRect = tester.getRect(find.byTooltip('Previous occurrence'));
        final showButtonRect = tester.getRect(find.byType(DocumentHierarchyShowButton));
        expect(searchRect.bottom, lessThanOrEqualTo(detailsRect.top));
        expect(showButtonRect.overlaps(tester.getRect(find.byType(TextField))), isFalse);
        expect(tester.takeException(), isNull);
        expectPreservedSearch();
        for (final width in [640.0, 900.0, 1100.0, 1400.0, 2200.0, 360.0]) {
          await tester.binding.setSurfaceSize(Size(width, 700));
          await tester.pumpAndSettle();
          final resizedSearch = tester.getRect(find.byType(DocumentHierarchySearch));
          final resizedDetails = tester.getRect(find.byTooltip('Previous occurrence'));
          final divider = tester.getRect(find.byKey(const ValueKey('preview-toolbar-divider')));
          expect(resizedSearch.width, lessThanOrEqualTo(360));
          expect(resizedSearch.bottom, lessThanOrEqualTo(resizedDetails.top));
          expect(resizedSearch.right, lessThanOrEqualTo(width));
          expect(divider.size, Size(width, 1));
          expect(divider.top, resizedSearch.bottom);
          expect(divider.bottom, lessThanOrEqualTo(resizedDetails.top));
          expect(
            tester.getSize(find.byKey(const ValueKey('preview-selected-element-details'))).width,
            width < 1000 ? width : 1000,
          );
          expectPreservedSearch();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(search.searchPhrase, isNull);
        expect(hierarchy.selectedElement, isNull);
        expect(find.byType(DocumentHierarchySearch), findsNothing);
        expect(find.byType(DocumentHierarchyLayout), findsNothing);
        expectToggleVisible(false);

        await controlShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.enterText(find.byType(TextField), 'no matching elements');
        await tester.pumpAndSettle();
        expect(search.searchResults, isEmpty);
        expect(find.byType(DocumentHierarchySearch), findsOneWidget);
        expectToggleVisible(true);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(of: find.byType(DocumentHierarchySearch), matching: find.byType(IconButton)).last,
        );
        await tester.pumpAndSettle();
        expect(search.searchPhrase, isNull);
        expect(application.showDocumentHierarchy, isFalse);
        expectToggleVisible(false);
        isPointerOverApplication.value = true;
        await tester.pumpAndSettle();
        expectToggleVisible(true);

        await tester.binding.setSurfaceSize(const Size(1000, 700));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byType(DocumentHierarchyShowButton), matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        await controlShortcut(tester, LogicalKeyboardKey.keyF);
        await tester.enterText(find.byType(TextField), 'needle');
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchyLayout), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(DocumentHierarchySearch), findsNothing);
        expect(find.byType(DocumentHierarchyLayout), findsOneWidget);
        expect(application.showDocumentHierarchy, isTrue);
        expect(hierarchy.selectedElement, same(matches.first));
        expect(tester.takeException(), isNull);
      }
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      container.dispose();
      isPointerOverApplication.value = false;
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  });
}
