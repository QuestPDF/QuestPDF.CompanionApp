import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Reads the file when it is created and whenever [filePath] changes.
/// A file edited on disk is read again only by a new instance.
class SourceCodeVisualization extends StatefulWidget {
  final String filePath;
  final int highlightLineNumber;
  final int showLinesBuffer;
  final Color backgroundColor;
  final Color highlightColor;

  const SourceCodeVisualization({
    super.key,
    required this.filePath,
    required this.highlightLineNumber,
    required this.showLinesBuffer,
    required this.backgroundColor,
    required this.highlightColor,
  });

  @override
  State<SourceCodeVisualization> createState() => SourceCodeVisualizationState();
}

class SourceCodeVisualizationState extends State<SourceCodeVisualization> {
  String? sourceCode;
  bool hasLoadingFailed = false;

  @override
  void initState() {
    super.initState();
    loadSourceCode();
  }

  @override
  void didUpdateWidget(SourceCodeVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.filePath == widget.filePath) return;

    sourceCode = null;
    hasLoadingFailed = false;
    loadSourceCode();
  }

  Future<void> loadSourceCode() async {
    final filePath = widget.filePath;
    String? fileContent;

    try {
      fileContent = await File(filePath).readAsString();
    } catch (e) {
      // reported below as a loading failure
    }

    // another file may have been requested while this one was being read
    if (!mounted || filePath != widget.filePath) return;

    setState(() {
      sourceCode = fileContent;
      hasLoadingFailed = fileContent == null;
    });
  }

  BoxDecoration buildBlockDecoration() {
    return BoxDecoration(
      color: widget.backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: context.appColors.border),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hasLoadingFailed) return buildFailureMessage();

    return buildPreview();
  }

  Widget buildFailureMessage() {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary);

    return Container(
      decoration: buildBlockDecoration(),
      padding: const EdgeInsets.all(12),
      child: Text('Cannot load source code from ${widget.filePath}', style: textStyle),
    );
  }

  Widget buildPreview() {
    // until the file is loaded, blank lines keep the block at its final height
    final lines = sourceCode?.split('\n') ?? List.filled(widget.highlightLineNumber + widget.showLinesBuffer, '');

    final lineNumberBegin = (widget.highlightLineNumber - widget.showLinesBuffer).clamp(1, lines.length);
    final lineNumberEnd = (widget.highlightLineNumber + widget.showLinesBuffer).clamp(1, lines.length);

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;

    final theme = Map<String, TextStyle>.from(isDarkTheme ? atomOneDarkTheme : atomOneLightTheme);
    theme["root"] = TextStyle(color: theme["root"]!.color, backgroundColor: Colors.transparent);

    Widget buildCodeLine(int lineNumber) {
      final isHighlighted = lineNumber == widget.highlightLineNumber;
      const codeStyle = TextStyle(fontFamily: codeFontFamily, fontSize: 14, height: 1.5);
      final lineNumberColor = isHighlighted ? colors.textSecondary : colors.textMuted;

      return Container(
        decoration: BoxDecoration(
          color: isHighlighted ? widget.highlightColor.withAlpha(36) : Colors.transparent,
          border: Border(left: BorderSide(color: isHighlighted ? widget.highlightColor : Colors.transparent, width: 2)),
        ),
        padding: const EdgeInsets.only(left: 10, right: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                lineNumber.toString(),
                textAlign: TextAlign.right,
                style: codeStyle.copyWith(color: lineNumberColor),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: sourceCode == null ? 600 : null,
              child: HighlightView(lines[lineNumber - 1], language: 'cs', theme: theme, textStyle: codeStyle),
            ),
          ],
        ),
      );
    }

    final codeLines = [for (var line = lineNumberBegin; line <= lineNumberEnd; line++) buildCodeLine(line)];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: buildBlockDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      // lines are at least as wide as the block, so the highlighted line spans its full width
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: codeLines),
            ),
          ),
        ),
      ),
    );
  }
}
