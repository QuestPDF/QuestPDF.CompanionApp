import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/open_source_code_path_in_editor.dart';
import '../../../shared/source_code_visualization.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../application/state/application_state_provider.dart';
import '../models/dotnet_stack_frame_signature.dart';
import '../models/generic_exception_stack_frame.dart';

class GenericExceptionStackFramePreview extends ConsumerStatefulWidget {
  const GenericExceptionStackFramePreview({super.key, required this.stackFrame, required this.isExpanded});

  final GenericExceptionStackFrame stackFrame;
  final bool isExpanded;

  @override
  ConsumerState<GenericExceptionStackFramePreview> createState() => GenericExceptionStackFramePreviewState();
}

class GenericExceptionStackFramePreviewState extends ConsumerState<GenericExceptionStackFramePreview> {
  static const headerHeight = 56.0;

  late bool isExpanded = widget.isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;
    final editor = ref.watch(applicationStateProvider.select((x) => x.defaultCodeEditor));

    final stackFrame = widget.stackFrame;
    final signature = DotnetStackFrameSignature.parse(stackFrame.codeLocation);

    final canExpand = stackFrame.hasSourceCode || signature.origin != null;

    final baseStyle = theme.textTheme.bodyLarge!;
    final namespaceStyle = baseStyle.copyWith(color: colors.textMuted);
    final typeStyle = baseStyle.copyWith(color: colors.textPrimary);
    final methodStyle = baseStyle.copyWith(color: colors.highlight, fontWeight: FontWeight.w600);
    final detailStyle = theme.textTheme.bodyMedium!.copyWith(color: colors.textSecondary);

    Widget buildSignature() {
      return Text.rich(
        TextSpan(
          children: [
            if (signature.namespace.isNotEmpty) TextSpan(text: '${signature.namespace}.', style: namespaceStyle),
            if (signature.typeName.isNotEmpty) TextSpan(text: '${signature.typeName}.', style: typeStyle),
            TextSpan(text: signature.methodName, style: methodStyle),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    Widget buildHeader() {
      // the minimum height keeps rows with and without the chevron even
      return InkWell(
        onTap: canExpand ? () => setState(() => isExpanded = !isExpanded) : null,
        hoverColor: colors.accent.withAlpha(isDark ? 32 : 20),
        child: Container(
          constraints: const BoxConstraints(minHeight: headerHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(child: buildSignature()),
              if (canExpand)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(
                    isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
                    size: 14,
                    color: colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget buildFilePath() {
      final filePath = stackFrame.fileName!;

      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: path.dirname(filePath) + path.separator, style: detailStyle),
            TextSpan(
              text: '${path.basename(filePath)}:${stackFrame.lineNumber}',
              style: detailStyle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    Widget buildSourceCodeSnippet() {
      final filePath = stackFrame.fileName!;
      final lineNumber = stackFrame.lineNumber!;

      final snippet = SourceCodeVisualization(
        filePath: filePath,
        highlightLineNumber: lineNumber,
        showLinesBuffer: 9,
        backgroundColor: colors.fill,
        highlightColor: colors.error,
      );

      // the shadow lifts the button off the code lines running underneath
      final openInEditorButton = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(isDark ? 96 : 32), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: FilledButton.icon(
          icon: const Icon(FontAwesomeIcons.externalLink, size: 14),
          label: Text('Open in ${getEditorName(editor)}'),
          onPressed: () => tryOpenSourceCodePathInEditor(context, editor, filePath, lineNumber),
        ),
      );

      return Stack(
        children: [
          snippet,
          Positioned(right: 12, bottom: 12, child: openInEditorButton),
        ],
      );
    }

    Widget buildDetails() {
      if (!isExpanded || !canExpand) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            if (signature.origin != null) Text(signature.origin!, style: detailStyle),
            if (stackFrame.hasSourceCode) buildFilePath(),
            if (stackFrame.hasSourceCode) buildSourceCodeSnippet(),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buildHeader(), buildDetails()]),
    );
  }
}
