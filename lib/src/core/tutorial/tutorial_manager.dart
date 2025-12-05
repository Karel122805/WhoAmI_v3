import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whoami_app/widgets/mascot_intro.dart';
import 'tutorial_keys.dart';
import 'tutorial_messages.dart';

class TutorialManager {
  static const _prefix = "tutorial_seen_";

  static Future<bool> _hasSeen(TutorialKey key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("$_prefix${key.name}") ?? false;
  }

  static Future<void> _setSeen(TutorialKey key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("$_prefix${key.name}", true);
  }

  static Future<void> maybeShow(BuildContext context, TutorialKey key) async {
    final seen = await _hasSeen(key);
    if (seen) return;

    final message = TutorialMessages.getMessage(key);

    await Future.delayed(const Duration(milliseconds: 300));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return MascotIntro(
          message: message,
          onClose: () {
            Navigator.of(context).pop();
            _setSeen(key);
          },
        );
      },
    );
  }
}
