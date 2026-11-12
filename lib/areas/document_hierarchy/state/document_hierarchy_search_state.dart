import 'dart:math';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/document_hierarchy_element.dart';
import 'document_hierarchy_provider.dart';

final documentHierarchySearchStateInstance = DocumentHierarchySearchState();
final documentHierarchySearchStateProvider = ChangeNotifierProvider((ref) => documentHierarchySearchStateInstance);

class SearchCacheItem {
  String text;
  DocumentHierarchyElement element;

  SearchCacheItem(this.text, this.element);
}

class DocumentHierarchySearchState extends ChangeNotifier {
  String? searchPhrase;
  List<SearchCacheItem>? searchableElements;
  List<SearchCacheItem>? searchableElementsForCurrentPhrase;
  List<DocumentHierarchyElement> searchResults = [];
  int searchResultIndex = 0;

  // set by the search field, so the shortcut can move focus back to it without touching the phrase
  VoidCallback? onFocusRequested;

  void focusSearchField() => onFocusRequested?.call();

  bool get showSearchCount => (searchPhrase?.isNotEmpty ?? false) && searchResults.isNotEmpty;

  void reset() {
    searchPhrase = null;
    searchResultIndex = 0;
    searchResults = [];

    searchableElements = null;
    searchableElementsForCurrentPhrase = null;

    focusOnCurrentSearchResult();
    notifyListeners();
  }

  void update(String? phrase) {
    if (phrase != null && searchPhrase != null && !phrase.contains(searchPhrase!)) {
      searchableElementsForCurrentPhrase = null;
    }

    searchPhrase = phrase;
    searchResultIndex = 0;
    searchResults = [];

    search();

    focusOnCurrentSearchResult();
    notifyListeners();
  }

  void accept() {
    searchableElementsForCurrentPhrase = null;

    searchPhrase = null;
    searchResultIndex = 0;
    searchResults = [];

    notifyListeners();
  }

  List<SearchCacheItem> getSearchableElements() {
    final root = documentHierarchyProviderInstance.root;

    if (root == null) return [];

    const searchableElementTypes = ["TextBlock", "DebugPointer"];

    return root.selfAndDescendants
        .where((x) => searchableElementTypes.contains(x.elementType) && x.searchableContent.isNotNullOrEmpty)
        .map((x) => SearchCacheItem(x.searchableContent!.toLowerCase(), x))
        .toList();
  }

  void search() {
    if (searchPhrase.isNullOrEmpty) return;

    final phrase = searchPhrase!.toLowerCase();
    searchableElements ??= getSearchableElements();
    searchableElementsForCurrentPhrase ??= searchableElements;

    searchableElementsForCurrentPhrase = searchableElementsForCurrentPhrase!
        .where((x) => x.text.contains(phrase))
        .toList();
    searchResults = searchableElementsForCurrentPhrase!.map((x) => x.element).distinct().toList();
  }

  void changeCurrentSearchIndex(int direction) {
    searchResultIndex = (searchResultIndex + direction) % max(1, searchResults.length);
    focusOnCurrentSearchResult();
    notifyListeners();
  }

  void focusOnCurrentSearchResult() {
    if (searchResults.isEmpty) {
      documentHierarchyProviderInstance.setSelectedElement(null);
    } else {
      documentHierarchyProviderInstance.setSelectedElementAndFocusOnIt(searchResults[searchResultIndex]);
    }
  }
}
