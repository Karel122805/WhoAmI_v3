import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../notifications/data/notifications_service.dart';
import '../../domain/entities/reminder.dart';

class ReminderAlertService {
  ReminderAlertService._();

  static const MethodChannel _alarmChannel =
      MethodChannel('whoami/reminder_alarm');

  static Future<void> initialize() async {
    await NotificationsService.ensureInitialized();
  }

  static Future<void> scheduleReminder(Reminder reminder) async {
    await initialize();

    if (!reminder.notificationEnabled) return;

    await NotificationsService.scheduleReminderNotification(
      reminderId: reminder.id,
      title: reminder.title,
      body: reminder.description,
      dateTime: reminder.dateTime,
    );

    try {
      await _alarmChannel.invokeMethod('scheduleAlarm', {
        'id': reminder.id.hashCode,
        'title': reminder.title,
        'timeMillis': reminder.dateTime.millisecondsSinceEpoch,
      });

      debugPrint('ALARMA NATIVA PROGRAMADA: ${reminder.title}');
    } catch (e) {
      debugPrint('ERROR AL PROGRAMAR ALARMA NATIVA: $e');
    }
  }

  static Future<void> cancelReminder(String reminderId) async {
    await initialize();

    await NotificationsService.cancelReminderNotification(reminderId);

    try {
      await _alarmChannel.invokeMethod('cancelAlarm', {
        'id': reminderId.hashCode,
      });

      debugPrint('ALARMA NATIVA CANCELADA: $reminderId');
    } catch (e) {
      debugPrint('ERROR AL CANCELAR ALARMA NATIVA: $e');
    }
  }

  static Future<void> speakReminder(Reminder reminder) async {
    // La voz automática se conecta después.
    // Primero dejamos estable la alarma nativa del celular.
  }
}