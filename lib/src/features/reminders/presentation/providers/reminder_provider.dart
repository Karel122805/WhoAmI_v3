import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/datasources/reminder_remote_datasource.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../data/services/reminder_alert_service.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/usecases/create_reminder.dart';
import '../../domain/usecases/delete_reminder.dart';
import '../../domain/usecases/mark_reminder_as_completed.dart';
import '../../domain/usecases/update_reminder.dart';
import '../../domain/usecases/watch_user_reminders.dart';

class ReminderProvider extends ChangeNotifier {
  ReminderProvider() {
    final datasource = ReminderRemoteDatasource();
    final repository = ReminderRepositoryImpl(remoteDatasource: datasource);

    _watchUserReminders = WatchUserReminders(repository);
    _createReminder = CreateReminder(repository);
    _updateReminder = UpdateReminder(repository);
    _deleteReminder = DeleteReminder(repository);
    _markReminderAsCompleted = MarkReminderAsCompleted(repository);
  }

  late final WatchUserReminders _watchUserReminders;
  late final CreateReminder _createReminder;
  late final UpdateReminder _updateReminder;
  late final DeleteReminder _deleteReminder;
  late final MarkReminderAsCompleted _markReminderAsCompleted;

  StreamSubscription<List<Reminder>>? _subscription;

  List<Reminder> _reminders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Reminder> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Reminder> get pendingReminders {
    final now = DateTime.now();

    final list = _reminders
        .where((r) => !r.completed && r.dateTime.isAfter(now))
        .toList();

    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<Reminder> get completedReminders {
    final list = _reminders.where((r) => r.completed).toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  List<Reminder> get expiredReminders {
    final now = DateTime.now();

    final list = _reminders
        .where((r) => !r.completed && r.dateTime.isBefore(now))
        .toList();

    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  void watchReminders(String userId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();

    _subscription = _watchUserReminders(userId).listen(
      (items) {
        _reminders = items;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _errorMessage = 'No se pudieron cargar los recordatorios.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<bool> create({
    required String userId,
    required String title,
    String? description,
    required DateTime dateTime,
    required bool voiceEnabled,
    required bool notificationEnabled,
  }) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final reminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title.trim(),
        description: description?.trim(),
        dateTime: dateTime,
        voiceEnabled: voiceEnabled,
        notificationEnabled: notificationEnabled,
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: null,
      );

      await _createReminder(reminder);

      _reminders = [..._reminders, reminder];
      notifyListeners();

      try {
        await ReminderAlertService.scheduleReminder(reminder);
      } catch (_) {
        // Si falla la notificación local, NO debe fallar el guardado.
      }

      return true;
    } catch (_) {
      _errorMessage = 'No se pudo crear el recordatorio.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Reminder reminder) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final updated = reminder.copyWith(updatedAt: DateTime.now());

      await _updateReminder(updated);

      _reminders = _reminders.map((r) {
        return r.id == updated.id ? updated : r;
      }).toList();

      notifyListeners();

      try {
        await ReminderAlertService.cancelReminder(updated.id);
        await ReminderAlertService.scheduleReminder(updated);
      } catch (_) {}

      return true;
    } catch (_) {
      _errorMessage = 'No se pudo actualizar el recordatorio.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String reminderId) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _deleteReminder(reminderId);

      _reminders = _reminders.where((r) => r.id != reminderId).toList();
      notifyListeners();

      try {
        await ReminderAlertService.cancelReminder(reminderId);
      } catch (_) {}

      return true;
    } catch (_) {
      _errorMessage = 'No se pudo eliminar el recordatorio.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> complete(String reminderId) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _markReminderAsCompleted(reminderId);

      _reminders = _reminders.map((r) {
        if (r.id == reminderId) {
          return r.copyWith(completed: true, updatedAt: DateTime.now());
        }
        return r;
      }).toList();

      notifyListeners();

      try {
        await ReminderAlertService.cancelReminder(reminderId);
      } catch (_) {}

      return true;
    } catch (_) {
      _errorMessage = 'No se pudo completar el recordatorio.';
      notifyListeners();
      return false;
    }
  }

  Future<void> speak(Reminder reminder) async {
    await ReminderAlertService.speakReminder(reminder);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}