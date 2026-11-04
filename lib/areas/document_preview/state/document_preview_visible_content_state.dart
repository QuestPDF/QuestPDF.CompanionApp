import 'package:flutter/material.dart';

import '../../document_hierarchy/models/page_location.dart';

final documentPreviewVisibleContentStateInstance = DocumentPreviewVisibleContentState();

class DocumentPreviewVisibleContentState extends ChangeNotifier {
  List<PageLocation> visiblePageLocations = [];

  void update(List<PageLocation> locations) {
    visiblePageLocations = locations;
    notifyListeners();
  }
}
