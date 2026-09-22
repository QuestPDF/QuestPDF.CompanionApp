import 'package:flutter/material.dart';

import '../../../shared/macos_command_line_alias_installer.dart';
import '../../../shared/font_awesome_icons.dart';
import 'application_titlebar_card.dart';

class ApplicationTitlebarMacOsAutomaticLaunch extends StatefulWidget {
  const ApplicationTitlebarMacOsAutomaticLaunch({super.key});

  @override
  State<ApplicationTitlebarMacOsAutomaticLaunch> createState() => _ApplicationTitlebarMacOsAutomaticLaunchState();
}

class _ApplicationTitlebarMacOsAutomaticLaunchState extends State<ApplicationTitlebarMacOsAutomaticLaunch> {
  bool? _isInstalled;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    if (MacOsCommandLineAliasInstaller.isSupported) _refreshInstallationStatus();
  }

  Future<void> _refreshInstallationStatus() async {
    final isInstalled = await MacOsCommandLineAliasInstaller.isInstalled();
    if (!mounted) return;
    setState(() => _isInstalled = isInstalled);
  }

  Future<void> _install() async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    setState(() => _isBusy = true);

    void showMessage(String message, {bool isError = false}) {
      final textColor = isError ? theme.colorScheme.onError : theme.colorScheme.onPrimary;
      final backgroundColor = isError ? theme.colorScheme.error : theme.colorScheme.primary;
      final textStyle = theme.textTheme.bodySmall?.copyWith(color: textColor);

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Text(message, style: textStyle),
        ),
      );
    }

    try {
      await MacOsCommandLineAliasInstaller.install();
      showMessage("Automatic launch is enabled. The ShowInCompanion method can now start this application.");
    } on MacOsCommandLineAliasCancelledException {
      // The administrator prompt was dismissed, so nothing changed.
    } catch (e) {
      showMessage(
        "Automatic launch could not be enabled. "
        "Administrator privileges are required to write to /usr/local/bin.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
      await _refreshInstallationStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInstalled = _isInstalled ?? false;

    return ApplicationTitlebarCard(
      isVisible: MacOsCommandLineAliasInstaller.isSupported && !isInstalled,
      width: 350,
      icon: FontAwesomeIcons.automaticLaunch,
      emphasized: true,
      emphasisColor: Colors.orange,
      title: "Automatic Application Launch",
      content: [
        "The ShowInCompanion method can launch this application automatically.",
        "To enable this integration, the installer requires administrator privileges.",
      ],
      actions: [
        if (isInstalled == false)
          ApplicationTitlebarCardAction(label: "Install", onPressed: _isBusy ? null : _install),
      ],
      onClicked: () {},
    );
  }
}
