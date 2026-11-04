import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/font_awesome_icons.dart';
import '../../shared/questpdf_urls.dart';
import '../../theme/app_colors.dart';
import 'welcome_view_automatic_launch.dart';
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
    final colors = context.appColors;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(child: buildBackgroundGlow(context)),
        Positioned.fill(child: buildBackgroundGrain(context)),
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
                      fontSize: 24,
                      fontWeight: isDark ? FontWeight.w500 : FontWeight.w600,
                      color: isDark ? null : colors.info,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
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

  Widget buildBackgroundGlow(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glowColor = isDark ? const Color(0xFF2D64BE) : colors.info;
    final glowAlphas = isDark ? const [56, 24, 9, 0] : const [28, 12, 4, 0];

    return ColoredBox(
      color: colors.chrome,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // the glow sits in the bottom left corner, opposite the dot pattern
          gradient: RadialGradient(
            center: Alignment.bottomLeft,
            radius: 1.1,
            colors: glowAlphas.map(glowColor.withAlpha).toList(),
            stops: const [0.0, 0.4, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  // the grain tile of the QuestPDF website keeps the glow from banding
  Widget buildBackgroundGrain(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/grain.png'),
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          filterQuality: FilterQuality.none,
          opacity: isDark ? 0.5 : 0.25,
        ),
      ),
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
          const WelcomeViewAutomaticLaunch(),
          const WelcomeViewUpdate(),
        ],
      ),
    );
  }
}
