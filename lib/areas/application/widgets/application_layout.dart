import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/keyboard_shortcuts.dart';
import '../../../shared/pointer_over_application.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../document_preview_with_hierarchy_view.dart';
import '../../generic_exception/widgets/generic_exception_view_layout.dart';
import '../../welcome/welcome_view_layout.dart';
import '../state/application_state_provider.dart';
import 'application_titlebar.dart';
import 'application_titlebar_window_gestures.dart';

class ApplicationLayout extends ConsumerWidget {
  const ApplicationLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentMode = ref.watch(applicationStateProvider.select((x) => x.currentMode));

    final currentView = switch (currentMode) {
      ApplicationMode.welcomeScreen => const WelcomeViewLayout(),
      ApplicationMode.documentPreview => const DocumentPreviewWithHierarchyView(),
      ApplicationMode.genericException => const GenericExceptionViewLayout(),
    };

    // the bottom border is painted over the bar, so the content keeps the full height
    final titlebar = ApplicationTitlebarWindowGestures(
      child: Container(
        height: AppSizes.barHeight,
        color: colors.chrome,
        foregroundDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: const ApplicationTitlebar(),
      ),
    );

    return MouseRegion(
      onEnter: (_) => isPointerOverApplication.value = true,
      onExit: (_) => isPointerOverApplication.value = false,
      child: Stack(
        children: [
          const KeyboardShortcuts(),
          Scaffold(
            backgroundColor: colors.canvas,
            body: Column(
              children: [
                titlebar,
                Expanded(child: currentView),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
