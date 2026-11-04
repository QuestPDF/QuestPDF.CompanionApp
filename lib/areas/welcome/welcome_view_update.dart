import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/font_awesome_icons.dart';
import '../../shared/questpdf_urls.dart';
import '../../theme/app_colors.dart';
import '../application/state/application_version_state.dart';
import 'welcome_view_button.dart';

class WelcomeViewUpdate extends ConsumerWidget {
  const WelcomeViewUpdate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationVersion = ref.watch(applicationVersionProvider);

    if (!applicationVersion.isUpdateAvailable) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(),
        WelcomeViewButton(
          icon: FontAwesomeIcons.arrowsRotate,
          label: "Update to ${applicationVersion.latestApplicationVersion!.text}",
          tone: StatusTone.info,
          onClick: () => launchUrl(Uri.parse(QuestPdfUrls.companionDownload)),
        ),
      ],
    );
  }
}
