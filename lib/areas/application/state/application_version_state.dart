import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shared/questpdf_urls.dart';

final applicationVersionProviderInstance = ApplicationVersionState();
final applicationVersionProvider = ChangeNotifierProvider((ref) => applicationVersionProviderInstance);

class ApplicationVersionState extends ChangeNotifier {
  ApplicationVersion? currentApplicationVersion;
  ApplicationVersion? latestApplicationVersion;

  bool get isUpdateAvailable => latestApplicationVersion?.isNewerThan(currentApplicationVersion) ?? false;

  ApplicationVersionState() {
    loadCurrentApplicationVersion();
    fetchLatestApplicationVersion();
  }

  Future<void> loadCurrentApplicationVersion() async {
    final info = await PackageInfo.fromPlatform();
    currentApplicationVersion = ApplicationVersion.parse(info.version);
    notifyListeners();
  }

  Future<void> fetchLatestApplicationVersion() async {
    try {
      final response = await http.get(Uri.parse(QuestPdfUrls.companionLatestVersion));
      latestApplicationVersion = ApplicationVersion.parse(response.body);
      notifyListeners();
    } catch (e) {
      // offline or an unexpected response, so no update is shown
    }
  }
}

class ApplicationVersion {
  final int major;
  final int minor;
  final int patch;

  String get text => '$major.$minor.$patch';

  ApplicationVersion(this.major, this.minor, this.patch);

  static ApplicationVersion parse(String version) {
    final parts = version.split('.');
    return ApplicationVersion(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  bool isNewerThan(ApplicationVersion? other) {
    if (other == null) return false;

    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;

    return patch > other.patch;
  }
}
