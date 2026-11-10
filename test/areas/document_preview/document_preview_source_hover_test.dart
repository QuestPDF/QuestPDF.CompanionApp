import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/source_code_path.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_provider.dart';
import 'package:questpdf_companion/areas/document_preview/widgets/document_preview_element_details.dart';
import 'package:questpdf_companion/shared/font_awesome_icons.dart';
import 'package:questpdf_companion/shared/source_code_visualization.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

final class SourceFile implements File {
  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => 'var value = 1;';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a snippet closed by clearing the selection stays closed for the next selection', (tester) async {
    const outsideTheBar = Offset(400, 500);
    final hierarchy = documentHierarchyProviderInstance;
    final element = DocumentHierarchyElement(
      'TextBlock',
      null,
      null,
      true,
      [],
      [],
      [],
      SourceCodePath('/example/Test.cs', 1),
      [],
    );
    hierarchy.setSelectedElement(element);

    await IOOverrides.runZoned(() async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(
              body: Align(alignment: Alignment.topCenter, child: DocumentPreviewElementDetails()),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: outsideTheBar);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byIcon(FontAwesomeIcons.penLine)));
      await tester.pumpAndSettle();
      expect(find.byType(SourceCodeVisualization), findsOneWidget);

      // The bar disappears from under the pointer, e.g. after pressing Escape, so it never reports an exit.
      hierarchy.setSelectedElement(null);
      await tester.pumpAndSettle();
      await mouse.moveTo(outsideTheBar);
      hierarchy.setSelectedElement(element);
      await tester.pumpAndSettle();

      expect(find.byIcon(FontAwesomeIcons.penLine), findsOneWidget);
      expect(find.byType(SourceCodeVisualization), findsNothing);
    }, createFile: (_) => SourceFile());
  });
}
