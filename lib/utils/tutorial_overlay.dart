import 'package:flutter/material.dart';
import '../widgets/mascot_intro.dart';

class TutorialOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, String message, VoidCallback onClose) {
    if (_entry != null) return; // evita duplicados

    _entry = OverlayEntry(
      builder: (_) => MascotIntro(
        message: message,
        onClose: () {
          hide();
          onClose();
        },
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}
