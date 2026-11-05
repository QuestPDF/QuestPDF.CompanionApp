import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/shared/tree_view/tree_view.dart';
import 'package:questpdf_companion/shared/tree_view/tree_view_model.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

TreeViewModel<String> node(
  String label, {
  required String hint,
  bool isHintImportant = false,
  bool isSelected = false,
  List<TreeViewModel<String>> children = const [],
}) {
  return TreeViewModel<String>(
    label: label,
    hint: hint,
    isHintImportant: isHintImportant,
    isHighlighted: false,
    isDimmed: (_) => false,
    isSelected: isSelected,
    isExpanded: true,
    isSingleChildContainer: false,
    children: children,
    content: label,
    notifier: null,
  );
}

Future<void> pumpTree(WidgetTester tester, TreeViewModel<String> root, {String? selected}) async {
  root.updateHierarchy();

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: Scaffold(
          body: TreeView<String>(rootNode: root, selectedElementContent: selected),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  const documentHint = "DocumentStructure / Document";
  const headerHint = "DocumentStructure / Header";
  const textHint = "Lorem ipsum";

  TreeViewModel<String> buildRoot({bool selectHeader = false}) {
    return node(
      "Document",
      hint: documentHint,
      children: [
        node("Header", hint: headerHint, isSelected: selectHeader),
        node("Text", hint: textHint, isHintImportant: true),
      ],
    );
  }

  testWidgets("hints of ordinary elements follow the pointer and hide again when it leaves", (tester) async {
    await pumpTree(tester, buildRoot());

    expect(find.text(documentHint), findsNothing);
    expect(find.text(headerHint), findsNothing);
    expect(find.text(textHint), findsOneWidget);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);

    // the tree schedules zero-delay futures on every build, which the test clock only runs when it advances,
    // so every pointer move is followed by pumpAndSettle
    await tester.pumpAndSettle();

    await pointer.moveTo(tester.getCenter(find.text("Document")));
    await tester.pumpAndSettle();

    expect(find.text(documentHint), findsOneWidget);
    expect(find.text(headerHint), findsNothing);

    await pointer.moveTo(tester.getCenter(find.text("Header")));
    await tester.pumpAndSettle();

    expect(find.text(documentHint), findsNothing);
    expect(find.text(headerHint), findsOneWidget);

    await pointer.moveTo(const Offset(400, 590));
    await tester.pumpAndSettle();

    expect(find.text(documentHint), findsNothing);
    expect(find.text(headerHint), findsNothing);
    expect(find.text(textHint), findsOneWidget);
  });

  testWidgets("the selected element shows its hint without hover", (tester) async {
    await pumpTree(tester, buildRoot(selectHeader: true), selected: "Header");

    expect(find.text(documentHint), findsNothing);
    expect(find.text(headerHint), findsOneWidget);
    expect(find.text(textHint), findsOneWidget);
  });
}
