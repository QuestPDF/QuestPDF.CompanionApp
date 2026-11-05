import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/document_structure_page_size.dart';
import 'package:questpdf_companion/areas/document_hierarchy/models/page_location.dart';

import '../../document_preview/state/document_preview_pointer_location_state.dart';
import '../../document_preview/state/document_viewer_state_provider.dart';
import '../models/document_hierarchy_element.dart';
import 'document_hierarchy_provider.dart';

final documentHierarchyManualMeasurementProviderInstance = DocumentHierarchyManualMeasurement();
final documentHierarchyManualMeasurementProvider = ChangeNotifierProvider(
  (ref) => documentHierarchyManualMeasurementProviderInstance,
);

class DocumentHierarchyManualMeasurement extends ChangeNotifier {
  DocumentManualMeasurementResult? manualMeasurementResult;

  void resetPreviewMeasurement() {
    if (manualMeasurementResult == null) return;

    manualMeasurementResult = null;
    notifyListeners();
  }

  void findPreviewMeasurement(PointerLocation pointerLocation, double scale) {
    if (documentPreviewImageCacheStateInstance.pages.length < pointerLocation.pageNumber) return;

    final pageSize = documentPreviewImageCacheStateInstance.pages[pointerLocation.pageNumber - 1];
    final measurableElements = _findVisibleAndMeasurableElementsHelper(pointerLocation.pageNumber);

    final point = _getPointMeasurement(measurableElements, pointerLocation, 10 / scale);
    final vertical = _getVerticalMeasurement(measurableElements, pointerLocation, pageSize);
    final horizontal = _getHorizontalMeasurement(measurableElements, pointerLocation, pageSize);

    manualMeasurementResult = DocumentManualMeasurementResult(
      pageNumber: pointerLocation.pageNumber,
      point: point,
      vertical: vertical,
      horizontal: horizontal,
    );

    notifyListeners();
  }

  List<DocumentHierarchyElement> _findVisibleAndMeasurableElementsHelper(int pageNumber) {
    final root = documentHierarchyProviderInstance.root;

    if (root == null) return [];

    final List<DocumentHierarchyElement> result = [];

    void findVisibleElements(DocumentHierarchyElement node) {
      if (node.isVisual) result.add(node);

      final isVisible = node.pageLocations.any((x) => x.pageNumber == pageNumber);

      if (!isVisible) return;

      node.children.forEach(findVisibleElements);
    }

    findVisibleElements(root);
    return result;
  }

  bool isClose(double a, double b) {
    return (a - b).abs() < 0.01;
  }

  DocumentManualMeasurementResultAxis _getHorizontalMeasurement(
    List<DocumentHierarchyElement> elements,
    PointerLocation pointer,
    DocumentStructurePageSize pageSize,
  ) {
    final closeToCursor = elements.mapNotNull((element) {
      final location = element.pageLocations.where((page) => page.pageNumber == pointer.pageNumber).firstOrNull;

      if (location == null) return null;

      if (pointer.y < location.top || location.bottom < pointer.y) return null;

      return (element: element, location: location);
    }).toList();

    final sortedSides = [
      0.0,
      ...closeToCursor.flatMap((x) => [x.location.left, x.location.right]),
      pageSize.width,
    ].distinct().sorted();

    final index = Iterable.generate(sortedSides.length - 1)
        .firstWhere((i) => sortedSides[i] <= pointer.x && pointer.x <= sortedSides[i + 1]);

    final begin = Offset(sortedSides[index], pointer.y);
    final end = Offset(sortedSides[index + 1], pointer.y);

    Rect? findRelatedElement(double side) {
      final touching = closeToCursor
          .where((x) => isClose(x.location.left, side) || isClose(x.location.right, side))
          .toList();

      final preferred = touching
          .where((x) => x.location.left <= pointer.x && pointer.x <= x.location.right)
          .minBy((x) => x.location.area);

      final fallback = touching.minBy((x) => x.location.area);

      return (preferred ?? fallback)?.location.toRect();
    }

    final relatedElementBegin = findRelatedElement(begin.dx);
    final relatedElementEnd = findRelatedElement(end.dx);

    return DocumentManualMeasurementResultAxis(
      begin: begin,
      end: end,
      relatedElementBegin: relatedElementBegin,
      relatedElementEnd: relatedElementEnd,
    );
  }

