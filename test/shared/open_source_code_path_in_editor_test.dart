import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:process_run/process_run.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/shared/open_source_code_path_in_editor.dart';

void main() {
  test('Unix editor arguments preserve quotes and shell metacharacters literally', () async {
    const path = '''/tmp/Work/R&D \$literal %PATH% ! 'quote' "double".cs''';
    final command = buildSourceCodeEditorCommand(CodeEditor.visualCode, path, 27, isWindows: false);
    final directory = await Directory.systemTemp.createTemp('questpdf-editor-test-');
    addTearDown(() => directory.delete(recursive: true));
    final executable = File('${directory.path}/code');
    await executable.writeAsString('#!/bin/sh\nprintf \'%s\\n\' "\$@" > received.txt\n');
    final chmod = await Process.run('chmod', ['+x', executable.path]);
    expect(chmod.exitCode, 0);
    final shell = Shell(
      runInShell: false,
      verbose: false,
      workingDirectory: directory.path,
      environment: {...command.environment, 'PATH': '${directory.path}:${Platform.environment['PATH']}'},
    );
    await shell.runExecutableArguments(command.executable, command.arguments);
    expect(await File('${directory.path}/received.txt').readAsLines(), ['-g', '$path:27']);
  }, skip: Platform.isWindows);

  for (final editor in CodeEditor.values) {
    test('Windows $editor keeps quoted paths out of the process command line', () {
      const path = r'C:\Données\R&D\100%PATH% bang! (test)^name.cs';
      final command = buildSourceCodeEditorCommand(editor, path, 27, isWindows: true);
      expect(command.executable, 'cmd.exe');
      expect(command.arguments, ['/d', '/v:off', '/c', '%QUESTPDF_COMPANION_EDITOR_COMMAND%']);
      final script = command.environment['QUESTPDF_COMPANION_EDITOR_COMMAND']!;
      expect(script, contains('"$path${editor == CodeEditor.visualCode ? ':27' : ''}"'));
      expect(script.startsWith('start "" '), editor == CodeEditor.visualStudio);
    });
  }

  for (final invalidPath in ['bad"path.cs', 'bad\rpath.cs', 'bad\npath.cs', 'bad\x00path.cs']) {
    test('Windows rejects a path that can escape its quotes: ${invalidPath.codeUnits}', () {
      expect(
        () => buildSourceCodeEditorCommand(CodeEditor.visualCode, invalidPath, 1, isWindows: true),
        throwsArgumentError,
      );
    });
  }

  test('Windows batch launchers receive literal metacharacters and Unicode paths', () async {
    final directory = await Directory.systemTemp.createTemp('questpdf-editor-test-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/code.cmd').writeAsString(
      '@echo off\r\nsetlocal DisableDelayedExpansion\r\nchcp 65001>nul\r\nset "received=%~2"\r\nset received>received.txt\r\n',
    );
    for (final path in [r'C:\Work\R&D\Report.cs', r'C:\Données\100%PATH% bang! (test)^name.cs']) {
      final command = buildSourceCodeEditorCommand(CodeEditor.visualCode, path, 27, isWindows: true);
      final shell = Shell(
        runInShell: false,
        verbose: false,
        workingDirectory: directory.path,
        environment: {...command.environment, 'PATH': '${directory.path};${Platform.environment['PATH']}'},
      );
      await shell.runExecutableArguments(command.executable, command.arguments);
      expect((await File('${directory.path}/received.txt').readAsString()).trim(), 'received=$path:27');
    }
  }, skip: !Platform.isWindows);
}
