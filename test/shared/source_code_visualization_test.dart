import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/shared/source_code_visualization.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

final class PendingSourceFile implements File {
  final Future<String> contents;
  PendingSourceFile(this.contents);

  @override
  Future<String> readAsString({Encoding encoding = utf8}) => contents;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget snippet(String path) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: Scaffold(
    body: SourceCodeVisualization(
      filePath: path,
      highlightLineNumber: 1,
      showLinesBuffer: 1,
      backgroundColor: Colors.white,
      highlightColor: Colors.red,
    ),
  ),
);

SourceCodeVisualizationState sourceState(WidgetTester tester) =>
    tester.state<SourceCodeVisualizationState>(find.byType(SourceCodeVisualization));

void main() {
  testWidgets('a slow read of the previous file does not replace the current one', (tester) async {
    final first = Completer<String>();
    final second = Completer<String>();
    await IOOverrides.runZoned(() async {
      await tester.pumpWidget(snippet('first.cs'));
      await tester.pumpWidget(snippet('second.cs'));
      second.complete('SECOND_FILE');
      await tester.pump();
      expect(sourceState(tester).sourceCode, 'SECOND_FILE');

      first.complete('FIRST_FILE');
      await tester.pump();
      expect(sourceState(tester).sourceCode, 'SECOND_FILE');
    }, createFile: (path) => PendingSourceFile(path == 'first.cs' ? first.future : second.future));
  });

  testWidgets('a new path replaces the displayed source', (tester) async {
    final first = Completer<String>();
    final second = Completer<String>();
    await IOOverrides.runZoned(() async {
      await tester.pumpWidget(snippet('first.cs'));
      first.complete('FIRST_FILE');
      await tester.pump();
      expect(sourceState(tester).sourceCode, 'FIRST_FILE');

      await tester.pumpWidget(snippet('second.cs'));
      expect(sourceState(tester).sourceCode, isNull);
      second.complete('SECOND_FILE');
      await tester.pump();
      expect(sourceState(tester).sourceCode, 'SECOND_FILE');
    }, createFile: (path) => PendingSourceFile(path == 'first.cs' ? first.future : second.future));
  });

  testWidgets('a failed file does not prevent loading a different file', (tester) async {
    final first = Completer<String>();
    final second = Completer<String>();
    await IOOverrides.runZoned(() async {
      await tester.pumpWidget(snippet('missing.cs'));
      first.completeError(const FileSystemException('missing'));
      await tester.pump();
      expect(find.textContaining('Cannot load source code'), findsOneWidget);

      await tester.pumpWidget(snippet('found.cs'));
      expect(sourceState(tester).hasLoadingFailed, isFalse);
      second.complete('FOUND_FILE');
      await tester.pump();
      expect(sourceState(tester).sourceCode, 'FOUND_FILE');
      expect(find.textContaining('Cannot load source code'), findsNothing);
    }, createFile: (path) => PendingSourceFile(path == 'missing.cs' ? first.future : second.future));
  });

  testWidgets('completing a read after unmount is safe', (tester) async {
    final pending = Completer<String>();
    await IOOverrides.runZoned(() async {
      await tester.pumpWidget(snippet('file.cs'));
      await tester.pumpWidget(const SizedBox());
      pending.complete('SOURCE');
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, createFile: (_) => PendingSourceFile(pending.future));
  });
}
