import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BrainSaysProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _scoreField = 'brainSaysHighScore';
  static const String _levelField = 'brainSaysHighLevel';

  Future<int> getHighScore() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        _scoreField: 0,
        _levelField: 0,
      }, SetOptions(merge: true));
      return 0;
    }

    final value = doc.data()?[_scoreField];

    if (value is num) {
      return value.toInt();
    }

    await ref.set({_scoreField: 0}, SetOptions(merge: true));
    return 0;
  }

  Future<int> getHighLevel() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();

    final value = doc.data()?[_levelField];

    if (value is num) {
      return value.toInt();
    }

    await ref.set({_levelField: 0}, SetOptions(merge: true));
    return 0;
  }

  Future<bool> saveRecordIfBetter({
    required int score,
    required int level,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();

    final currentScore = doc.data()?[_scoreField];

    final int highScore = currentScore is num ? currentScore.toInt() : 0;

    if (score > highScore) {
      await ref.set({
        _scoreField: score,
        _levelField: level,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    }

    return false;
  }
}