import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:questpdf_companion/areas/application/widgets/application_titlebar_window_buttons.dart';
import 'package:questpdf_companion/main.dart';

void main() {
  testWidgets('desktop title-bar dragging and caption buttons remain usable', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'QuestPDF Companion',
      packageName: 'questpdf_companion',
      version: '2026.11.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (call) async {
      calls.add(call.method);
      return call.method == 'isFullScreen' ? false : null;
    });

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(ProviderScope(child: QuestPdfCompanionApp(key: ValueKey(platform))));
      await tester.pump();
      calls.clear();
      await tester.dragFrom(const Offset(400, 22), const Offset(60, 0));
      await tester.pump();
      expect(calls, contains('startDragging'));

      final buttons = find.descendant(
        of: find.byType(ApplicationTitlebarWindowButtons),
        matching: find.byType(IconButton),
      );
      if (platform == TargetPlatform.macOS) {
        expect(buttons, findsNothing);
      } else {
        await tester.tap(buttons.first);
        await tester.tap(buttons.last);
        await tester.pump();
        expect(calls, containsAll(['minimize', 'close']));
      }
    }
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
