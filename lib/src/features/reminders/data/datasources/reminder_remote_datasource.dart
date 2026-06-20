import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reminder_model.dart';

class ReminderRemoteDatasource {
  final FirebaseFirestore firestore;

  ReminderRemoteDatasource({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _remindersCollection {
    return firestore.collection('reminders');
  }

  Stream<List<ReminderModel>> watchUserReminders(String userId) {
    return _remindersCollection
        .where('userId', isEqualTo: userId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReminderModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> createReminder(ReminderModel reminder) async {
    final docRef = _remindersCollection.doc(reminder.id);

    final cleanReminder = ReminderModel(
      id: reminder.id,
      userId: reminder.userId,
      title: reminder.title.trim(),
      description: reminder.description?.trim(),
      dateTime: reminder.dateTime,
      voiceEnabled: reminder.voiceEnabled,
      notificationEnabled: reminder.notificationEnabled,
      completed: reminder.completed,
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
    );

    await docRef.set(cleanReminder.toFirestore());
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await _remindersCollection.doc(reminder.id).update(
          reminder.toFirestore(),
        );
  }

  Future<void> deleteReminder(String reminderId) async {
    await _remindersCollection.doc(reminderId).delete();
  }

  Future<void> markReminderAsCompleted(String reminderId) async {
    await _remindersCollection.doc(reminderId).update({
      'completed': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}