  DocumentManualMeasurementResultAxis _getVerticalMeasurement(
    List<DocumentHierarchyElement> elements,
    PointerLocation pointer,
    DocumentStructurePageSize pageSize,
  ) {
    final closeToCursor = elements.mapNotNull((element) {
      final location = element.pageLocations.where((page) => page.pageNumber == pointer.pageNumber).firstOrNull;

      if (location == null) return null;

      if (pointer.x < location.left || location.right < pointer.x) return null;

      return (element: element, location: location);
    }).toList();

    final sortedSides = [
      0.0,
      ...closeToCursor.flatMap((x) => [x.location.top, x.location.bottom]),
      pageSize.height,
    ].distinct().sorted();

    final index = Iterable.generate(sortedSides.length - 1)
        .firstWhere((i) => sortedSides[i] <= pointer.y && pointer.y <= sortedSides[i + 1]);

    final begin = Offset(pointer.x, sortedSides[index]);
    final end = Offset(pointer.x, sortedSides[index + 1]);

    Rect? findRelatedElement(double side) {
      final touching = closeToCursor
          .where((x) => isClose(x.location.top, side) || isClose(x.location.bottom, side))
          .toList();

      final preferred = touching
          .where((x) => x.location.top <= pointer.y && pointer.y <= x.location.bottom)
          .minBy((x) => x.location.area);

      final fallback = touching.minBy((x) => x.location.area);

      return (preferred ?? fallback)?.location.toRect();
    }

    final relatedElementBegin = findRelatedElement(begin.dy);
    final relatedElementEnd = findRelatedElement(end.dy);

    return DocumentManualMeasurementResultAxis(
      begin: begin,
      end: end,
      relatedElementBegin: relatedElementBegin,
      relatedElementEnd: relatedElementEnd,
    );
  }

  DocumentManualMeasurementResultPoint? _getPointMeasurement(
    List<DocumentHierarchyElement> elements,
    PointerLocation pointer,
    double tolerance,
  ) {
    final pointerLocation = Offset(pointer.x, pointer.y);

    double distanceFromPointToRect(Rect rect, Offset point) {
      return [
            rect.left - point.dx,
            rect.right - point.dx,
            rect.top - point.dy,
            rect.bottom - point.dy,
          ].map((x) => x.abs()).min() ??
          0;
    }

    final targetRectangle = elements
        .mapNotNull((x) => x.pageLocations.where((page) => page.pageNumber == pointer.pageNumber).firstOrNull?.toRect())
        .where((x) {
          final outerRect = x.inflate(tolerance);
          final innerRect = x.deflate(tolerance);

          return outerRect.contains(pointerLocation) && !innerRect.contains(pointerLocation);
        })
        .sortedBy((x) => x.contains(pointerLocation) ? 0 : 1)
        .thenBy((x) => distanceFromPointToRect(x, pointerLocation).round())
        .thenBy((x) => x.width * x.height)
        .firstOrNull;

    if (targetRectangle == null) return null;

    var targetPointX = pointerLocation.dx;
    var targetPointY = pointerLocation.dy;

    if ((targetRectangle.left - pointerLocation.dx).abs() < tolerance) targetPointX = targetRectangle.left;

    if ((targetRectangle.right - pointerLocation.dx).abs() < tolerance) targetPointX = targetRectangle.right;

    if ((targetRectangle.top - pointerLocation.dy).abs() < tolerance) targetPointY = targetRectangle.top;

    if ((targetRectangle.bottom - pointerLocation.dy).abs() < tolerance) targetPointY = targetRectangle.bottom;

    final targetPoint = Offset(targetPointX, targetPointY);
    return DocumentManualMeasurementResultPoint(point: targetPoint, relatedRect: targetRectangle);
  }
}

class DocumentManualMeasurementResultPoint {
  final Offset point;
  final Rect relatedRect;

  DocumentManualMeasurementResultPoint({required this.point, required this.relatedRect});
}

class DocumentManualMeasurementResultAxis {
  final Offset begin;
  final Offset end;

  final Rect? relatedElementBegin;
  final Rect? relatedElementEnd;

  double get length => (begin - end).distance;

  DocumentManualMeasurementResultAxis({
    required this.begin,
    required this.end,
    required this.relatedElementBegin,
    required this.relatedElementEnd,
  });
}

class DocumentManualMeasurementResult {
  final int pageNumber;
  final DocumentManualMeasurementResultPoint? point;
  final DocumentManualMeasurementResultAxis vertical;
  final DocumentManualMeasurementResultAxis horizontal;

  DocumentManualMeasurementResult({
    required this.pageNumber,
    required this.point,
    required this.vertical,
    required this.horizontal,
  });
}
