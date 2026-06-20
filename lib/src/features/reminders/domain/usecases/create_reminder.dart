import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class CreateReminder {
  final ReminderRepository repository;

  CreateReminder(this.repository);

  Future<void> call(Reminder reminder) {
    return repository.createReminder(reminder);
  }
}