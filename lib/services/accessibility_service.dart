import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../src/core/accessibility/accessibility_settings.dart';

class AccessibilityService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<AccessibilitySettings> loadForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return AccessibilitySettings.defaults();

    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();

    return AccessibilitySettings.fromMap(data);
  }

  Future<void> saveForCurrentUser(AccessibilitySettings settings) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('users').doc(user.uid).set(
      settings.toMap(),
      SetOptions(merge: true),
    );
  }
}