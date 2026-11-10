import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../theme/app_theme.dart';
import '../state/application_state_provider.dart';
import 'application_titlebar_hot_reload_warning.dart';
import 'application_titlebar_license.dart';
import 'application_titlebar_logo.dart';
import 'application_titlebar_update_available.dart';
import 'application_titlebar_window_buttons.dart';

class ApplicationTitlebar extends ConsumerStatefulWidget {
  const ApplicationTitlebar({super.key});

  @override
  ConsumerState<ApplicationTitlebar> createState() => _ApplicationTitlebarState();
}

class _ApplicationTitlebarState extends ConsumerState<ApplicationTitlebar> with WindowListener {
  // macOS hides its native window buttons in full screen, so the bar should not leave room for them
  bool isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isFullScreen().then(_setFullScreen);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() => _setFullScreen(true);

  @override
  void onWindowLeaveFullScreen() => _setFullScreen(false);

  void _setFullScreen(bool value) {
    if (!mounted || isFullScreen == value) return;
    setState(() => isFullScreen = value);
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(applicationStateProvider.select((x) => x.currentMode));
    final usesNativeWindowButtons = defaultTargetPlatform == TargetPlatform.macOS;

    // leaves room for the native window buttons on macOS
    final leadingInset = usesNativeWindowButtons && !isFullScreen ? 90.0 : 12.0;

    final trailing = usesNativeWindowButtons
        ? const [SizedBox(width: 16)]
        : const [SizedBox(width: 12), ApplicationTitlebarWindowButtons()];

    return Row(
      children: [
        SizedBox(width: leadingInset),
        const ApplicationTitlebarLogo(),
        // pills are right-aligned; those that do not fit wrap into a clipped second row and disappear
        Expanded(
          child: ClipRect(
            child: SizedBox(
              height: AppSizes.barHeight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: AppSizes.barHeight,
                children: [
                  // the welcome screen lists an available update in its own menu
                  if (currentMode != ApplicationMode.welcomeScreen) ...const [
                    ApplicationTitlebarHotReloadWarning(),
                    ApplicationTitlebarLicense(),
                    ApplicationTitlebarUpdateAvailable(),
                  ],
                ],
              ),
            ),
          ),
        ),
        ...trailing,
      ],
    );
  }
}
