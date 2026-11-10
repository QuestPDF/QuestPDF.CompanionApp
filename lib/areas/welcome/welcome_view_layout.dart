import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/font_awesome_icons.dart';
import '../../shared/questpdf_urls.dart';
import '../../theme/app_colors.dart';
import 'welcome_view_automatic_launch.dart';
import 'welcome_view_background.dart';
import 'welcome_view_connection_error.dart';
import 'welcome_view_button.dart';
import 'welcome_view_dot_pattern.dart';
import 'welcome_view_settings.dart';
import 'welcome_view_update.dart';
import 'welcome_view_version.dart';

class WelcomeViewLayout extends StatelessWidget {
  const WelcomeViewLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        const Positioned.fill(child: WelcomeViewBackground()),
        const Positioned.fill(child: RepaintBoundary(child: WelcomeViewDotPattern())),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Companion App",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 28,
                      fontWeight: isDark ? FontWeight.w500 : FontWeight.w600,
                      color: isDark ? null : const Color(0xFF1675FF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  buildMenuCard(context),
                  const SizedBox(height: 30),
                  const WelcomeViewVersion(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMenuCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? Colors.white.withAlpha(10) : Colors.white;

    return Card(
      color: cardColor,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appColors.border),
      ),
      child: Column(
        children: [
          WelcomeViewButton(
            label: "Quick Start",
            icon: FontAwesomeIcons.rocket,
            onClick: () => launchUrl(Uri.parse(QuestPdfUrls.companionUsage)),
          ),
          const Divider(),
          WelcomeViewButton(
            label: "App features",
            icon: FontAwesomeIcons.book,
            onClick: () => launchUrl(Uri.parse(QuestPdfUrls.companionFeatures)),
          ),
          const Divider(),
          WelcomeViewButton(
            label: "License",
            icon: FontAwesomeIcons.license,
            onClick: () => launchUrl(Uri.parse(QuestPdfUrls.pricing)),
          ),
          const Divider(),
          const WelcomeViewSettings(),
          const WelcomeViewConnectionError(),
          const WelcomeViewAutomaticLaunch(),
          const WelcomeViewUpdate(),
        ],
      ),
    );
  }
}
