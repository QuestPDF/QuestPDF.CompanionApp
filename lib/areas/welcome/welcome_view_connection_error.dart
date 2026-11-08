import 'package:flutter/material.dart';

import '../../communication_service.dart';
import '../../shared/font_awesome_icons.dart';
import '../../theme/app_colors.dart';
import 'welcome_view_button.dart';

class WelcomeViewConnectionError extends StatelessWidget {
  const WelcomeViewConnectionError({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: communicationServiceInstance.failedPort,
      builder: (context, port, _) {
        if (port == null) return const SizedBox.shrink();

        return Column(
          children: [
            const Divider(),
            Padding(
              padding: WelcomeViewButton.contentPadding,
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.linkHorizontal,
                    size: WelcomeViewButton.iconSize,
                    color: context.appColors.error,
                  ),
                  const SizedBox(width: WelcomeViewButton.iconSpacing),
                  Expanded(
                    child: Text(
                      'Port $port is unavailable. Retrying automatically. Change it in Settings.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 14, color: context.appColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
