import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../document_hierarchy/models/document_structure_page_size.dart';
import '../../document_hierarchy/models/page_snapshot_index.dart';
import '../models/page_snapshot_rendered.dart';

final documentPreviewImageCacheStateInstance = DocumentPreviewImageCacheState();
final documentPreviewImageCacheStateProvider = ChangeNotifierProvider((ref) => documentPreviewImageCacheStateInstance);

class DocumentPreviewImageCacheState extends ChangeNotifier {
  int refreshId = 0;
  List<DocumentStructurePageSize> pages = [];

  bool isImagesCacheInvalidated = false;
  final Map<String, ui.Image> images = {};

  List<PageSnapshotIndex> neededImages = [];

  static String _cacheKey(int pageIndex, int zoomLevel) => "${pageIndex}_$zoomLevel";

  void updateDocumentStructure(List<DocumentStructurePageSize> newPages) {
    refreshId++;

    pages = newPages;

    neededImages = [];
    isImagesCacheInvalidated = true;

    notifyListeners();
  }

  void updateNeededImages(List<PageSnapshotIndex> indexes) {
    neededImages = indexes;
  }

  List<PageSnapshotIndex> getNeededImages() {
    final imagesToRequest = neededImages
        .where((x) => isImagesCacheInvalidated || !images.containsKey(_cacheKey(x.pageIndex, x.zoomLevel)))
        .toList();

    neededImages = [];
    return imagesToRequest;
  }

  Future<void> addImages(List<PageSnapshotRendered> imagesToAdd) async {
    if (isImagesCacheInvalidated) {
      final imagesToClear = images.values.toList();
      images.clear();

      Future.microtask(() {
        for (final image in imagesToClear) {
          image.dispose();
        }
      });

      isImagesCacheInvalidated = false;
    }

    for (final image in imagesToAdd) {
      final codec = await instantiateImageCodec(image.imageData);
      final frame = await codec.getNextFrame();

      images[_cacheKey(image.pageIndex, image.zoomLevel)] = frame.image;
    }

    notifyListeners();
  }

  // until the requested zoom level is rendered, the closest available one stands in, sharper levels first
  ui.Image? getImage(PageSnapshotIndex index) {
    final zoomLevels = [
      for (var i = 0; i < 10; i++) index.zoomLevel + i,
      for (var i = 1; i < 10; i++) index.zoomLevel - i,
    ];

    return zoomLevels.map((zoomLevel) => images[_cacheKey(index.pageIndex, zoomLevel)]).nonNulls.firstOrNull;
  }
}
