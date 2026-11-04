import 'package:flutter/material.dart';

import '../../shared/font_awesome_icons.dart';
import '../../shared/macos_command_line_alias_installer.dart';
import '../../theme/app_colors.dart';
import 'welcome_view_button.dart';

// offered only on macOS, until the launcher script is installed
class WelcomeViewAutomaticLaunch extends StatefulWidget {
  const WelcomeViewAutomaticLaunch({super.key});

  @override
  State<WelcomeViewAutomaticLaunch> createState() => _WelcomeViewAutomaticLaunchState();
}

class _WelcomeViewAutomaticLaunchState extends State<WelcomeViewAutomaticLaunch> {
  // null until checked, so the row does not flash in before the check completes
  bool? isInstalled;
  bool isInstalling = false;

  @override
  void initState() {
    super.initState();
    if (MacOsCommandLineAliasInstaller.isSupported) refreshStatus();
  }

  Future<void> refreshStatus() async {
    final result = await MacOsCommandLineAliasInstaller.isInstalled();
    if (!mounted) return;
    setState(() => isInstalled = result);
  }

  Future<void> install() async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    setState(() => isInstalling = true);

    void showMessage(String message, {bool isError = false}) {
      final textColor = isError ? theme.colorScheme.onError : theme.colorScheme.onPrimary;
      final backgroundColor = isError ? theme.colorScheme.error : theme.colorScheme.primary;

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: textColor)),
        ),
      );
    }

    try {
      await MacOsCommandLineAliasInstaller.install();
      showMessage("Automatic launch is enabled. The ShowInCompanion method can now start this application.");
    } on MacOsCommandLineAliasCancelledException {
      // the administrator prompt was dismissed, so nothing changed
    } catch (e) {
      showMessage(
        "Automatic launch could not be enabled. "
        "Administrator privileges are required to write to /usr/local/bin.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => isInstalling = false);
      await refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInstalled != false) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(),
        Tooltip(
          message:
              "Lets the ShowInCompanion method start this application.\n"
              "Installing requires administrator privileges.",
          child: WelcomeViewButton(
            icon: FontAwesomeIcons.bolt,
            label: isInstalling ? "Enabling automatic launch…" : "Enable automatic launch",
            trailingIcon: null,
            tone: StatusTone.caution,
            onClick: isInstalling ? () {} : install,
          ),
        ),
      ],
    );
  }
}
