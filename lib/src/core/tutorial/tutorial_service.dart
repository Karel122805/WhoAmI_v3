import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const _key = "tutorial_seen_";

  static Future<bool> hasSeen(String screen) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("$_key$screen") ?? false;
  }

  static Future<void> markSeen(String screen) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("$_key$screen", true);
  }
}






