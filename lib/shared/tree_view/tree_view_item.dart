import 'package:flutter/material.dart';
import 'package:questpdf_companion/shared/tree_view/tree_view.dart';
import 'package:questpdf_companion/shared/tree_view/tree_view_model.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../font_awesome_icons.dart';

class TreeViewItem<TContent> extends StatefulWidget {
  final int indentationLevel;
  final TreeViewModel<TContent> node;

  const TreeViewItem({super.key, required this.node, required this.indentationLevel});

  @override
  State<TreeViewItem<TContent>> createState() => TreeViewItemState<TContent>();
}

class TreeViewItemState<TContent> extends State<TreeViewItem<TContent>> {
  static const double indentationSize = 24;
  static const double iconSize = 16;
  static const double annotationSize = 10;

  // the dot is centered under the leading icon of the panel header, and the tree starts where the header text does
  static const double annotationSlotSize = 16;
  static const double annotationSpacing = 10;

  static const TextStyle labelStyle = TextStyle(fontWeight: FontWeight.w400);
  static const TextStyle highlightedLabelStyle = TextStyle(fontWeight: FontWeight.w500);

  // dark text on a light background reads thinner, so highlighted labels get one weight step more
  static const TextStyle highlightedLabelStyleLight = TextStyle(fontWeight: FontWeight.w600);

  static const TextStyle hintStyle = TextStyle(fontWeight: FontWeight.w300);

  static const double lowEmphasisOpacity = 0.5;

  bool isDimmed = false;
  bool isHovered = false;

  TreeViewModel<TContent> get node => widget.node;

  int get indentationLevel => widget.indentationLevel;

  @override
  void initState() {
    super.initState();
    refreshState();

    node.notifier?.addListener(refreshState);
  }

  @override
  void dispose() {
    node.notifier?.removeListener(refreshState);
    super.dispose();
  }

  void refreshState() {
    Future(() {
      final isDimmedNext = node.isDimmed(node.content);

      if (isDimmed == isDimmedNext) return;

      if (!mounted) return;

      setState(() {
        isDimmed = isDimmedNext;
      });
    });
  }

  bool get isEmphasized => !isDimmed || isHovered;

  Color withEmphasis(Color color) => isEmphasized ? color : color.withValues(alpha: color.a * lowEmphasisOpacity);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: buildContentRow(),
    );
  }

  Widget buildContentRow() {
    final row = ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Row(children: [buildAnnotation(), ...buildTree(), buildLabel(), buildHint()]),
    );

    if (!isHovered && !node.isSelected) return row;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        buildHighlight(),
        Center(child: row),
      ],
    );
  }

  Widget buildHighlight() {
    const horizontalSpacing = -6.0;

    return Positioned(
      top: 0,
      bottom: 0,
      left: horizontalSpacing,
      right: horizontalSpacing,
      child: Container(
        decoration: BoxDecoration(
          color: getHighlightColor(),
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.small)),
        ),
      ),
    );
  }

  Color getContentColor() {
    final color = node.isHighlighted ? context.appColors.highlight : context.appColors.textPrimary;
    return withEmphasis(color);
  }

  Color? getHighlightColor() {
    final colors = context.appColors;

    if (node.isSelected) return colors.treeSelection;

    if (isHovered) return colors.hover;

    return null;
  }

  // each indentation level, disclosure chevron and folder icon occupies one slot,
  // so the guide of a folder lines up with the chevrons and icons of its children
  List<Widget> buildTree() {
    final isFolderChild = node.parent?.isFolder ?? false;
    final chevronIcon = node.isExpanded ? FontAwesomeIcons.angleDown : FontAwesomeIcons.angleRight;
    final folderIcon = node.isExpanded ? FontAwesomeIcons.folderOpen : FontAwesomeIcons.folderClosed;

    return [
      for (var i = 0; i < indentationLevel; i++) buildIndentationGuide(),
      if (isFolderChild && node.children.isNotEmpty)
        buildSlot(Icon(chevronIcon, size: iconSize, color: withEmphasis(context.appColors.textSecondary))),
      if (isFolderChild && node.children.isEmpty) buildIndentationGuide(),
      if (node.isFolder) buildSlot(Icon(folderIcon, size: iconSize, color: getContentColor())),
    ];
  }

  Widget buildSlot(Widget icon) {
    return SizedBox(
      width: indentationSize,
      child: Align(alignment: Alignment.centerLeft, child: icon),
    );
  }

  Widget buildIndentationGuide() {
    return SizedBox(
      width: indentationSize,
      height: TreeView.itemHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 1,
          margin: const EdgeInsets.only(left: (iconSize - 1) / 2),
          color: context.appColors.border,
        ),
      ),
    );
  }

  Widget buildAnnotation() {
    final annotationColor = node.annotationColor;

    if (annotationColor == null) return const SizedBox();

    if (annotationColor == Colors.transparent) return const SizedBox(width: annotationSlotSize + annotationSpacing);

    return Container(
      width: annotationSize,
      height: annotationSize,
      margin: const EdgeInsets.only(
        left: (annotationSlotSize - annotationSize) / 2,
        right: (annotationSlotSize - annotationSize) / 2 + annotationSpacing,
      ),
      decoration: BoxDecoration(
        color: isDimmed ? annotationColor.withValues(alpha: lowEmphasisOpacity) : annotationColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget buildLabel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightedStyle = isDark ? highlightedLabelStyle : highlightedLabelStyleLight;
    final targetLabelStyle = node.isHighlighted ? highlightedStyle : labelStyle;

    return Text(node.label, style: targetLabelStyle.copyWith(color: getContentColor()));
  }

  Widget buildHint() {
    final showHint = node.hint != null && (node.isHintImportant || isHovered || node.isSelected);

    if (!showHint) return const SizedBox();

    final isHintEmphasized = isHovered || node.isSelected;
    final hintColor = context.appColors.textPrimary.withValues(alpha: isHintEmphasized ? 1 : lowEmphasisOpacity);

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          node.hint!,
          style: hintStyle.copyWith(color: hintColor),
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.fade,
        ),
      ),
    );
  }
}
