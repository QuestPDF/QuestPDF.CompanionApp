import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:dartx/dartx.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../shared/keyboard_shortcuts.dart';
import '../../../shared/open_source_code_path_in_editor.dart';
import '../../application/state/application_state_provider.dart';
import '../../document_hierarchy/models/document_hierarchy_element.dart';
import '../../document_hierarchy/models/document_structure_page_size.dart';
import '../../document_hierarchy/models/page_location.dart';
import '../../document_hierarchy/models/page_snapshot_index.dart';
import '../../document_hierarchy/state/document_hierarchy_manual_measurement.dart';
import '../../document_hierarchy/state/document_hierarchy_provider.dart';
import '../state/document_preview_pointer_location_state.dart';
import '../state/document_preview_visible_content_state.dart';
import '../state/document_viewer_state_provider.dart';

class DocumentPreview extends StatefulWidget {
  final List<DocumentStructurePageSize> pages;
  final DocumentHierarchyElement? hoveredElement;
  final DocumentHierarchyElement? selectedElement;
  final int? selectedElementLocationIndex;
  final DocumentManualMeasurementResult? manualMeasurementResult;

  const DocumentPreview({
    super.key,
    required this.pages,
    required this.hoveredElement,
    required this.selectedElement,
    required this.selectedElementLocationIndex,
    required this.manualMeasurementResult,
  });

  @override
  State<DocumentPreview> createState() => DocumentPreviewState();
}

class DocumentPreviewState extends State<DocumentPreview> with SingleTickerProviderStateMixin {
  final GlobalKey previewKey = GlobalKey();

  Offset translate = Offset.zero;
  double scale = 1;

  double scaleOnGestureStart = 1;

  late final AnimationController flingController;
  Offset flingDirection = Offset.zero;
  double flingLastDistance = 0;

  num cacheRefreshId = 0;
  List<PageDrawingPlan> pagePositions = [];
  double totalDocumentHeight = 0;
  double totalDocumentWidth = 0;

  Offset currentCursorPositionOnCanvas = Offset.zero;

  /* KEYBOARD AND MOUSE INTERACTION */
  bool isHighResolution = false;

  static const scrollPointsPerWheelTick = 120.0;
  static const scrollZoomSensitivity = 0.25;
  static const scrollPanSensitivity = 75.0;
  static const mouseMoveZoomSensitivity = 0.01;
  static const keyboardPanSensitivity = 25.0;
  static const keyboardPanShiftSensitivity = 250.0;
  static const keyboardZoomSensitivity = 1.2;

  List<DocumentStructurePageSize> get pages => widget.pages;

  ui.Rect get renderBox => (context.findRenderObject() as RenderBox?)?.paintBounds ?? ui.Rect.zero;

  PointerHoverInteraction pointerHoverInteraction = PointerHoverInteraction.none;

  bool scrollbarHover = false;
  bool scrollbarMove = false;

  @override
  void initState() {
    super.initState();

    flingController = AnimationController.unbounded(vsync: this)..addListener(handleFlingTick);
    HardwareKeyboard.instance.addHandler(handleKeyInteraction);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(handleKeyInteraction);
    flingController.dispose();
    super.dispose();
  }

