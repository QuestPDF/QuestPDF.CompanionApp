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
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
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

  int cacheRefreshId = 0;
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

  // the canvas in screen pixels; the document is drawn with its horizontal centre at the top centre of the viewport
  Rect get viewport => (context.findRenderObject() as RenderBox?)?.paintBounds ?? Rect.zero;

  // the part of the document inside the viewport, in document coordinates
  Rect get visibleBox => ((-translate - viewport.topCenter) / scale) & (viewport.size / scale);

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
    final isControlPressed = isControlOrCommandPressed();

    // navigation: key repeats keep panning and zooming
    if (isCanvasNavigationByKeyboardShortcutsAvailable() && event is! KeyUpEvent) {
      if (isControlPressed) {
        if (event is KeyDownEvent && event.physicalKey == PhysicalKeyboardKey.keyE) {
          zoomOnPage();
          return true;
        }

        if (zoomInKeys.contains(event.physicalKey)) {
          zoomBy(keyboardZoomSensitivity, viewportCenter);
          return true;
        }

        if (zoomOutKeys.contains(event.physicalKey)) {
          zoomBy(1 / keyboardZoomSensitivity, viewportCenter);
          return true;
        }
      } else {
        final panDirection = keyboardPanDirection(event.logicalKey);

        if (panDirection != null) {
          final distance = HardwareKeyboard.instance.isShiftPressed ? keyboardPanShiftSensitivity : keyboardPanSensitivity;
          panBy(panDirection * distance);
          return true;
        }
      }
    }

    // tools: held down while hovering the canvas, released by any key up
    if (areCanvasKeyboardToolInteractionsAvailable()) {
      final interaction = event is KeyUpEvent
          ? PointerHoverInteraction.none
          : pointerHoverInteractionOf(event.physicalKey);

      if (interaction != null) {
        if (pointerHoverInteraction != interaction) setState(() => pointerHoverInteraction = interaction);
        return true;
      }
    }

    return false;
  }

  static const zoomInKeys = [PhysicalKeyboardKey.equal, PhysicalKeyboardKey.numpadAdd];
  static const zoomOutKeys = [PhysicalKeyboardKey.minus, PhysicalKeyboardKey.numpadSubtract];

  static Offset? keyboardPanDirection(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.arrowLeft => const Offset(1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(-1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, 1),
      LogicalKeyboardKey.arrowDown => const Offset(0, -1),
      _ => null,
    };
  }

  static PointerHoverInteraction? pointerHoverInteractionOf(PhysicalKeyboardKey key) {
    return switch (key) {
      PhysicalKeyboardKey.digit1 => PointerHoverInteraction.zoom,
      PhysicalKeyboardKey.digit2 => PointerHoverInteraction.showPosition,
      PhysicalKeyboardKey.digit3 => PointerHoverInteraction.measureVertical,
      PhysicalKeyboardKey.digit4 => PointerHoverInteraction.measureHorizontal,
      _ => null,
    };
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

    final box = visibleBox.inflate(visibleBox.height * visibleBoxBufferFactor);
    return pagePositions.where((x) => x.position.overlaps(box)).toList();
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

    final box = visibleBox;

    return pagePositions
        .map((x) => (page: x, intersection: x.position.intersect(box).shift(-x.position.topLeft)))
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
  }

  void handleTranslateLimits() {
    var minVerticalTranslate = -totalDocumentHeight * scale + viewport.size.height;
    final maxHorizontalOffset = (viewport.size.width / 2 - totalDocumentWidth / 2 * scale).abs();

    translate = Offset(
      translate.dx.clamp(-maxHorizontalOffset, maxHorizontalOffset),
      translate.dy.clamp(min(0, minVerticalTranslate), 0),
    );

    // scale where entire document width is visible should be centered
    final idealWidthScale = viewport.size.width / totalDocumentWidth;
    final idealHeightScale = viewport.size.height / totalDocumentHeight;

    translate = Offset(
      idealWidthScale > scale ? 0 : translate.dx,
      idealHeightScale > scale ? (viewport.size.height - totalDocumentHeight * scale) / 2 : translate.dy,
    );
  }

  Offset get viewportCenter => viewport.size.center(Offset.zero);

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
      final viewportOrigin = viewport.topCenter;
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

    if (isControlOrCommandPressed()) {
      Future(() {
        final location = documentHierarchyProviderInstance.findSourceCodeLocationOf(
          documentHierarchyProviderInstance.selectedElement,
        );

        if (location == null || !mounted) return;

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
      scale = min(viewport.size.width / location.width, viewport.size.height / location.height) / zoomScalePadding;
      scale = min(scale, maxZoom);
      translate = Offset(
        -(pagePosition.position.left + location.left + location.width / 2) * scale,
        viewport.size.height / 2 - (pagePosition.position.top + location.top + location.height / 2) * scale,
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

    final neededImages = getVisiblePages(visibleBoxBufferFactor: 1)
        .map((x) => PageSnapshotIndex(x.pageIndex, currentZoomLevel))
        .toList();

    documentPreviewImageCacheStateInstance.updateNeededImages(neededImages);
  }

  void updateCursorLocation() {
    final viewportOrigin = viewport.topCenter;

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
              backgroundColor: context.appColors.canvas,
              selectionVeilColor: Theme.of(context).brightness == Brightness.dark
                  ? DocumentPreviewPainter.darkSelectionVeilColor
                  : DocumentPreviewPainter.lightSelectionVeilColor,
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

    final doesPageCoverEntireHorizontalSpace = totalDocumentWidth * scale >= viewport.size.width;
    final isDocumentFullyVisible = totalDocumentHeight * scale <= viewport.size.height;

    if (doesPageCoverEntireHorizontalSpace || isDocumentFullyVisible) return const SizedBox();

    const scrollbarTrackPadding = 8.0;
    const minScrollbarHeight = 50.0;

    final scrollbarTrackHeight = viewport.size.height - scrollbarTrackPadding * 2 - minScrollbarHeight;
    final ratio = scrollbarTrackHeight / totalDocumentHeight / scale;

    final scrollbarStart = -translate.dy * ratio;
    final scrollbarHeight = viewport.size.height * ratio + minScrollbarHeight;

    final isScrollbarActive = scrollbarHover || scrollbarMove;
    final scrollbarColor = context.appColors.textPrimary.withAlpha(isScrollbarActive ? 100 : 64);

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

            panBy(Offset(0, -event.localDelta.dy / ratio));
          },
          child: MouseRegion(
            cursor: (scrollbarHover || scrollbarMove) ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => scrollbarHover = true),
            onExit: (_) => setState(() => scrollbarHover = false),
            child: Container(
              width: isScrollbarActive ? 8 : 6,
              height: scrollbarHeight,
              decoration: BoxDecoration(color: scrollbarColor, borderRadius: const BorderRadius.all(Radius.circular(4))),
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

    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(applyViewportChange);
        });

        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Stack(
          children: [
            Positioned.fill(child: buildPreview()),
            buildScrollbar(),
          ],
        ),
      ),
    );
  }
}

