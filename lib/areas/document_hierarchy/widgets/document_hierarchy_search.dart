import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../shared/keyboard_shortcuts.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../state/document_hierarchy_search_state.dart';

class DocumentHierarchySearch extends ConsumerStatefulWidget {
  const DocumentHierarchySearch({super.key});

  @override
  ConsumerState<DocumentHierarchySearch> createState() => _DocumentHierarchySearchState();
}

class _DocumentHierarchySearchState extends ConsumerState<DocumentHierarchySearch> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    requestSearchFocus();
  }

  @override
  void activate() {
    super.activate();
    requestSearchFocus();
  }

  void requestSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(documentHierarchySearchStateProvider);

    final theme = Theme.of(context);
    final colors = context.appColors;

    final searchFieldStyle = theme.textTheme.bodyMedium?.copyWith(color: colors.textPrimary);
    final counterStyle = theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary, fontFeatures: tabularFigures);
    final enablePositionButtons = searchState.searchResults.isNotEmpty;

    return Container(
      height: AppSizes.barHeight,
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Row(
        children: [
          Icon(FontAwesomeIcons.search, color: colors.textSecondary, size: 16),
          const SizedBox(width: 10),
          Flexible(
            child: Focus(
              canRequestFocus: false,
              // Reserve the hierarchy shortcut for the global handler. Ctrl+B otherwise moves the caret on macOS.
              onKeyEvent: (_, event) => isControlOrCommandPressed() && event.physicalKey == PhysicalKeyboardKey.keyB
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored,
              child: TextField(
                focusNode: _focusNode,
                selectAllOnFocus: false,
                style: searchFieldStyle,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: "Search elements",
                  hintStyle: TextStyle(color: colors.textMuted),
                ),
                onChanged: (x) => Future.microtask(() => searchState.update(x)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (searchState.showSearchCount) ...[
            Text("${searchState.searchResultIndex + 1} / ${searchState.searchResults.length}", style: counterStyle),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowUp, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: enablePositionButtons ? () => searchState.changeCurrentSearchIndex(-1) : null,
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.arrowDown, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: enablePositionButtons ? () => searchState.changeCurrentSearchIndex(1) : null,
          ),
          IconButton(
            icon: const Icon(FontAwesomeIcons.close, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: searchState.reset,
          ),
        ],
      ),
    );
  }
}
