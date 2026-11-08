import 'package:flutter/widgets.dart';

@immutable
class DocumentPreviewToolbarItem {
  final Widget child;
  final double? maxWidth;

  const DocumentPreviewToolbarItem({required this.child, this.maxWidth});
}

// Each control group has its own row and stays compact on wide windows.
class DocumentPreviewToolbarLayout extends StatelessWidget {
  static const double searchWidth = 360;
  static const double layoutErrorWidth = 300;
  static const double detailsWidth = 1000;

  final List<DocumentPreviewToolbarItem> items;
  final Color dividerColor;

  const DocumentPreviewToolbarLayout({super.key, required this.items, required this.dividerColor})
    : assert(items.length > 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0)
            SizedBox(
              key: ValueKey(index == 1 ? 'preview-toolbar-divider' : 'preview-toolbar-divider-$index'),
              height: 1,
              child: ColoredBox(color: dividerColor),
            ),
          Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: items[index].maxWidth ?? double.infinity),
              child: items[index].child,
            ),
          ),
        ],
      ],
    );
  }
}