class DocumentPreviewPainter extends CustomPainter {
  final Color backgroundColor;
  final Color selectionVeilColor;
  final Offset translate;
  final double scale;
  final List<PageDrawingPlan> visiblePages;
  final bool isHighResolution;
  final List<PageLocation>? highlightedArea;
  final PointerHoverInteraction interactionType;
  final PointerLocation? pointerLocation;
  final DocumentManualMeasurementResult? measurement;

  // the page is always white, so overlays use the light palette regardless of the application theme
  static final selectionColor = AppColors.light.highlight;

  static const darkSelectionVeilColor = Color(0x66000000);
  static const lightSelectionVeilColor = Color(0x66FFFFFF);

  static const measurementColor = Color(0xFFF24822);

  double get selectionThickness => 2 / scale;

  DocumentPreviewPainter({
    required this.backgroundColor,
    required this.selectionVeilColor,
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
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // the title bar is painted before the preview, so zoomed and scrolled pages must not spill over it
    canvas.clipRect(Offset.zero & size);

    drawBackground(canvas, size);

    canvas.translate(size.width / 2, 0);
    canvas.translate(translate.dx, translate.dy);
    canvas.scale(scale);

    drawDocument(canvas);
    drawMagnification(canvas, size);

    canvas.restore();
  }

  void drawBackground(Canvas canvas, Size drawingAreaSize) {
    canvas.drawRect(Offset.zero & drawingAreaSize, Paint()..color = backgroundColor);
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
      Radius.circular(12 / scale),
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
    for (final page in visiblePages) {
      drawPageContent(canvas, page);
    }
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

    final pageShadowColor = Colors.black.withAlpha(72);
    canvas.drawShadow(path, pageShadowColor, 3 * scale, false);

    // draw empty page with a hairline edge that stays visible on dark backgrounds
    canvas.drawRect(rect, Paint()..color = Colors.white);

    final pageBorderPaint = Paint()
      ..color = Colors.black.withAlpha(24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;

    canvas.drawRect(rect.inflate(0.5 / scale), pageBorderPaint);

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
    if (highlightedArea == null) return;

    // fade the content surrounding the highlighted element
    final veilPath = getHighlightedAreas(pageIndex, true);
    canvas.drawPath(veilPath, Paint()..color = selectionVeilColor);

    // draw border
    final borderPaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectionThickness;

    final borderPath = getHighlightedAreas(pageIndex, false);
    canvas.drawPath(borderPath, borderPaint);
  }

  // the measurement overlays keep their stroke widths and labels in screen pixels, hence the divisions by the scale
  Paint get measurementFillPaint => Paint()..color = measurementColor.withAlpha(48);

  Paint get measurementStrokePaint => Paint()
    ..color = measurementColor
    ..strokeWidth = 1 / scale
    ..style = PaintingStyle.stroke;

  void drawMeasuredRect(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, measurementFillPaint);
    canvas.drawRect(rect, measurementStrokePaint);
  }

  static const labelPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);

