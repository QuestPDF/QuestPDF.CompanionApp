import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/font_awesome_icons.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/popover_decoration.dart';
import 'application_titlebar_indicator.dart';

class ApplicationTitlebarCardAction {
  final String label;
  final String url;

  const ApplicationTitlebarCardAction({required this.label, required this.url});

  void open() => launchUrl(Uri.parse(url));
}

// a title bar indicator that opens an explanatory card when hovered
class ApplicationTitlebarCard extends StatelessWidget {
  static const double width = 380;

  final IconData icon;
  final StatusTone tone;
  final String label;
  final bool showLabel;

  final String title;
  final List<String> content;

  // a terminal command shown below the content
  final String? code;

  final ApplicationTitlebarCardAction? action;

  const ApplicationTitlebarCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    this.showLabel = true,
    required this.title,
    required this.content,
    this.code,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      richMessage: WidgetSpan(child: IntrinsicWidth(child: buildCard(context))),
      padding: EdgeInsets.zero,
      enableTapToDismiss: false,
      decoration: const BoxDecoration(),
      exitDuration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: ApplicationTitlebarIndicator(
          icon: icon,
          tone: tone,
          label: label,
          showLabel: showLabel,
          onPressed: action?.open,
        ),
      ),
    );
  }

  Widget buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(color: colors.textPrimary);
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(color: colors.textSecondary);

    return Container(
      constraints: const BoxConstraints(maxWidth: width),
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(24),
      decoration: PopoverDecoration(colors),
      // the tooltip overlay has no Material of its own, which the link below needs
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: titleStyle),
            for (final paragraph in content)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(paragraph, style: contentStyle),
              ),
            if (code != null) buildCode(context, code!),
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _ApplicationTitlebarCardLink(action: action!),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildCode(BuildContext context, String code) {
    final colors = context.appColors;
    final codeStyle = TextStyle(fontFamily: codeFontFamily, fontSize: 12, height: 1.4, color: colors.textPrimary);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colors.border),
      ),
      // a command wrapped at a hyphen reads as two, so it stays on one line
      child: Text.rich(
        softWrap: false,
        overflow: TextOverflow.fade,
        TextSpan(
          style: codeStyle,
          children: [
            TextSpan(
              text: "\$ ",
              style: TextStyle(color: colors.textMuted),
            ),
            TextSpan(text: code),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTitlebarCardLink extends StatefulWidget {
  final ApplicationTitlebarCardAction action;

  const _ApplicationTitlebarCardLink({required this.action});

  @override
  State<_ApplicationTitlebarCardLink> createState() => _ApplicationTitlebarCardLinkState();
}

class _ApplicationTitlebarCardLinkState extends State<_ApplicationTitlebarCardLink> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.accent;

    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: color,
      decoration: isHovered ? TextDecoration.underline : TextDecoration.none,
      decorationColor: color,
    );

    return InkWell(
      onTap: widget.action.open,
      onHover: (value) => setState(() => isHovered = value),
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.action.label, style: textStyle),
            const SizedBox(width: 6),
            Icon(FontAwesomeIcons.externalLink, size: 11, color: color),
          ],
        ),
      ),
    );
  }
}
