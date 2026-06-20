import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemoramaProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _field = 'memoramaUnlockedLevel';
  static const int maxLevel = 3;

  Future<int> getUnlockedLevel() async {
    final user = _auth.currentUser;
    if (user == null) return 1;

    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({_field: 1}, SetOptions(merge: true));
      return 1;
    }

    final data = doc.data();
    final value = data?[_field];

    if (value == null) {
      await ref.set({_field: 1}, SetOptions(merge: true));
      return 1;
    }

    if (value is num) {
      return value.toInt().clamp(1, maxLevel);
    }

    await ref.set({_field: 1}, SetOptions(merge: true));
    return 1;
  }

  Future<void> saveUnlockedLevel(int level) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final safeLevel = level.clamp(1, maxLevel);

    await _firestore.collection('users').doc(user.uid).set({
      _field: safeLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> unlockNextLevel(int currentLevel) async {
    final unlocked = await getUnlockedLevel();
    final nextLevel = (currentLevel + 1).clamp(1, maxLevel);

    if (currentLevel >= unlocked && unlocked < maxLevel) {
      await saveUnlockedLevel(nextLevel);
      return nextLevel;
    }

    return unlocked;
  }
}