import '../../domain/entities/reminder.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../datasources/reminder_remote_datasource.dart';
import '../models/reminder_model.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final ReminderRemoteDatasource remoteDatasource;

  ReminderRepositoryImpl({
    required this.remoteDatasource,
  });

  @override
  Stream<List<Reminder>> watchUserReminders(String userId) {
    return remoteDatasource.watchUserReminders(userId);
  }

  @override
  Future<void> createReminder(Reminder reminder) async {
    final model = ReminderModel.fromEntity(reminder);
    await remoteDatasource.createReminder(model);
  }

  @override
  Future<void> updateReminder(Reminder reminder) async {
    final model = ReminderModel.fromEntity(reminder);
    await remoteDatasource.updateReminder(model);
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    await remoteDatasource.deleteReminder(reminderId);
  }

  @override
  Future<void> markReminderAsCompleted(String reminderId) async {
    await remoteDatasource.markReminderAsCompleted(reminderId);
  }
}