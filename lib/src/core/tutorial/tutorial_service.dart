// lib/src/core/tutorial/tutorial_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  const TutorialService._();

  static const String _caregiverHomeKey = 'caregiver_home';
  static const String _consultantHomeKey = 'consultant_home';

  static String _storageKey(String tutorialName) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    return 'tutorial_seen_${uid}_$tutorialName';
  }

  static Future<bool> hasSeen(String tutorialName) async {
    final preferences = await SharedPreferences.getInstance();

    return preferences.getBool(
          _storageKey(tutorialName),
        ) ??
        false;
  }

  static Future<void> markSeen(String tutorialName) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(
      _storageKey(tutorialName),
      true,
    );
  }

  static Future<void> reset(String tutorialName) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(
      _storageKey(tutorialName),
    );
  }

  static Future<void> resetAllForCurrentUser() async {
    final preferences = await SharedPreferences.getInstance();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    final keysToRemove = preferences
        .getKeys()
        .where(
          (key) => key.startsWith('tutorial_seen_${uid}_'),
        )
        .toList();

    for (final key in keysToRemove) {
      await preferences.remove(key);
    }
  }

  static Future<bool> hasSeenCaregiverHome() {
    return hasSeen(_caregiverHomeKey);
  }

  static Future<void> markCaregiverHomeSeen() {
    return markSeen(_caregiverHomeKey);
  }

  static Future<void> resetCaregiverHome() {
    return reset(_caregiverHomeKey);
  }

  static Future<bool> hasSeenConsultantHome() {
    return hasSeen(_consultantHomeKey);
  }

  static Future<void> markConsultantHomeSeen() {
    return markSeen(_consultantHomeKey);
  }

  static Future<void> resetConsultantHome() {
    return reset(_consultantHomeKey);
  }
}