  bool handleKeyInteraction(KeyEvent event) {
    const cursorModifierKeys = [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
    ];

    if (event is! KeyRepeatEvent && cursorModifierKeys.contains(event.logicalKey)) setState(() {});

    // shortcut: zoom on page
    final isControlPressed =
        HardwareKeyboard.instance.isControlPressed || (Platform.isMacOS && HardwareKeyboard.instance.isMetaPressed);

    if (isCanvasNavigationByKeyboardShortcutsAvailable() &&
        event is KeyDownEvent &&
        isControlPressed &&
        event.physicalKey == PhysicalKeyboardKey.keyE) {
      zoomOnPage();
      return true;
    }

    // shortcut: zoom in and out
    if (isCanvasNavigationByKeyboardShortcutsAvailable() && event is! KeyUpEvent && isControlPressed) {
      const zoomInKeys = [PhysicalKeyboardKey.equal, PhysicalKeyboardKey.numpadAdd];
      const zoomOutKeys = [PhysicalKeyboardKey.minus, PhysicalKeyboardKey.numpadSubtract];

      if (zoomInKeys.contains(event.physicalKey)) {
        zoomBy(keyboardZoomSensitivity, viewportCenter);
        return true;
      }

      if (zoomOutKeys.contains(event.physicalKey)) {
        zoomBy(1 / keyboardZoomSensitivity, viewportCenter);
        return true;
      }
    }

    // shortcut: pan with arrow keys
    Offset? findKeyboardPanDirection(LogicalKeyboardKey key) {
      if (!isCanvasNavigationByKeyboardShortcutsAvailable()) return null;

      if (key == LogicalKeyboardKey.arrowLeft) return const Offset(1, 0);

      if (key == LogicalKeyboardKey.arrowRight) return const Offset(-1, 0);

      if (key == LogicalKeyboardKey.arrowUp) return const Offset(0, 1);

      if (key == LogicalKeyboardKey.arrowDown) return const Offset(0, -1);

      return null;
    }

    if (isCanvasNavigationByKeyboardShortcutsAvailable() && event is! KeyUpEvent && !isControlPressed) {
      final panDirection = findKeyboardPanDirection(event.logicalKey);

      final modifier = HardwareKeyboard.instance.isShiftPressed ? keyboardPanShiftSensitivity : keyboardPanSensitivity;

      if (panDirection != null) {
        panBy(panDirection * modifier);
        return true;
      }
    }

    // shortcut: pointer interactions
    PointerHoverInteraction? findBestInteraction() {
      if (event is KeyUpEvent) return PointerHoverInteraction.none;

      if (event.physicalKey == PhysicalKeyboardKey.digit1) return PointerHoverInteraction.zoom;

      if (event.physicalKey == PhysicalKeyboardKey.digit2) return PointerHoverInteraction.showPosition;

      if (event.physicalKey == PhysicalKeyboardKey.digit3) return PointerHoverInteraction.measureVertical;

      if (event.physicalKey == PhysicalKeyboardKey.digit4) return PointerHoverInteraction.measureHorizontal;

      return null;
    }

    final bestInteraction = findBestInteraction();

    if (areCanvasKeyboardToolInteractionsAvailable() && bestInteraction != null) {
      if (pointerHoverInteraction != bestInteraction) {
        pointerHoverInteraction = bestInteraction;
        setState(() {});
      }

      return true;
    }

    return false;
  }

  void initNewDocument() {
    setState(() {
      pagePositions = planPagePositions();
      totalDocumentHeight = pages.sumBy((x) => x.height) + (pages.length + 1) * pageSpacing;
      totalDocumentWidth = pages.map((x) => x.width).max()! + 2 * pageSpacing;
    });
  }

  void handleMouseDownEvent(PointerDownEvent event) {
    flingController.stop();
    documentHierarchyProviderInstance.setSelectedElement(null);
  }

  void handleMouseScrollEvent(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    flingController.stop();
    documentHierarchyProviderInstance.setSelectedElement(null);

    final scrollDelta = event.scrollDelta.dy / scrollPointsPerWheelTick;

    if (HardwareKeyboard.instance.isControlPressed) {
      zoomBy(1 / exp(scrollDelta * scrollZoomSensitivity), event.localPosition);
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      panBy(Offset(-scrollDelta * scrollPanSensitivity, 0));
    } else {
      panBy(Offset(0, -scrollDelta * scrollPanSensitivity));
    }
  }

  static const pageSpacing = 32.0;

  List<PageDrawingPlan> getVisiblePages({double visibleBoxBufferFactor = 0}) {
    if (previewKey.currentContext == null) return [];

    final visibleBoxTopLeft = (-translate - renderBox.topLeft / 2) / scale;
    final visibleBoxSize = renderBox.size / scale;
    final visibleBox = (visibleBoxTopLeft & visibleBoxSize).inflate(visibleBoxSize.height * visibleBoxBufferFactor);

    return pagePositions.where((x) => !x.position.intersect(visibleBox).isEmpty).toList();
  }

  List<PageDrawingPlan> planPagePositions() {
    List<PageDrawingPlan> result = [];
    var verticalOffset = pageSpacing;

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];

      final topLeft = Offset(-page.width / 2, verticalOffset);
      final size = Size(page.width, page.height);

      final position = topLeft & size;

