import '../repositories/reminder_repository.dart';

class MarkReminderAsCompleted {
  final ReminderRepository repository;

  MarkReminderAsCompleted(this.repository);

  Future<void> call(String reminderId) {
    return repository.markReminderAsCompleted(reminderId);
  }
}