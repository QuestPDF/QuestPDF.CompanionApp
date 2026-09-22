import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

class MacOsCommandLineAliasInstaller {
  static const name = 'questpdf-companion';
  static const _path = '/usr/local/bin/$name';

  static bool get isSupported => Platform.isMacOS;

  static Future<bool> isInstalled() => File(_path).exists();

  static Future<void> install() async {
    if (!isSupported) return;

    final script = "#!/bin/sh\nexec ${await _buildLaunchCommand()}\n";
    final stagingDirectory = await Directory.systemTemp.createTemp('questpdf_companion_alias');

    try {
      final stagedFile = File('${stagingDirectory.path}/$name');
      await stagedFile.writeAsString(script);

      final command = "mkdir -p '/usr/local/bin' && cp '${stagedFile.path}' '$_path' && chmod 755 '$_path'";
      await _runWithAdministratorPrivileges(command);
    } finally {
      await stagingDirectory.delete(recursive: true);
    }
  }

  static Future<void> uninstall() async {
    if (!isSupported) return;

    await _runWithAdministratorPrivileges("rm -f '$_path'");
  }

  static Future<String> _buildLaunchCommand() async {
    final bundleId = (await PackageInfo.fromPlatform()).packageName;

    if (bundleId.isNotEmpty) return "open -b '$bundleId' --args \"\$@\"";

    final bundlePath = Platform.resolvedExecutable.split('/Contents/MacOS/').first;
    return "open -a '$bundlePath' --args \"\$@\"";
  }

  static Future<void> _runWithAdministratorPrivileges(String command) async {
    final escapedCommand = command.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

    final result = await Process.run('osascript', [
      '-e',
      'do shell script "$escapedCommand" with administrator privileges',
    ]);

    if (result.exitCode == 0) return;

    if (result.stderr.toString().contains('User canceled')) throw MacOsCommandLineAliasCancelledException();

    throw Exception('Failed to run "$command" (exit code ${result.exitCode}): ${result.stderr}');
  }
}

class MacOsCommandLineAliasCancelledException implements Exception {}
