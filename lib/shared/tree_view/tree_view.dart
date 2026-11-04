import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:questpdf_companion/shared/tree_view/tree_view_item.dart';
import 'package:questpdf_companion/shared/tree_view/tree_view_model.dart';

class TreeViewVisibleItem<TContent> {
  final TreeViewModel<TContent> viewModel;
  final int indentationLevel;

  TreeViewVisibleItem(this.viewModel, this.indentationLevel);
}

class TreeView<TContent> extends ConsumerWidget {
  final TreeViewModel<TContent> rootNode;
  final TContent? selectedElementContent;
  final Function(TContent? content)? onHover;

  const TreeView({super.key, required this.rootNode, required this.selectedElementContent, this.onHover});

  static const itemHeight = 24.0;
  static final scrollController = ScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleItems = listVisibleItems();

    Future(() {
      if (!scrollController.hasClients) return;

      if (selectedElementContent != null) {
        final selectedElementIndex = visibleItems.indexWhere((x) => x.viewModel.content == selectedElementContent);
        final elementOffset = selectedElementIndex * itemHeight;

        final targetPositionStart = scrollController.offset + scrollController.position.viewportDimension / 8;
        final targetPositionEnd = scrollController.offset + scrollController.position.viewportDimension * 7 / 8;

        if (elementOffset < targetPositionStart || elementOffset > targetPositionEnd) {
          final targetPosition = selectedElementIndex * itemHeight - scrollController.position.viewportDimension / 2;
          scrollController.animateTo(targetPosition, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
        }
      }
    });

    return ListView.builder(
      controller: scrollController,
      itemCount: visibleItems.length,
      physics: const ClampingScrollPhysics(),
      shrinkWrap: true,
      // the left inset matches the panel headers above
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      prototypeItem: const SizedBox(height: itemHeight),
      itemBuilder: (context, index) {
        return buildItem(visibleItems[index]);
      },
    );
  }

  Widget buildItem(TreeViewVisibleItem<TContent> activeItem) {
    final node = activeItem.viewModel;
    final indentationLevel = activeItem.indentationLevel;

    return MouseRegion(
      onEnter: (_) => onHover?.call(node.content),
      onExit: (_) => onHover?.call(null),
      child: GestureDetector(
        onTap: node.onClick,
        child: TreeViewItem(node: node, indentationLevel: indentationLevel),
      ),
    );
  }

  List<TreeViewVisibleItem<TContent>> listVisibleItems() {
    List<TreeViewVisibleItem<TContent>> result = [];
    var indentationLevel = 0;

    void traverse(TreeViewModel<TContent> node) {
      result.add(TreeViewVisibleItem(node, indentationLevel));

      if (!node.isExpanded) return;

      var nestingChange = 0;

      if (node.isExpandable && node.isSingleChildContainer) nestingChange = 1;

      if (node.isFolder && (node.parent?.isFolder ?? false)) nestingChange = 1;

      indentationLevel += nestingChange;
      node.children.forEach(traverse);
      indentationLevel -= nestingChange;
    }

    traverse(rootNode);
    return result;
  }
}
