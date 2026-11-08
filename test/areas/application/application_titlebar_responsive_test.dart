import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/application/state/application_version_state.dart';
import 'package:questpdf_companion/areas/application/widgets/application_titlebar.dart';
import 'package:questpdf_companion/areas/application/widgets/application_titlebar_card.dart';
import 'package:questpdf_companion/areas/application/widgets/application_titlebar_window_buttons.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

void main() {
  testWidgets('all title-bar statuses fit and caption buttons remain reachable on desktop', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Companion',
      packageName: 'com.questpdf.companion',
      version: '2026.11.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await (FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'))).load();
    final container = ProviderContainer();
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
      calls.add(call.method);
      return ['isFullScreen', 'isMaximized'].contains(call.method) ? false : null;
    });
    applicationStateProviderInstance
      ..changeMode(ApplicationMode.genericException)
      ..setCurrentLicense(LicenseType.evaluation)
      ..setDocumentAsHotReloaded(true);
    applicationVersionProviderInstance.currentApplicationVersion = ApplicationVersion(2026, 11, 0);
    applicationVersionProviderInstance.latestApplicationVersion = ApplicationVersion(2027, 1, 0);

    try {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final width in [600.0, 800.0, 1280.0]) {
          for (final textScale in [1.0, 2.0]) {
            await tester.binding.setSurfaceSize(Size(width, 500));
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: buildAppTheme(Brightness.light),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: child!,
                  ),
                  home: const Scaffold(body: SizedBox(height: 44, child: ApplicationTitlebar())),
                ),
              ),
            );
            await tester.runAsync(
              () => precacheImage(
                const AssetImage('assets/questpdf-logo-light.png'),
                tester.element(find.byType(ApplicationTitlebar)),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$platform, width=$width, textScale=$textScale');
            expect(find.byType(ApplicationTitlebarCard), findsNWidgets(3));
            expect(find.text('EVALUATION MODE'), width >= 800 * textScale ? findsOneWidget : findsNothing);

            final buttons = find.descendant(
              of: find.byType(ApplicationTitlebarWindowButtons),
              matching: find.byType(IconButton),
            );
            if (platform == TargetPlatform.macOS) {
              expect(buttons, findsNothing);
            } else {
              calls.clear();
              for (final button in buttons.evaluate()) {
                final finder = find.byElementPredicate((element) => identical(element, button));
                final rect = tester.getRect(finder);
                expect(rect.left, greaterThanOrEqualTo(0));
                expect(rect.right, lessThanOrEqualTo(width));
                await tester.tap(finder);
                await tester.pump();
              }
              expect(calls, containsAll(['minimize', 'maximize', 'close']));
            }
          }
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      container.dispose();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
