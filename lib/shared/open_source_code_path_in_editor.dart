import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';

import '../areas/application/state/application_state_provider.dart';

Future<void> openSourceCodePathInEditor(CodeEditor editor, String filePath, int lineNumber) async {
  if (filePath.isEmpty) return;

  final command = buildSourceCodeEditorCommand(editor, filePath, lineNumber, isWindows: Platform.isWindows);
  final shell = Shell(throwOnError: true, runInShell: false, environment: command.environment);
  await shell.runExecutableArguments(command.executable, command.arguments);
}

@visibleForTesting
({String executable, List<String> arguments, Map<String, String> environment}) buildSourceCodeEditorCommand(
  CodeEditor editor,
  String filePath,
  int lineNumber, {
  required bool isWindows,
}) {
  final (executable, arguments) = switch (editor) {
    CodeEditor.rider => ('rider', ['--line', '$lineNumber', filePath]),
    CodeEditor.visualCode => ('code', ['-g', '$filePath:$lineNumber']),
    CodeEditor.visualStudio => ('devenv', ['/Command', 'Edit.Goto $lineNumber', filePath]),
  };

  if (!isWindows) return (executable: executable, arguments: arguments, environment: {});

  // These characters cannot occur in a Windows file path and could break its quotes.
  if (filePath.contains(RegExp('["\\r\\n\\x00]'))) {
    throw ArgumentError.value(filePath, 'filePath', 'Invalid Windows source file path');
  }

  final editorCommand = '$executable ${arguments.map((argument) => '"$argument"').join(' ')}';
  final command = editor == CodeEditor.visualStudio ? 'start "" $editorCommand' : editorCommand;

  // Windows editor launchers can be .cmd files. Expand one environment variable
  // inside cmd so Dart does not re-escape its quotes, and literal percent signs
  // in the path are not expanded again. Disable AutoRun and delayed ! expansion.
  const commandVariable = 'QUESTPDF_COMPANION_EDITOR_COMMAND';
  return (
    executable: 'cmd.exe',
    arguments: ['/d', '/v:off', '/c', '%$commandVariable%'],
    environment: {commandVariable: command},
  );
}

Future<void> tryOpenSourceCodePathInEditor(
  BuildContext context,
  CodeEditor editor,
  String filePath,
  int lineNumber,
) async {
  try {
    await openSourceCodePathInEditor(editor, filePath, lineNumber);
  } catch (e) {
    if (!context.mounted) return;

    final theme = Theme.of(context);

    final message =
        "Unable to open the source code in ${getEditorName(editor)}. "
        "Please ensure that the editor is installed correctly and can be launched from the command line (it is added to the PATH environment variable). "
        "Alternatively, you can change the default editor on the welcome screen.";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: theme.colorScheme.error,
        content: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onError)),
      ),
    );
  }
}

String getEditorName(CodeEditor editor) {
  return switch (editor) {
    CodeEditor.rider => 'Rider',
    CodeEditor.visualCode => 'VS Code',
    CodeEditor.visualStudio => 'Visual Studio',
  };
}
