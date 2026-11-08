import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/welcome/welcome_view_button.dart';
import 'package:questpdf_companion/areas/welcome/welcome_view_connection_error.dart';
import 'package:questpdf_companion/communication_service.dart';
import 'package:questpdf_companion/shared/font_awesome_icons.dart';
import 'package:questpdf_companion/theme/app_colors.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a port error matches menu alignment and clears after recovery in ${brightness.name} mode', (
      tester,
    ) async {
      final failedPort = communicationServiceInstance.failedPort;
      addTearDown(() => failedPort.value = null);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WelcomeViewButton(icon: FontAwesomeIcons.gear, label: 'Settings', trailingIcon: null, onClick: () {}),
                  const WelcomeViewConnectionError(),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(FontAwesomeIcons.linkHorizontal), findsNothing);
      failedPort.value = 12501;
      await tester.pump();
      final message = find.text('Port 12501 is unavailable. Retrying automatically. Change it in Settings.');
      expect(message, findsOneWidget);
      final icon = find.byIcon(FontAwesomeIcons.linkHorizontal);
      final menuIcon = find.byIcon(FontAwesomeIcons.gear);
      expect(icon, findsOneWidget);
      expect(
        tester.widget<Icon>(icon).color,
        brightness == Brightness.light ? AppColors.light.error : AppColors.dark.error,
      );
      expect(tester.widget<Text>(message).style?.fontSize, 14);
      expect(tester.getSize(icon), tester.getSize(menuIcon));
      expect(tester.getTopLeft(icon).dx, tester.getTopLeft(menuIcon).dx);
      expect(tester.getTopLeft(message).dx, tester.getTopLeft(find.text('Settings')).dx);
      expect(tester.getTopLeft(message).dx - tester.getBottomRight(icon).dx, 20);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      failedPort.value = null;
      await tester.pump();
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('is unavailable'), findsNothing);
      expect(find.byIcon(FontAwesomeIcons.linkHorizontal), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
