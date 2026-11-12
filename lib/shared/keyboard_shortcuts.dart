import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:questpdf_companion/areas/application/state/application_state_provider.dart';

import '../areas/document_hierarchy/state/document_hierarchy_provider.dart';
import '../areas/document_hierarchy/state/document_hierarchy_search_state.dart';
import '../areas/document_hierarchy/state/document_layout_error_provider.dart';

final toggleDocumentHierarchyShortcutLabel = Platform.isMacOS ? "⌘B" : "Ctrl+B";

bool isTextInputActive() {
  final focusContext = FocusManager.instance.primaryFocus?.context;

  if (focusContext == null) return false;

  return focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

// the shortcut modifier: Ctrl, and also Cmd on macOS
bool isControlOrCommandPressed() {
  return HardwareKeyboard.instance.isControlPressed || (Platform.isMacOS && HardwareKeyboard.instance.isMetaPressed);
}

bool isCanvasNavigationByKeyboardShortcutsAvailable() {
  if (isTextInputActive()) return false;

  if (documentLayoutErrorProviderInstance.containsLayoutError) return false;

  if (documentHierarchyProviderInstance.selectedElement != null) return false;

  return true;
}

bool areCanvasKeyboardToolInteractionsAvailable() {
  if (isTextInputActive()) return false;

  return true;
}

class KeyboardShortcuts extends StatefulWidget {
  const KeyboardShortcuts({super.key});

  @override
  State<KeyboardShortcuts> createState() => KeyboardShortcutsState();
}

class KeyboardShortcutsState extends State<KeyboardShortcuts> {
  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(handleKeyInteraction);
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(handleKeyInteraction);
    super.dispose();
  }

  bool handleKeyInteraction(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isControlPressed = isControlOrCommandPressed();

    bool handleGlobalShortcuts() {
      if (kDebugMode && isControlPressed && event.physicalKey == PhysicalKeyboardKey.keyD) {
        applicationStateProviderInstance.changeThemeMode(ThemeMode.dark);
        return true;
      }

      if (kDebugMode && isControlPressed && event.physicalKey == PhysicalKeyboardKey.keyL) {
        applicationStateProviderInstance.changeThemeMode(ThemeMode.light);
        return true;
      }

      return false;
    }

    bool handlePreviewShortcuts() {
      final isPreviewMode = applicationStateProviderInstance.currentMode == ApplicationMode.documentPreview;

      if (!isPreviewMode) return false;

      // the search captures the keyboard only while its text field has focus; once focus moves elsewhere, regular shortcuts work again
      final isSearchActive = documentHierarchySearchStateInstance.searchPhrase != null && isTextInputActive();
      final isElementSelected = documentHierarchyProviderInstance.selectedElement != null;
      final documentHasLayoutErrors = documentLayoutErrorProviderInstance.containsLayoutError;

      if (isControlPressed && event.physicalKey == PhysicalKeyboardKey.keyB && (isSearchActive || !isTextInputActive())) {
        applicationStateProviderInstance.toggleDocumentHierarchyVisibility();
        return true;
      }

      if (isControlPressed &&
          event.physicalKey == PhysicalKeyboardKey.keyF &&
          documentHierarchySearchStateInstance.searchPhrase != null) {
        documentHierarchySearchStateInstance.focusSearchField();
        return true;
      }

      if (isSearchActive) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          documentHierarchySearchStateInstance.reset();
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          documentHierarchySearchStateInstance.changeCurrentSearchIndex(1);
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          documentHierarchySearchStateInstance.changeCurrentSearchIndex(-1);
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          documentHierarchySearchStateInstance.accept();
          return true;
        }

        return false;
      }

      if (isTextInputActive()) return false;

      if (isControlPressed && event.physicalKey == PhysicalKeyboardKey.keyF) {
        documentHierarchySearchStateInstance.update(null);
        Future(() => documentHierarchySearchStateInstance.update(""));
        return true;
      }

      if (documentHasLayoutErrors) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          documentLayoutErrorProviderInstance.changeSelectedErrorLayoutPage(1);
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          documentLayoutErrorProviderInstance.changeSelectedErrorLayoutPage(-1);
          return true;
        }
      }

      if (isElementSelected) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          documentHierarchyProviderInstance.setSelectedElement(null);
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          documentHierarchyProviderInstance.changeSelectedElementPageNumberVisibility(1);
          return true;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          documentHierarchyProviderInstance.changeSelectedElementPageNumberVisibility(-1);
          return true;
        }
      }

      return false;
    }

    return handleGlobalShortcuts() || handlePreviewShortcuts();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
