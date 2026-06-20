import '../entities/reminder.dart';

abstract class ReminderRepository {
  Stream<List<Reminder>> watchUserReminders(String userId);

  Future<void> createReminder(Reminder reminder);

  Future<void> updateReminder(Reminder reminder);

  Future<void> deleteReminder(String reminderId);

  Future<void> markReminderAsCompleted(String reminderId);
}