import 'package:flutter/material.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_hierarchy_element_layout_error_measurement.dart';

import '../theme/app_colors.dart';

extension LayoutErrorMeasurementColor on DocumentHierarchyElementLayoutErrorMeasurement? {
  // on white, the status colors are too saturated for small dots
  static const _lightRootCause = Color(0xFFDC4C46);
  static const _lightWrap = Color(0xFFE68427);
  static const _lightPartialRender = Color(0xFFE3C342);
  static const _lightFullRender = Color(0xFF3DAA72);

  // the dark error color leans to salmon (close to orange) and the dark warning color to amber (close to yellow)
  static const _darkRootCause = Color(0xFFEF4444);
  static const _darkWrap = Color(0xFFF6882F);

  Color getAnnotationColor(BuildContext context) {
    final measurement = this;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (measurement == null) return Colors.transparent;
    if (measurement.isLayoutErrorRootCause) return isDark ? _darkRootCause : _lightRootCause;

    return switch (measurement.spacePlanType) {
      SpacePlanType.wrap => isDark ? _darkWrap : _lightWrap,
      SpacePlanType.partialRender => isDark ? colors.caution : _lightPartialRender,
      SpacePlanType.fullRender || SpacePlanType.empty => isDark ? colors.success : _lightFullRender,
      null => Colors.transparent,
    };
  }
}
