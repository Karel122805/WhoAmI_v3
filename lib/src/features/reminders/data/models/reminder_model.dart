import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/reminder.dart';

class ReminderModel extends Reminder {
  const ReminderModel({
    required super.id,
    required super.userId,
    required super.title,
    super.description,
    required super.dateTime,
    required super.voiceEnabled,
    required super.notificationEnabled,
    required super.completed,
    required super.createdAt,
    super.updatedAt,
  });

  factory ReminderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return ReminderModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      dateTime: _timestampToDateTime(data['dateTime']),
      voiceEnabled: data['voiceEnabled'] as bool? ?? true,
      notificationEnabled: data['notificationEnabled'] as bool? ?? true,
      completed: data['completed'] as bool? ?? false,
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: _nullableTimestampToDateTime(data['updatedAt']),
    );
  }

  factory ReminderModel.fromEntity(Reminder reminder) {
    return ReminderModel(
      id: reminder.id,
      userId: reminder.userId,
      title: reminder.title,
      description: reminder.description,
      dateTime: reminder.dateTime,
      voiceEnabled: reminder.voiceEnabled,
      notificationEnabled: reminder.notificationEnabled,
      completed: reminder.completed,
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'voiceEnabled': voiceEnabled,
      'notificationEnabled': notificationEnabled,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static DateTime _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.now();
  }

  static DateTime? _nullableTimestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}