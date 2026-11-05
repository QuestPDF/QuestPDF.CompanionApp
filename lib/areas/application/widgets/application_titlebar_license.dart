import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/questpdf_urls.dart';
import '../models/license_details.dart';
import '../state/application_state_provider.dart';
import 'application_titlebar_card.dart';

class ApplicationTitlebarLicense extends ConsumerWidget {
  const ApplicationTitlebarLicense({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLicense = ref.watch(applicationStateProvider.select((x) => x.currentLicense));

    if (currentLicense == null) return const SizedBox.shrink();

    final licenseDetails = LicenseDetails.of(currentLicense);

    return ApplicationTitlebarCard(
      icon: FontAwesomeIcons.license,
      tone: licenseDetails.tone,
      label: licenseDetails.title,
      title: "Your License: ${licenseDetails.title}",
      content: [licenseDetails.description],
      action: const ApplicationTitlebarCardAction(label: "Details", url: QuestPdfUrls.pricing),
    );
  }
}
