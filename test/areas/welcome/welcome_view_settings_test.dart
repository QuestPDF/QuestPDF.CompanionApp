import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';
import 'package:questpdf_companion/areas/welcome/welcome_view_settings.dart';
import 'package:questpdf_companion/communication_service.dart';
import 'package:questpdf_companion/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await font.load();
  });

  test('a port that cannot be used falls back to the default one', () {
    for (final text in ['', '0', '125', '1023', '65536', '99999999999999999999']) {
      expect(ApplicationStateProvider.sanitizePortNumber(text), communicationServiceDefaultPort, reason: '"$text"');
    }

    expect(ApplicationStateProvider.sanitizePortNumber('1024'), 1024);
    expect(ApplicationStateProvider.sanitizePortNumber('65535'), 65535);
  });

  testWidgets('desktop port field applies on submission and focus loss', (tester) async {
    final state = applicationStateProviderInstance;
    final outsideFocus = FocusNode();
    final bindAttempts = <int>[];
    var nextPort = 12501;

    void expectPortFieldGeometry() {
      final field = find.byType(TextField);
      final editable = find.byType(EditableText);
      final fill = InputDecorator.containerOf(tester.element(editable))!;
      final fillBounds = fill.localToGlobal(Offset.zero) & fill.size;
      expect(fill.size, const Size(72, 30), reason: 'The painted field must match the other settings controls');
      expect(fillBounds, tester.getRect(field));
      final text = tester.state<EditableTextState>(editable).renderEditable;
      final textCenter = text.localToGlobal(Offset(0, text.size.height / 2));
      expect(textCenter.dy, closeTo(fillBounds.center.dy, 0.01));
    }

    try {
      await IOOverrides.runZoned(
        () async {
          for (final (platform, brightness) in [
            for (final platform in [TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS])
              for (final brightness in Brightness.values) (platform, brightness),
          ]) {
            debugDefaultTargetPlatformOverride = platform;
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  key: ValueKey((platform, brightness)),
                  theme: buildAppTheme(brightness),
                  home: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: 320,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(focusNode: outsideFocus, onPressed: () {}, child: const Text('Outside settings')),
                            const WelcomeViewSettings(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Settings'));
            await tester.pumpAndSettle();
            final field = find.byType(TextField);
            expect(tester.getSize(field), const Size(72, 30));
            expectPortFieldGeometry();

            for (final action in [TextInputAction.done, TextInputAction.newline]) {
              final previousPort = state.communicationPort;
              final port = nextPort++;
              await tester.enterText(field, port.toString());
              await tester.pump();
              expectPortFieldGeometry();
              expect(tester.testTextInput.setClientArgs!['inputAction'], 'TextInputAction.done');
              expect(state.communicationPort, previousPort);
              await tester.testTextInput.receiveAction(action);
              await tester.pumpAndSettle();
              expectPortFieldGeometry();
              expect(state.communicationPort, port, reason: '$platform: $action must submit');
              expect(bindAttempts.where((attempt) => attempt == port), hasLength(1));
              expect(tester.widget<TextField>(field).controller!.text, port.toString());
            }

            final filteredPort = nextPort++;
            await tester.enterText(field, '');
            await tester.pump();
            expectPortFieldGeometry();
            await tester.enterText(field, '${filteredPort}x\n');
            expect(tester.widget<TextField>(field).controller!.text, filteredPort.toString());
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pumpAndSettle();
            expect(state.communicationPort, filteredPort);

            final blurPort = nextPort++;
            await tester.enterText(field, blurPort.toString());
            await tester.pump();
            await tester.tap(find.text('Outside settings'));
            await tester.pumpAndSettle();
            expect(state.communicationPort, blurPort);
            expect(bindAttempts.where((attempt) => attempt == blurPort), hasLength(1));

            final tabPort = nextPort++;
            await tester.enterText(field, tabPort.toString());
            await tester.pump();
            expect(state.communicationPort, blurPort);
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            expect(state.communicationPort, tabPort, reason: '$platform: Tab must apply the port');
            expect(bindAttempts.where((attempt) => attempt == tabPort), hasLength(1));

            final movedFocusPort = nextPort++;
            await tester.enterText(field, movedFocusPort.toString());
            await tester.pump();
            outsideFocus.requestFocus();
            await tester.pumpAndSettle();
            expect(state.communicationPort, movedFocusPort, reason: '$platform: moving focus must apply the port');
            expect(bindAttempts.where((attempt) => attempt == movedFocusPort), hasLength(1));

            final collapsedPort = nextPort++;
            await tester.enterText(field, collapsedPort.toString());
            await tester.pump();
            await tester.tap(find.text('Settings'));
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsNothing);
            expect(state.communicationPort, collapsedPort);
            expect(bindAttempts.where((attempt) => attempt == collapsedPort), hasLength(1));
            expect(tester.takeException(), isNull);
          }
        },
        serverSocketBind: (address, port, {backlog = 0, v6Only = false, shared = false}) async {
          // Exercise submission without opening sockets in a widget-test zone.
          bindAttempts.add(port);
          throw const SocketException('Port occupied in test');
        },
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await communicationServiceInstance.stopServer();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      outsideFocus.dispose();
    }
  });
}
