import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/application/widgets/application_layout.dart';
import 'package:window_manager/window_manager.dart';

import 'communication_service.dart';
import 'shared/command_line_arguments.dart';
import 'theme/app_theme.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  // the bundled Inter font is distributed under the SIL Open Font License, which must accompany it
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/Inter-LICENSE.txt');
    yield LicenseEntryWithLineBreaks(['Inter'], license);
  });

  await windowManager.ensureInitialized();
  // macOS keeps its native window buttons; other platforms draw their own in the title bar
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: Platform.isMacOS);
  await windowManager.setMinimumSize(const Size(600, 500));

  await applicationStateProviderInstance.loadDefaultSettings(communicationPortOverride: parseCommunicationPort(arguments));
  await communicationServiceInstance.tryToStartTheServer(applicationStateProviderInstance.communicationPort);

  runApp(const ProviderScope(child: QuestPdfCompanionApp()));
}

class QuestPdfCompanionApp extends ConsumerWidget {
  const QuestPdfCompanionApp({super.key});

  static final shortcuts = Map<ShortcutActivator, Intent>.of(WidgetsApp.defaultShortcuts)
    ..removeWhere((activator, intent) => intent is DirectionalFocusIntent);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(applicationStateProvider.select((x) => x.themeMode));

    return MaterialApp(
      title: 'QuestPDF Companion',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      shortcuts: shortcuts,
      home: const ApplicationLayout(),
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: false,
    );
  }
}
