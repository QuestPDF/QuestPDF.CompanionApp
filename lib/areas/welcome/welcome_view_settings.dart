import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/font_awesome_icons.dart';
import '../../shared/open_source_code_path_in_editor.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/popover_decoration.dart';
import '../application/state/application_state_provider.dart';
import 'welcome_view_button.dart';

class WelcomeViewSettings extends ConsumerStatefulWidget {
  const WelcomeViewSettings({super.key});

  @override
  ConsumerState<WelcomeViewSettings> createState() => _WelcomeViewSettingsState();
}

class _WelcomeViewSettingsState extends ConsumerState<WelcomeViewSettings> {
  static const double controlHeight = 30;
  static const double menuWidth = 140;
  static const double menuPadding = 5;

  static final borderlessInput = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide.none,
  );

  late final TextEditingController portController;

  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    final port = ref.read(applicationStateProvider).communicationPort;
    portController = TextEditingController(text: port.toString());
  }

  @override
  void dispose() {
    portController.dispose();
    super.dispose();
  }

  void applyPort() {
    final port = ApplicationStateProvider.sanitizePortNumber(portController.text);
    portController.text = port.toString();
    applicationStateProviderInstance.changeCommunicationPort(port);
  }

  @override
  Widget build(BuildContext context) {
    final options = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          buildRow("Theme", buildThemeChoice()),
          buildRow("Code editor", buildCodeEditorChoice()),
          buildRow("Connection port", buildPortField()),
        ],
      ),
    );

    return Column(
      children: [
        WelcomeViewButton(
          icon: FontAwesomeIcons.gear,
          label: "Settings",
          trailingIcon: isExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.chevronDown,
          showsTrailingIconOnHoverOnly: false,
          onClick: () => setState(() => isExpanded = !isExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isExpanded ? options : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  // the labels line up with the "Settings" label above
  Widget buildRow(String label, Widget control) {
    final labelStyle = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: context.appColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 20, top: 6, bottom: 6),
      child: Row(
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 20),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: control),
          ),
        ],
      ),
    );
  }

  Widget buildThemeChoice() {
    final themeMode = ref.watch(applicationStateProvider.select((x) => x.themeMode));

    String getThemeName(ThemeMode mode) {
      return switch (mode) {
        ThemeMode.system => "System",
        ThemeMode.light => "Light",
        ThemeMode.dark => "Dark",
      };
    }

    return buildMenu(ThemeMode.values, themeMode, getThemeName, applicationStateProviderInstance.changeThemeMode);
  }

  Widget buildCodeEditorChoice() {
    final defaultCodeEditor = ref.watch(applicationStateProvider.select((x) => x.defaultCodeEditor));

    return buildMenu(
      CodeEditor.values,
      defaultCodeEditor,
      getEditorName,
      applicationStateProviderInstance.changeDefaultCodeEditor,
    );
  }

  // a compact menu instead of the Material dropdown, whose button and items are too tall for this card
  Widget buildMenu<T>(List<T> values, T selected, String Function(T) getName, void Function(T) onSelected) {
    final colors = context.appColors;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textPrimary);

    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colors.popover),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(PopoverDecoration.elevation),
      shadowColor: WidgetStatePropertyAll(colors.shadow),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(menuPadding)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.popover),
          side: BorderSide(color: colors.border),
        ),
      ),
    );

    Widget buildItem(T value) {
      final isSelected = value == selected;

      return MenuItemButton(
        onPressed: () => onSelected(value),
        style: ButtonStyle(
          // the compact density of the theme would squeeze the items below the height of the controls
          visualDensity: VisualDensity.standard,
          fixedSize: const WidgetStatePropertyAll(Size.fromWidth(menuWidth - 2 * menuPadding)),
          minimumSize: const WidgetStatePropertyAll(Size(menuWidth - 2 * menuPadding, controlHeight)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control))),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return colors.hover.withValues(alpha: colors.hover.a * 2);
            if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return colors.hover;
            return null;
          }),
          splashFactory: NoSplash.splashFactory,
        ),
        trailingIcon: Icon(FontAwesomeIcons.check, size: 12, color: isSelected ? colors.accent : Colors.transparent),
        child: Text(getName(value), style: textStyle?.copyWith(fontWeight: isSelected ? FontWeight.w500 : null)),
      );
    }

    // opens the list right-aligned to the box, so it does not overhang the card
    void openMenu(BuildContext anchorContext, MenuController controller) {
      final anchorWidth = (anchorContext.findRenderObject() as RenderBox).size.width;
      controller.open(position: Offset(anchorWidth - menuWidth, controlHeight + 6));
    }

    return MenuAnchor(
      style: menuStyle,
      menuChildren: values.map(buildItem).toList(),
      builder: (context, controller, child) {
        return InkWell(
          onTap: () => controller.isOpen ? controller.close() : openMenu(context, controller),
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Container(
            height: controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.control), color: colors.fill),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(getName(selected), style: textStyle),
                const SizedBox(width: 8),
                Icon(FontAwesomeIcons.chevronDown, size: 10, color: colors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildPortField() {
    return SizedBox(
      width: 72,
      height: controlHeight,
      child: TextField(
        controller: portController,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        textAlignVertical: TextAlignVertical.center,
        expands: true,
        maxLines: null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: context.appColors.fill,
          border: borderlessInput,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide(color: context.appColors.accent),
          ),
        ),
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
          applyPort();
        },
        onSubmitted: (_) => applyPort(),
      ),
    );
  }
}
