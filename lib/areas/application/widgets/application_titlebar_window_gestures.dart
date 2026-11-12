import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> toggleWindowMaximized() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

/// Moves the window when the title bar is dragged, and maximizes or restores it on a double click.
class ApplicationTitlebarWindowGestures extends StatefulWidget {
  const ApplicationTitlebarWindowGestures({super.key, required this.child});

  final Widget child;

  @override
  State<ApplicationTitlebarWindowGestures> createState() => _ApplicationTitlebarWindowGesturesState();
}

class _ApplicationTitlebarWindowGesturesState extends State<ApplicationTitlebarWindowGestures> {
  Offset? previousClickPosition;
  Timer? doubleClickTimer;

  @override
  void dispose() {
    doubleClickTimer?.cancel();
    super.dispose();
  }

  // Clicks are paired by hand: a double-tap recognizer would hold back every click on the title bar buttons
  // until its timeout passes. A plain tap reaches the bar only when no button under the pointer has taken it.
  void onClick(TapUpDetails details) {
    final previousPosition = previousClickPosition;
    final position = details.globalPosition;

    doubleClickTimer?.cancel();
    previousClickPosition = null;

    if (previousPosition != null && (position - previousPosition).distance <= kDoubleTapSlop) {
      onDoubleClick();
      return;
    }

    previousClickPosition = position;
    doubleClickTimer = Timer(kDoubleTapTimeout, () => previousClickPosition = null);
  }

  Future<void> onDoubleClick() async {
    // a full-screen window stays as it is, as it does when its native title bar is double clicked
    if (await windowManager.isFullScreen()) return;
    await toggleWindowMaximized();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => windowManager.startDragging(),
      onTapUp: onClick,
      child: widget.child,
    );
  }
}
