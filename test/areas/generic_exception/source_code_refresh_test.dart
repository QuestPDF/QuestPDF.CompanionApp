import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/generic_exception/models/generic_exception_stack_frame.dart';
import 'package:questpdf_companion/areas/generic_exception/widgets/generic_exception_view_item.dart';
import 'package:questpdf_companion/shared/source_code_visualization.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

final class SourceFile implements File {
  final String content;
  SourceFile(this.content);

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async => content;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a new exception reloads source even at the same file and line', (tester) async {
    var content = 'BEFORE_HOT_RELOAD';
    Widget exception() => ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GenericExceptionViewItem(
              type: 'System.Exception',
              message: 'Boom',
              stackTrace: [GenericExceptionStackFrame('MyApp.Program.Main()', '/app/Program.cs', 1)],
            ),
          ),
        ),
      ),
    );

    await IOOverrides.runZoned(() async {
      await tester.pumpWidget(exception());
      await tester.pump();
      expect(tester.state<SourceCodeVisualizationState>(find.byType(SourceCodeVisualization)).sourceCode, content);
      content = 'AFTER_HOT_RELOAD';
      await tester.pumpWidget(exception());
      await tester.pump();
      expect(tester.state<SourceCodeVisualizationState>(find.byType(SourceCodeVisualization)).sourceCode, content);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, createFile: (_) => SourceFile(content));
  });
}
