import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questpdf_companion/areas/document_hierarchy/state/document_hierarchy_manual_measurement.dart';
import 'package:questpdf_companion/areas/document_preview/state/document_preview_pointer_location_state.dart';

import 'document_preview_test.dart';

double? measuredX() => documentHierarchyManualMeasurementProviderInstance.manualMeasurementResult?.vertical.begin.dx;

void main() {
  previewTest('pressing a measurement key measures at the current cursor position', (tester) async {
    await showPreview(tester);

    documentHierarchyManualMeasurementProviderInstance.findPreviewMeasurement(
      PointerLocation(pageNumber: 1, x: 100, y: 100),
      1,
    );
    documentPreviewPointerLocationStateInstance.update(PointerLocation(pageNumber: 1, x: 500, y: 900));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit3);
    await tester.pump();

    expect(measuredX(), 500);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
  });

  previewTest('a measurement follows the latest mouse position, not the previous one', (tester) async {
    await showPreview(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 100));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    await mouse.moveTo(const Offset(420, 100));
    await tester.pump();
    final first = measuredX();

    await mouse.moveTo(const Offset(450, 100));
    await tester.pump();

    expect(measuredX(), isNot(first));
    expect(measuredX(), documentPreviewPointerLocationStateInstance.state?.x);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    await mouse.removePointer();
  });
}
