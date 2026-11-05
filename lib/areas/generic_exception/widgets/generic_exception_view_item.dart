import 'package:flutter/material.dart';

import '../../../shared/emboldened_icon.dart';
import '../../../shared/font_awesome_icons.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../models/dotnet_stack_frame_signature.dart';
import '../models/generic_exception_stack_frame.dart';
import 'generic_exception_stack_frame_preview.dart';

class GenericExceptionViewItem extends StatelessWidget {
  static const _libraryNamespaces = ['QuestPDF', 'System', 'Microsoft'];

  const GenericExceptionViewItem({super.key, required this.type, required this.message, required this.stackTrace});

  final String type;
  final String message;
  final List<GenericExceptionStackFrame> stackTrace;

  static bool _isLibraryNamespace(String namespace) {
    return _libraryNamespaces.any((library) => namespace == library || namespace.startsWith('$library.'));
  }

  static bool _isUserCode(GenericExceptionStackFrame frame) {
    return frame.hasSourceCode && !_isLibraryNamespace(DotnetStackFrameSignature.parse(frame.codeLocation).namespace);
  }

  @override
  Widget build(BuildContext context) {
    // the first frame in user code opens by default;
    // QuestPDF frames may carry source too when the library is built from source
    final expandedFrame =
        stackTrace.where(_isUserCode).firstOrNull ?? stackTrace.where((x) => x.hasSourceCode).firstOrNull;

    return Card(
      color: context.appColors.chrome,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildHeader(context),
          ...stackTrace.map((x) => GenericExceptionStackFramePreview(stackFrame: x, isExpanded: x == expandedFrame)),
        ],
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final messageStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colors.error);
    final typeStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: codeFontFamily,
      color: Color.lerp(colors.textPrimary, colors.error, 0.35),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          EmboldenedIcon(icon: FontAwesomeIcons.bug, color: colors.error, size: 24, strokeWidth: 1),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: typeStyle),
                const SizedBox(height: 4),
                Text(message, style: messageStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