  Size labelSizeOf(Paragraph paragraph) => labelPadding.inflateSize(Size(paragraph.maxIntrinsicWidth, paragraph.height));

  // [anchor] is in document space; the label keeps its size in screen pixels, with [labelTopLeft] relative to the anchor
  void drawLabel(Canvas canvas, Paragraph paragraph, Offset anchor, Offset labelTopLeft) {
    final labelRect = labelTopLeft & labelSizeOf(paragraph);
    final labelPaint = Paint()..color = measurementColor;

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.scale(1 / scale);
    canvas.drawRRect(RRect.fromRectAndRadius(labelRect, const Radius.circular(AppRadius.small)), labelPaint);
    canvas.drawParagraph(paragraph, labelTopLeft + labelPadding.topLeft);
    canvas.restore();
  }

  void drawPointerMeasurement(Canvas canvas, int pageNumber) {
    if (interactionType != PointerHoverInteraction.showPosition) return;

    if (measurement == null) return;

    if (measurement!.pageNumber != pageNumber) return;

    final measurementPoint = measurement!.point;

    if (measurementPoint == null) return;

    canvas.drawCircle(measurementPoint.point, 5 / scale, Paint()..color = measurementColor);
    drawMeasuredRect(canvas, measurementPoint.relatedRect);

    final paragraphStyle = ParagraphStyle(
      textAlign: TextAlign.start,
      fontFamily: appFontFamily,
      fontSize: 14,
      maxLines: 10,
      height: 1.6,
      textHeightBehavior: TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
    );

    final labelStyle = ui.TextStyle(color: Colors.white.withAlpha(196), fontFeatures: tabularFigures);
    final valueStyle = ui.TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontFeatures: tabularFigures);

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
    paragraph.layout(const ParagraphConstraints(width: 300));

    // to the right of the pointer, vertically centred on it
    final pointer = Offset(pointerLocation!.x, pointerLocation!.y);
    drawLabel(canvas, paragraph, pointer, Offset(20, -labelSizeOf(paragraph).height / 2));
  }

  void drawManualMeasurementResult(Canvas canvas, int pageNumber) {
    if (interactionType != PointerHoverInteraction.measureHorizontal &&
        interactionType != PointerHoverInteraction.measureVertical) {
      return;
    }

    if (measurement == null) return;

    if (measurement!.pageNumber != pageNumber) return;

    if (pointerLocation == null) return;

    final isVertical = interactionType == PointerHoverInteraction.measureVertical;
    final axis = isVertical ? measurement!.vertical : measurement!.horizontal;

    // the elements the line is measured between, drawn once when both ends touch the same element
    for (final rect in {axis.relatedElementBegin, axis.relatedElementEnd}.nonNulls) {
      drawMeasuredRect(canvas, rect);
    }

    // the measurement line with an arm across each end
    final linePaint = Paint()
      ..color = measurementColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0 / scale;

    final armSize = 10 / scale;
    final arm = isVertical ? Offset(armSize, 0) : Offset(0, armSize);

    final path = Path()
      ..moveTo(axis.begin.dx, axis.begin.dy)
      ..lineTo(axis.end.dx, axis.end.dy);

    for (final end in [axis.begin, axis.end]) {
      path.moveTo(end.dx - arm.dx, end.dy - arm.dy);
      path.lineTo(end.dx + arm.dx, end.dy + arm.dy);
    }

    canvas.drawPath(path, linePaint);

    final paragraphStyle = ParagraphStyle(
      textAlign: TextAlign.start,
      fontFamily: appFontFamily,
      fontSize: 14,
      maxLines: 1,
    );
    final valueStyle = ui.TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontFeatures: tabularFigures);

    final paragraphBuilder = ParagraphBuilder(paragraphStyle);
    paragraphBuilder.pushStyle(valueStyle);
    paragraphBuilder.addText(axis.length.toStringAsFixed(1));

    final paragraph = paragraphBuilder.build();
    paragraph.layout(const ParagraphConstraints(width: 100));

    // beside the line at the pointer: left of a vertical line, above a horizontal one
    const labelGap = 10.0;
    final labelSize = labelSizeOf(paragraph);

    final anchor = isVertical ? Offset(axis.begin.dx, pointerLocation!.y) : Offset(pointerLocation!.x, axis.begin.dy);
    final labelTopLeft = isVertical
        ? Offset(-labelSize.width - labelGap, -labelSize.height / 2)
        : Offset(-labelSize.width / 2, -labelSize.height - labelGap);

    drawLabel(canvas, paragraph, anchor, labelTopLeft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

enum PointerHoverInteraction { none, zoom, showPosition, measureVertical, measureHorizontal }

class PageDrawingPlan {
  final int pageIndex;
  final Rect position;

  PageDrawingPlan({required this.pageIndex, required this.position});
}

int calculateZoomLevelFromScale(double scale, bool isHighResolution) {
  const maxScale = 3; // to not render too big images
  return min(maxScale, log(scale) / log(2) + (isHighResolution ? 1 : 0)).ceil();
}
