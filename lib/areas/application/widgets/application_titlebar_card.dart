import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationTitlebarCardAction {
  final String label;

  /// Either a link to open, or a callback for actions handled inside the app.
  final String? url;
  final VoidCallback? onPressed;

  const ApplicationTitlebarCardAction({required this.label, this.url, this.onPressed});
}

class ApplicationTitlebarCard extends ConsumerWidget {
  final bool isVisible;

  final IconData icon;
  final bool emphasized;
  final Color emphasisColor;

  final VoidCallback? onClicked;

  final String title;
  final List<String> content;
  final List<ApplicationTitlebarCardAction> actions;

  final double width;

  const ApplicationTitlebarCard({
    super.key,
    required this.isVisible,
    required this.icon,
    required this.emphasized,
    required this.emphasisColor,
    required this.onClicked,
    required this.title,
    required this.content,
    required this.actions,
    this.width = 300,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleTextStyle = Theme.of(context).textTheme.titleMedium;
    final contentStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline);

    Widget buildTooltipContent() {
      return Container(
        constraints: BoxConstraints(maxWidth: width),
        child: Card(
          color: Theme.of(context).cardColor,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleTextStyle),
                const SizedBox(height: 8),
                ...content.flatMap((x) => [Text(x, style: contentStyle), const SizedBox(height: 12)]),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions.map((action) {
                      final url = action.url;
                      final onPressed = action.onPressed ?? (url == null ? null : () => launchUrl(Uri.parse(url)));

                      return Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: OutlinedButton(onPressed: onPressed, child: Text(action.label)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    Widget buildIndicatorIcon() {
      final buttonStyle = ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        iconColor: WidgetStateProperty.all(Theme.of(context).colorScheme.onSurfaceVariant),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) => emphasized ? emphasisColor : null),
      );

      final iconColor = emphasized ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;

      return Padding(
        padding: EdgeInsets.only(left: emphasized ? 16 : 8, right: emphasized ? 2 : 0),
        child: IconButton(
          icon: Icon(icon, color: iconColor, size: 20),
          visualDensity: VisualDensity.standard,
          padding: EdgeInsets.all(4),
          style: buttonStyle,
          onPressed: onClicked,
        ),
      );
    }

    return Visibility(
      visible: isVisible,
      child: Tooltip(
        richMessage: WidgetSpan(child: IntrinsicWidth(child: buildTooltipContent())),
        padding: EdgeInsets.zero,
        enableTapToDismiss: false,
        decoration: const BoxDecoration(),
        exitDuration: const Duration(milliseconds: 200),
        child: buildIndicatorIcon(),
      ),
    );
  }
}
