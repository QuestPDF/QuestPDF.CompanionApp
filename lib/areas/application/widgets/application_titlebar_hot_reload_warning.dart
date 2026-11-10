import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../theme/app_colors.dart';
import '../state/application_state_provider.dart';
import 'application_titlebar_card.dart';

class ApplicationTitlebarHotReloadWarning extends ConsumerWidget {
  const ApplicationTitlebarHotReloadWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDocumentHotReloaded = ref.watch(applicationStateProvider.select((x) => x.isDocumentHotReloaded));

    if (!isDocumentHotReloaded) return const SizedBox.shrink();

    return const ApplicationTitlebarCard(
      icon: FontAwesomeIcons.hotReload,
      tone: StatusTone.warning,
      label: "Hot reload",
      title: "Code navigation degraded",
      content: [
        "The document was refreshed with hot reload. Hot reload limits how accurately the library can record where each element was created, so jumping from the preview to the source code may land on the wrong line.",
        "To restore precise navigation, run the project with hot reload disabled:",
      ],
      code: "dotnet watch --no-hot-reload",
    );
  }
}
