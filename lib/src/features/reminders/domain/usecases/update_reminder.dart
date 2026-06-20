import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class UpdateReminder {
  final ReminderRepository repository;

  UpdateReminder(this.repository);

  Future<void> call(Reminder reminder) {
    return repository.updateReminder(reminder);
  }
}