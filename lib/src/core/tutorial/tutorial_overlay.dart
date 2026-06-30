// lib/src/core/tutorial/tutorial_overlay.dart

import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/widgets/mascot_intro.dart';

class TutorialOverlay {
  const TutorialOverlay._();

  static OverlayEntry? _entry;

  static bool get isVisible => _entry != null;

  static void show({
    required BuildContext context,
    required List<String> messages,
    required VoidCallback onClose,
  }) {
    if (_entry != null || messages.isEmpty) {
      return;
    }

    final OverlayState? overlayState = Overlay.maybeOf(
      context,
      rootOverlay: true,
    );

    if (overlayState == null) {
      return;
    }

    _entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return MascotIntro(
          messages: messages,
          onClose: () {
            hide();
            onClose();
          },
        );
      },
    );

    overlayState.insert(_entry!);
  }

  static void showSingle({
    required BuildContext context,
    required String message,
    required VoidCallback onClose,
  }) {
    show(
      context: context,
      messages: <String>[message],
      onClose: onClose,
    );
  }

  static void hide() {
    final OverlayEntry? currentEntry = _entry;

    if (currentEntry == null) {
      return;
    }

    currentEntry.remove();
    currentEntry.dispose();
    _entry = null;
  }
}