import '../entities/reminder.dart';
import '../repositories/reminder_repository.dart';

class WatchUserReminders {
  final ReminderRepository repository;

  WatchUserReminders(this.repository);

  Stream<List<Reminder>> call(String userId) {
    return repository.watchUserReminders(userId);
  }
}