      result.add(PageDrawingPlan(pageIndex: i, position: position));
      verticalOffset += page.height + pageSpacing;
    }

    return result;
  }

  List<PageLocation> getVisiblePageFragments() {
    if (previewKey.currentContext == null) return [];

    final visibleBoxTopLeft = (-translate - renderBox.topCenter) / scale;
    final visibleBoxSize = renderBox.size / scale;
    final visibleBox = visibleBoxTopLeft & visibleBoxSize;

    final visiblePages = pagePositions
        .map((x) => (page: x, intersection: x.position.intersect(visibleBox).shift(-x.position.topLeft)))
        .where((x) => !x.intersection.isEmpty)
        .map(
          (x) => PageLocation(
            pageNumber: x.page.pageIndex + 1,
            left: x.intersection.left,
            top: x.intersection.top,
            right: x.intersection.right,
            bottom: x.intersection.bottom,
          ),
        )
        .toList();

    return visiblePages;
  }

  void handleTranslateLimits() {
    var minVerticalTranslate = -totalDocumentHeight * scale + renderBox.size.height;
    final maxHorizontalOffset = (renderBox.size.width / 2 - totalDocumentWidth / 2 * scale).abs();

    translate = Offset(
      translate.dx.clamp(-maxHorizontalOffset, maxHorizontalOffset),
      translate.dy.clamp(min(0, minVerticalTranslate), 0),
    );

    // scale where entire document width is visible should be centered
    final idealWidthScale = renderBox.size.width / totalDocumentWidth;
    final idealHeightScale = renderBox.size.height / totalDocumentHeight;

    translate = Offset(
      idealWidthScale > scale ? 0 : translate.dx,
      idealHeightScale > scale ? (renderBox.size.height - totalDocumentHeight * scale) / 2 : translate.dy,
    );
  }

  Offset get viewportCenter => renderBox.size.center(Offset.zero);

  void panBy(Offset delta) {
    setState(() {
      translate += delta;
      applyViewportChange();
    });
  }

  // momentum scrolling
  void startFling(Velocity velocity) {
    final pixelsPerSecond = velocity.pixelsPerSecond;

    if (pixelsPerSecond.distance < kMinFlingVelocity) return;

    const dragCoefficient = 0.135;
    const constantDeceleration = 1400.0;

    flingDirection = pixelsPerSecond / pixelsPerSecond.distance;
    flingLastDistance = 0;
    flingController.animateWith(
      FrictionSimulation(dragCoefficient, 0, pixelsPerSecond.distance, constantDeceleration: constantDeceleration),
    );
  }

  void handleFlingTick() {
    panBy(flingDirection * (flingController.value - flingLastDistance));
    flingLastDistance = flingController.value;
  }

  void zoomBy(double zoomFactor, Offset pivot, {Offset panDelta = Offset.zero}) {
    setState(() {
      final oldScale = scale;
      scale *= zoomFactor;
      handleScaleLimits();

      // keep the pivot stationary, based on the scale change that survived the limits
      final viewportOrigin = Offset(renderBox.size.width / 2, 0);
      final pivotInViewportCoordinates = pivot - viewportOrigin;

      translate += (pivotInViewportCoordinates - translate) * (1 - scale / oldScale);
      translate += panDelta;

      applyViewportChange();
    });
  }

  void applyViewportChange() {
    handleTranslateLimits();
    updateNeededImages();
    updateCursorLocation();
    handleManualMeasurement();
  }

  void handleScaleLimits() {
    const minScale = 0.1;
    const maxScale = 10.0;

    scale = scale.clamp(minScale, maxScale);
  }

  void handleMouseHoverEvent(PointerHoverEvent event) {
    currentCursorPositionOnCanvas = Offset(event.localPosition.dx, event.localPosition.dy);
    updateCursorLocation();

    if (pointerHoverInteraction != PointerHoverInteraction.none) handleManualMeasurement();
  }

  void onDoubleTap() {
    final pointerLocation = documentPreviewPointerLocationStateInstance.state;

    if (pointerLocation == null) return;

    documentHierarchyProviderInstance.findPreviewClickedElement(
      pointerLocation.pageNumber,
      pointerLocation.x,
      pointerLocation.y,
    );

    if (HardwareKeyboard.instance.isAltPressed) {
      final clickableLink = documentHierarchyProviderInstance.findClickableLink(
        pointerLocation.pageNumber,
        pointerLocation.x,
        pointerLocation.y,
      );

      if (clickableLink != null) documentHierarchyProviderInstance.openClickableLink(clickableLink);
    }

    final isControlPressed =
        HardwareKeyboard.instance.isControlPressed || (Platform.isMacOS && HardwareKeyboard.instance.isMetaPressed);

    if (isControlPressed) {
      Future(() {
        final location = documentHierarchyProviderInstance.findSourceCodeLocationOf(
          documentHierarchyProviderInstance.selectedElement,
        );

        if (location == null) return;

        tryOpenSourceCodePathInEditor(
          context,
          applicationStateProviderInstance.defaultCodeEditor,
          location.filePath,
          location.lineNumber,
        );
      });
    }
  }

  void zoomOnElement(DocumentHierarchyElement element, int pageLocationIndex) {
    final location = element.pageLocations[pageLocationIndex];
    zoomOn(location.pageNumber, location.toRect(), zoomScalePadding: 2);
  }

  void zoomOnPage() {
    final pageNumber = documentPreviewPointerLocationStateInstance.state?.pageNumber;

    if (pageNumber == null) return;

    final page = pagePositions[pageNumber - 1];
    zoomOn(pageNumber, Rect.fromLTWH(0, 0, page.position.width, page.position.height).inflate(pageSpacing));
  }

  void zoomOn(int pageNumber, Rect location, {double zoomScalePadding = 1}) {
    const maxZoom = 3.0;

    flingController.stop();

    final pagePosition = pagePositions[pageNumber - 1];

    setState(() {
      scale = min(renderBox.size.width / location.width, renderBox.size.height / location.height) / zoomScalePadding;
      scale = min(scale, maxZoom);
      translate = Offset(
        -(pagePosition.position.left + location.left + location.width / 2) * scale,
        renderBox.size.height / 2 - (pagePosition.position.top + location.top + location.height / 2) * scale,
      );

      handleScaleLimits();
      handleTranslateLimits();
      updateNeededImages();
      updateCursorLocation();
    });
  }

  void handleManualMeasurement() {
    final pointerLocation = documentPreviewPointerLocationStateInstance.state;

    if (pointerLocation == null) {
      documentHierarchyManualMeasurementProviderInstance.resetPreviewMeasurement();
      return;
    }

    documentHierarchyManualMeasurementProviderInstance.findPreviewMeasurement(pointerLocation, scale);
  }

  /* WIDGET BUILD */

  void updateNeededImages() {
    final visiblePageFragments = getVisiblePageFragments();
    documentPreviewVisibleContentStateInstance.update(visiblePageFragments);

    final currentZoomLevel = calculateZoomLevelFromScale(scale, isHighResolution);

    final neededImages = getVisiblePages(
      visibleBoxBufferFactor: 1,
    ).map((x) => PageSnapshotIndex(x.pageIndex, currentZoomLevel)).toList();

    documentPreviewImageCacheStateInstance.updateNeededImages(neededImages);
  }

  void updateCursorLocation() {
    final viewportOrigin = Offset(renderBox.size.width / 2, 0);

    final cursorPositionInViewportCoordinates = (currentCursorPositionOnCanvas - viewportOrigin);
    final cursorPositionInDocumentCoordinates = (cursorPositionInViewportCoordinates - translate) / scale;

    final currentPageIndex = pagePositions.indexWhere((x) => x.position.contains(cursorPositionInDocumentCoordinates));

    if (currentPageIndex == -1) {
      Future(() => documentPreviewPointerLocationStateInstance.update(null));
      return;
    }

    final page = pagePositions[currentPageIndex];
    final currentPagePosition = cursorPositionInDocumentCoordinates - page.position.topLeft;

    final position = PointerLocation(
      pageNumber: currentPageIndex + 1,
      x: currentPagePosition.dx,
      y: currentPagePosition.dy,
    );
    Future(() => documentPreviewPointerLocationStateInstance.update(position));
  }

  SystemMouseCursor getMouseCursor() {
    // disable mouse cursor on the zoom capability for visual clarity
    if (pointerHoverInteraction == PointerHoverInteraction.zoom) return SystemMouseCursors.none;

    // indicate clickable go-to-code interaction
    if (HardwareKeyboard.instance.isControlPressed) return SystemMouseCursors.click;

    // indicate clickable link
    bool hasClickableLink() {
      final pointerLocation = documentPreviewPointerLocationStateInstance.state;

      if (pointerLocation == null) return false;

      final clickableLink = documentHierarchyProviderInstance.findClickableLink(
        pointerLocation.pageNumber,
        pointerLocation.x,
        pointerLocation.y,
      );

      return clickableLink != null;
    }

    if (HardwareKeyboard.instance.isAltPressed && hasClickableLink()) return SystemMouseCursors.click;

    return SystemMouseCursors.basic;
  }

  Widget buildPreview() {
    final highlightedArea = (widget.hoveredElement ?? widget.selectedElement)?.pageLocations;

    return MouseRegion(
      cursor: getMouseCursor(),
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        onScaleStart: (details) {
          flingController.stop();
          scaleOnGestureStart = 1;
        },
        onScaleUpdate: (details) {
          zoomBy(details.scale / scaleOnGestureStart, details.localFocalPoint, panDelta: details.focalPointDelta);
          scaleOnGestureStart = details.scale;
        },
        onScaleEnd: (details) {
          scaleOnGestureStart = 1;
          startFling(details.velocity);
        },
        child: Listener(
          onPointerDown: handleMouseDownEvent,
          onPointerHover: handleMouseHoverEvent,
          onPointerSignal: handleMouseScrollEvent,
          child: CustomPaint(
            key: previewKey,
            painter: DocumentPreviewPainter(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              translate: translate,
              scale: scale,
              visiblePages: getVisiblePages(),
              isHighResolution: isHighResolution,
              highlightedArea: highlightedArea,
              interactionType: pointerHoverInteraction,
              pointerLocation: documentPreviewPointerLocationStateInstance.state,
              measurement: widget.manualMeasurementResult,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildScrollbar() {
    if (context.findRenderObject() == null) return const SizedBox();

    if (widget.selectedElement != null) return const SizedBox();

    final doesPageCoverEntireHorizontalSpace = totalDocumentWidth * scale >= renderBox.size.width;
    final isDocumentFullyVisible = totalDocumentHeight * scale <= renderBox.size.height;

    if (doesPageCoverEntireHorizontalSpace || isDocumentFullyVisible) return const SizedBox();

    const scrollbarTrackPadding = 8.0;
    const minScrollbarHeight = 50.0;

    final scrollbarTrackHeight = renderBox.size.height - scrollbarTrackPadding * 2 - minScrollbarHeight;
    final ratio = scrollbarTrackHeight / totalDocumentHeight / scale;

    final scrollbarStart = -translate.dy * ratio;
    final scrollbarHeight = renderBox.size.height * ratio + minScrollbarHeight;

    final scrollbarColor = (scrollbarHover || scrollbarMove)
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    return Positioned(
      right: 0,
      top: scrollbarStart,
      child: Padding(
        padding: const EdgeInsets.all(scrollbarTrackPadding),
        child: Listener(
          onPointerDown: (_) {
            flingController.stop();
            setState(() => scrollbarMove = true);
          },
          onPointerUp: (_) => setState(() => scrollbarMove = false),
          onPointerMove: (event) {
            if (event.buttons == 0) return;

            panBy(-ui.Offset(0, event.localDelta.dy) / ratio);
          },
          child: MouseRegion(
            cursor: (scrollbarHover || scrollbarMove) ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => scrollbarHover = true),
            onExit: (_) => setState(() => scrollbarHover = false),
            child: Container(
              width: 8,
              height: scrollbarHeight,
              decoration: BoxDecoration(color: scrollbarColor, borderRadius: const BorderRadius.all(Radius.circular(8))),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (documentPreviewImageCacheStateInstance.refreshId != cacheRefreshId) {
      cacheRefreshId = documentPreviewImageCacheStateInstance.refreshId;

      initNewDocument();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          handleTranslateLimits();
          handleScaleLimits();
        });

        updateNeededImages();
      });
    }

    isHighResolution = MediaQuery.of(context).devicePixelRatio > 1;

    if (widget.selectedElement != null) {
      zoomOnElement(widget.selectedElement!, widget.selectedElementLocationIndex!);
    }

    return Stack(
      children: [
        Positioned.fill(child: buildPreview()),
        buildScrollbar(),
      ],
    );
  }
}

class DocumentPreviewPainter extends CustomPainter {
  final Color backgroundColor;
  final Offset translate;
  final double scale;
  final List<PageDrawingPlan> visiblePages;
  final bool isHighResolution;
  final List<PageLocation>? highlightedArea;
  final PointerHoverInteraction interactionType;
  final PointerLocation? pointerLocation;
  final DocumentManualMeasurementResult? measurement;

  double get selectionThickness => 4 / scale;

  DocumentPreviewPainter({
    required this.backgroundColor,
    required this.translate,
    required this.scale,
    required this.visiblePages,
    required this.isHighResolution,
    required this.highlightedArea,
    required this.interactionType,
    required this.pointerLocation,
    required this.measurement,
  });

  @override
  void paint(Canvas canvas, Size size) async {
    canvas.save();

    drawBackground(canvas, size);

    canvas.translate(size.width / 2, 0);
    canvas.translate(translate.dx, translate.dy);
    canvas.scale(scale);

    drawDocument(canvas);
    drawMagnification(canvas, size);

    canvas.restore();
  }

  void drawBackground(Canvas canvas, Size drawingAreaSize) {
    final backgroundPaint = Paint()..color = backgroundColor;
    final drawingRect = Rect.fromLTWH(0, 0, drawingAreaSize.width, drawingAreaSize.height);

    canvas.drawRect(drawingRect, backgroundPaint);
  }

  void drawMagnification(Canvas canvas, Size drawingAreaSize) {
    const magnificationFactor = 3.0;
    const magnifierSize = 300.0;

    if (interactionType != PointerHoverInteraction.zoom) return;

    if (pointerLocation == null) return;

    final currentPage = visiblePages.where((x) => x.pageIndex == pointerLocation!.pageNumber - 1).firstOrNull;

    if (currentPage == null) return;

    final pointerLocationInScreenSpace = Offset(pointerLocation!.x, pointerLocation!.y) + currentPage.position.topLeft;

    canvas.save();

    // magnifier
    final magnifierClipRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: magnifierSize / scale, height: magnifierSize / scale),
      ui.Radius.circular(12 / scale),
    );
    final magnifierClipPath = Path()..addRRect(magnifierClipRect);

    final magnifierBackgroundPaint = Paint()..color = backgroundColor;

    final magnifierBorderPaint = Paint()
      ..color = Colors.black.withAlpha(64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;

    canvas.translate(pointerLocationInScreenSpace.dx, pointerLocationInScreenSpace.dy);
    canvas.drawShadow(magnifierClipPath, Colors.black, 16, false);
    canvas.drawRRect(magnifierClipRect, magnifierBackgroundPaint);
    canvas.drawRRect(magnifierClipRect.inflate(0.5 / scale), magnifierBorderPaint);
    canvas.clipRRect(magnifierClipRect);

    // page
    canvas.translate(
      -pointerLocationInScreenSpace.dx * magnificationFactor,
      -pointerLocationInScreenSpace.dy * magnificationFactor,
    );
    canvas.scale(magnificationFactor);
    drawPageContent(canvas, currentPage);

    canvas.restore();
  }

  void drawDocument(Canvas canvas) {
    for (final page in visiblePages) drawPageContent(canvas, page);
  }

  void drawPageContent(Canvas canvas, PageDrawingPlan page) {
    canvas.save();

    canvas.translate(page.position.left, page.position.top);
    drawPage(canvas, page);
    drawHighlightedElement(canvas, page.pageIndex);
    drawManualMeasurementResult(canvas, page.pageIndex + 1);
    drawPointerMeasurement(canvas, page.pageIndex + 1);

    canvas.restore();
  }

  Path getHighlightedAreas(int pageIndex, bool reverse) {
    if (highlightedArea == null) return Path();

    final path = Path();
    path.fillType = PathFillType.evenOdd;

    highlightedArea!
        .where((element) => element.pageNumber == pageIndex + 1)
        .map((x) => Rect.fromLTRB(x.left, x.top, x.right, x.bottom).inflate(selectionThickness / 2))
        .forEach(path.addRect);

    if (reverse) {
      final page = visiblePages.where((x) => x.pageIndex == pageIndex).first;
      final pageRect = Rect.fromLTWH(0, 0, page.position.width, page.position.height);

      path.addRect(pageRect);
    }

    return path;
  }

  void drawPage(Canvas canvas, PageDrawingPlan page) {
    // draw page shadow
    final rect = Rect.fromLTWH(0, 0, page.position.width, page.position.height);
    final path = Path()..addRect(rect);

    final pageShadowColor = Colors.black.withAlpha(128);
    canvas.drawShadow(path, pageShadowColor, 8 * scale, false);

    // draw empty page
    canvas.drawRect(rect, Paint()..color = Colors.white);

    //draw page image
    final canvasTransform = canvas.getTransform();
    final canvasScale = max(canvasTransform[0], canvasTransform[5]);
    final targetZoomLevel = calculateZoomLevelFromScale(canvasScale, isHighResolution);
    final image = documentPreviewImageCacheStateInstance.getImage(PageSnapshotIndex(page.pageIndex, targetZoomLevel));

    if (image == null) return;

    void scaleCanvasForImage() => canvas.scale(page.position.width / image.width, page.position.height / image.height);
    Paint getHighQualityPaint() => Paint()..filterQuality = FilterQuality.high;

    void drawImage() {
      canvas.save();
      scaleCanvasForImage();
      canvas.drawImage(image, Offset.zero, getHighQualityPaint());
      canvas.restore();
    }

    void drawImageWithHighlightBlur() {
      final blurSigma = 4 * sqrt(scale);

      final blurPaint = getHighQualityPaint()..imageFilter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);

      canvas.save();
      canvas.clipRect(rect);
      scaleCanvasForImage();
      canvas.drawImage(image, Offset.zero, blurPaint);
      canvas.restore();

      final clipArea = getHighlightedAreas(page.pageIndex, false);

      canvas.save();
      canvas.clipPath(clipArea);
      scaleCanvasForImage();
      canvas.drawImage(image, Offset.zero, getHighQualityPaint());
      canvas.restore();
    }

    highlightedArea == null ? drawImage() : drawImageWithHighlightBlur();
  }

  void drawHighlightedElement(Canvas canvas, int pageIndex) {
    const selectionBorderColor = Color.fromARGB(255, 0, 0, 0);
    const selectionOpaqueColor = Color.fromARGB(64, 0, 0, 0);

    if (highlightedArea == null) return;

    // draw opaque area
    final opaquePath = getHighlightedAreas(pageIndex, true);
    canvas.drawPath(opaquePath, Paint()..color = selectionOpaqueColor);

    // draw border
    final borderPaint = Paint()
      ..color = selectionBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectionThickness;

    final borderPath = getHighlightedAreas(pageIndex, false);
    canvas.drawPath(borderPath, borderPaint);
  }

  void drawPointerMeasurement(Canvas canvas, int pageNumber) {
    if (interactionType != PointerHoverInteraction.showPosition) return;

    if (measurement == null) return;

    if (measurement!.pageNumber != pageNumber) return;

    final measurementPoint = measurement!.point;

    if (measurementPoint == null) return;

    // draw targetPoint
    final targetPointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final relatedRectanglePaint = Paint()
      ..color = Colors.red.withAlpha(64)
      ..style = PaintingStyle.fill;

    final relatedRectangleBorderPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1 / scale
      ..style = PaintingStyle.stroke;

    final targetPointRadius = 5 / scale;
    canvas.drawCircle(measurementPoint.point, targetPointRadius, targetPointPaint);
    canvas.drawRect(measurementPoint.relatedRect, relatedRectanglePaint);
    canvas.drawRect(measurementPoint.relatedRect, relatedRectangleBorderPaint);

    // build text
    final paragraphStyle = ParagraphStyle(
      textAlign: TextAlign.start,
      fontSize: 14,
      maxLines: 10,
      height: 1.75,
      textHeightBehavior: TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
    );

    final labelStyle = ui.TextStyle(color: Colors.white.withAlpha(196));
    final valueStyle = ui.TextStyle(color: Colors.white);

    final paragraphBuilder = ParagraphBuilder(paragraphStyle);
    paragraphBuilder.pushStyle(labelStyle);
    paragraphBuilder.addText("Page: ");

    paragraphBuilder.pushStyle(valueStyle);
    paragraphBuilder.addText("${pointerLocation!.pageNumber}\n");

    paragraphBuilder.pushStyle(labelStyle);
    paragraphBuilder.addText("X: ");

    paragraphBuilder.pushStyle(valueStyle);
    paragraphBuilder.addText("${measurementPoint.point.dx.toStringAsFixed(1)}\n");

    paragraphBuilder.pushStyle(labelStyle);
    paragraphBuilder.addText("Y: ");

    paragraphBuilder.pushStyle(valueStyle);
    paragraphBuilder.addText(measurementPoint.point.dy.toStringAsFixed(1));

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 300));

    final paragraphSize = Rect.fromLTWH(0, 0, paragraph.maxIntrinsicWidth, paragraph.height);

    const paddingVertical = 8;
    const paddingHorizontal = 12;

    final tooltipArea = Rect.fromLTRB(
      paragraphSize.left - paddingHorizontal,
      paragraphSize.top - paddingVertical,
      paragraphSize.right + paddingHorizontal,
      paragraphSize.bottom + paddingVertical,
    );

    // draw label
    final labelPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final center = Offset(pointerLocation!.x, pointerLocation!.y);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1 / scale);
    canvas.translate(paddingHorizontal * 3, -tooltipArea.height / 2);
    canvas.drawRRect(ui.RRect.fromRectAndRadius(tooltipArea, const ui.Radius.circular(6)), labelPaint);
    canvas.drawParagraph(paragraph, const ui.Offset(0, 0));
    canvas.restore();
  }

  void drawManualMeasurementResult(Canvas canvas, int pageNumber) {
    if (interactionType != PointerHoverInteraction.measureHorizontal &&
        interactionType != PointerHoverInteraction.measureVertical)
      return;

    if (measurement == null) return;

    if (measurement!.pageNumber != pageNumber) return;

    if (pointerLocation == null) return;

    final isVertical = interactionType == PointerHoverInteraction.measureVertical;
    final axis = isVertical ? measurement!.vertical : measurement!.horizontal;

    // draw related elements
    void drawRelatedElement(Rect? rect) {
      final relatedElementPaint = Paint()
        ..color = Colors.red.withAlpha(64)
        ..style = PaintingStyle.fill;

      final relatedElementBorderPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 1 / scale
        ..style = PaintingStyle.stroke;

      if (rect == null) return;

      canvas.drawRect(rect, relatedElementPaint);
      canvas.drawRect(rect, relatedElementBorderPaint);
    }

    drawRelatedElement(axis.relatedElementBegin);

    if (axis.relatedElementBegin != axis.relatedElementEnd) drawRelatedElement(axis.relatedElementEnd);

    // draw measurement line and arms
    final linePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0 / scale;

    final path = Path();
    path.moveTo(axis.begin.dx, axis.begin.dy);
    path.lineTo(axis.end.dx, axis.end.dy);

    final armSize = 10 / scale;

    if (measurement != null && isVertical) {
      path.moveTo(axis.begin.dx - armSize, axis.begin.dy);
      path.lineTo(axis.begin.dx + armSize, axis.begin.dy);

      path.moveTo(axis.end.dx - armSize, axis.end.dy);
      path.lineTo(axis.end.dx + armSize, axis.end.dy);
    }

    if (measurement != null && !isVertical) {
      path.moveTo(axis.begin.dx, axis.begin.dy - armSize);
      path.lineTo(axis.begin.dx, axis.begin.dy + armSize);

      path.moveTo(axis.end.dx, axis.end.dy - armSize);
      path.lineTo(axis.end.dx, axis.end.dy + armSize);
    }

    canvas.drawPath(path, linePaint);

    // create label
    final paragraphStyle = ParagraphStyle(textAlign: TextAlign.start, fontSize: 14, maxLines: 1);

    final paragraphBuilder = ParagraphBuilder(paragraphStyle);
    paragraphBuilder.pushStyle(ui.TextStyle(color: Colors.white));
    paragraphBuilder.addText(axis.length.toStringAsFixed(1));

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 100));

    final paragraphSize = Rect.fromLTWH(0, 0, paragraph.maxIntrinsicWidth, paragraph.height);

    const paddingVertical = 8;
    const paddingHorizontal = 12;

    final tooltipArea = Rect.fromLTRB(
      paragraphSize.left - paddingHorizontal,
      paragraphSize.top - paddingVertical,
      paragraphSize.right + paddingHorizontal,
      paragraphSize.bottom + paddingVertical,
    );

    // offset label when measurement line is small compared to label
    const labelOffsetAxis = 10;

    var labelPosition = Offset.zero; // document space
    var labelOffset = Offset.zero; // screen space

    if (isVertical) {
      labelPosition = Offset(axis.begin.dx, pointerLocation!.y);
      labelOffset = Offset(-tooltipArea.width / 2 - labelOffsetAxis, 0);
    }

    if (!isVertical) {
      labelPosition = Offset(pointerLocation!.x, axis.begin.dy);
      labelOffset = Offset(0, -tooltipArea.height / 2 - labelOffsetAxis);
    }

    // draw label
    final labelPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(labelPosition.dx, labelPosition.dy);
    canvas.scale(1 / scale);
    canvas.translate(-paragraphSize.width / 2, -paragraph.height / 2);
    canvas.translate(labelOffset.dx, labelOffset.dy);
    canvas.drawRRect(ui.RRect.fromRectAndRadius(tooltipArea, const ui.Radius.circular(6)), labelPaint);
    canvas.drawParagraph(paragraph, const ui.Offset(0, 0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

enum PointerHoverInteraction { none, zoom, showPosition, measureVertical, measureHorizontal }

class PageDrawingPlan {
  int pageIndex;
  Rect position;

  PageDrawingPlan({required this.pageIndex, required this.position});
}

int calculateZoomLevelFromScale(double scale, bool isHighResolution) {
  const maxScale = 3; // to not render too big images
  return min(maxScale, log(scale) / log(2) + (isHighResolution ? 1 : 0)).ceil();
}
