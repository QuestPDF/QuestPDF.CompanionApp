import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/generic_exception/generic_exception_view_state_provider.dart';
import 'package:questpdf_companion/areas/generic_exception/models/generic_exception_details.dart';
import 'package:questpdf_companion/areas/generic_exception/models/generic_exception_stack_frame.dart';
import 'package:questpdf_companion/areas/generic_exception/models/show_generic_exception_command.dart';
import 'package:questpdf_companion/areas/generic_exception/widgets/generic_exception_view_layout.dart';
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

void showException() {
  final stackTrace = [GenericExceptionStackFrame('MyApp.Program.Main()', '/app/Program.cs', 1)];
  final exception = GenericExceptionDetails('System.Exception', 'Boom', stackTrace, null);
  genericExceptionViewStateInstance.setException(ShowGenericExceptionCommand(exception));
}

void main() {
  testWidgets('a new exception reloads source even at the same file and line', (tester) async {
    var content = 'BEFORE_HOT_RELOAD';

    String? displayedSource() =>
        tester.state<SourceCodeVisualizationState>(find.byType(SourceCodeVisualization)).sourceCode;

    await IOOverrides.runZoned(() async {
      showException();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(body: GenericExceptionViewLayout()),
          ),
        ),
      );
      await tester.pump();
      expect(displayedSource(), content);

      // rebuilding the view for the same exception keeps the snippet as it was read
      content = 'AFTER_HOT_RELOAD';
      genericExceptionViewStateInstance.notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(displayedSource(), 'BEFORE_HOT_RELOAD');

      showException();
      await tester.pump();
      await tester.pump();
      expect(displayedSource(), content);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, createFile: (_) => SourceFile(content));
  });
}
