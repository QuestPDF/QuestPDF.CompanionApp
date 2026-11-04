import 'dart:async';

import 'package:flutter/material.dart';
import 'package:process_run/process_run.dart';

import '../areas/application/state/application_state_provider.dart';

Future<void> openSourceCodePathInEditor(CodeEditor editor, String filePath, int lineNumber) async {
  if (filePath.isEmpty) return;

  final shell = Shell(throwOnError: true, runInShell: true);

  final command = switch (editor) {
    CodeEditor.rider => 'rider --line $lineNumber $filePath',
    CodeEditor.visualCode => 'code -g $filePath:$lineNumber',
    CodeEditor.visualStudio => 'start devenv /Command "Edit.Goto $lineNumber" $filePath',
  };

  await shell.run(command);
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
