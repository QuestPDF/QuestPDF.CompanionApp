import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/questpdf_urls.dart';
import '../../../theme/app_colors.dart';
import '../state/application_version_state.dart';
import 'application_titlebar_card.dart';

class ApplicationTitlebarUpdateAvailable extends ConsumerWidget {
  final bool showLabel;

  const ApplicationTitlebarUpdateAvailable({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationVersion = ref.watch(applicationVersionProvider);

    if (!applicationVersion.isUpdateAvailable) return const SizedBox.shrink();

    final currentVersion = applicationVersion.currentApplicationVersion!.text;
    final latestVersion = applicationVersion.latestApplicationVersion!.text;

    return ApplicationTitlebarCard(
      showLabel: showLabel,
      icon: FontAwesomeIcons.arrowsRotate,
      tone: StatusTone.info,
      label: "Update",
      title: "Update Available",
      content: [
        "Please consider updating the application to receive the latest features and improvements.",
        "$currentVersion → $latestVersion",
      ],
      action: const ApplicationTitlebarCardAction(label: "Download", url: QuestPdfUrls.companionDownload),
    );
  }
}
