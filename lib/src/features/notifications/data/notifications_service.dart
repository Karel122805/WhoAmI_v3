import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum MemoryCadence {
  hourly1,
  hourly2,
  hourly6,
  daily1,
  daily2,
  weekly,
  biweekly,
  monthly,
  quarterly,
  semiannual,
  annual,
}

MemoryCadence cadenceFromString(String value) {
  switch (value) {
    case 'hourly1':
      return MemoryCadence.hourly1;
    case 'hourly2':
      return MemoryCadence.hourly2;
    case 'hourly6':
      return MemoryCadence.hourly6;
    case 'daily1':
      return MemoryCadence.daily1;
    case 'daily2':
      return MemoryCadence.daily2;
    case 'weekly':
      return MemoryCadence.weekly;
    case 'biweekly':
      return MemoryCadence.biweekly;
    case 'monthly':
      return MemoryCadence.monthly;
    case 'quarterly':
      return MemoryCadence.quarterly;
    case 'semiannual':
      return MemoryCadence.semiannual;
    case 'annual':
      return MemoryCadence.annual;
    default:
      return MemoryCadence.monthly;
  }
}

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;

  static const String _androidChannelId = 'whoami_global';
  static const String _androidChannelName = 'Recordatorios y alertas';
  static const String _androidChannelDescription =
      'Canal para recordatorios, mensajes y alertas de la aplicación.';

  static const String _emergencyChannelId = 'whoami_emergencies';
  static const String _emergencyChannelName = 'Alertas de emergencia';
  static const String _emergencyChannelDescription =
      'Canal para alertas importantes de emergencia.';

  static int _nextNotificationId = 100000;

  static int _safeId() {
    _nextNotificationId++;

    if (_nextNotificationId > 999999) {
      _nextNotificationId = 100000;
    }

    return _nextNotificationId;
  }

  static Future<void> _trimPending() async {
    if (kIsWeb) return;

    try {
      final pending = await _plugin.pendingNotificationRequests();

      if (pending.length <= 60) return;

      final excess = pending.length - 60;

      for (var i = 0; i < excess; i++) {
        await _plugin.cancel(pending[i].id);
      }

      debugPrint('Se limpiaron $excess notificaciones pendientes antiguas.');
    } catch (e) {
      debugPrint('Error al limpiar notificaciones pendientes: $e');
    }
  }

  static Future<void> init() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        debugPrint('Notificaciones locales deshabilitadas en web.');
        _initialized = true;
        return;
      }

      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) async {
          await _handleNotificationTap(response.payload);
        },
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      const globalChannel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const emergencyChannel = AndroidNotificationChannel(
        _emergencyChannelId,
        _emergencyChannelName,
        description: _emergencyChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidPlugin?.createNotificationChannel(globalChannel);
      await androidPlugin?.createNotificationChannel(emergencyChannel);
      await androidPlugin?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      await FirebaseMessaging.instance.requestPermission();

      FirebaseMessaging.onMessage.listen(_onFirebaseMessage);

      _initialized = true;
      debugPrint('Notificaciones inicializadas correctamente.');
    } catch (e) {
      debugPrint('Error al inicializar notificaciones: $e');
    }
  }

  static Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;

    if (payload == 'emergency') return;

    if (payload.startsWith('reminder/')) {
      await _openReminderAlarmFromPayload(payload);
      return;
    }

    if (payload.contains('/')) {
      await rescheduleNextFromPayload(payload);
    }
  }

  static Future<void> _openReminderAlarmFromPayload(String payload) async {
    try {
      final reminderId = payload.replaceFirst('reminder/', '').trim();

      if (reminderId.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(reminderId)
          .get();

      String title = 'Recordatorio';
      String? description;

      if (doc.exists) {
        final data = doc.data() ?? {};

        final rawTitle = (data['title'] as String?)?.trim();
        final rawDescription = (data['description'] as String?)?.trim();

        if (rawTitle != null && rawTitle.isNotEmpty) {
          title = rawTitle;
        }

        if (rawDescription != null && rawDescription.isNotEmpty) {
          description = rawDescription;
        }
      }

      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        debugPrint(
          'No se pudo abrir la alarma porque el navegador no está listo.',
        );
        return;
      }

      navigator.pushNamed(
        '/reminder-alarm',
        arguments: {
          'title': title,
          'description': description,
        },
      );
    } catch (e) {
      debugPrint('Error al abrir alarma de recordatorio: $e');
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  static Future<void> showInstant({
    required String title,
    required String body,
    String? payload,
  }) async {
    await ensureInitialized();

    if (kIsWeb) return;

    await _trimPending();

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _safeId(),
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> _onFirebaseMessage(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) return;

    await showInstant(
      title: notification.title ?? 'Notificación',
      body: notification.body ?? '',
    );
  }

  static Future<void> scheduleReminderNotification({
    required String reminderId,
    required String title,
    String? body,
    required DateTime dateTime,
  }) async {
    await ensureInitialized();

    if (kIsWeb) return;

    await _trimPending();

    if (!dateTime.isAfter(DateTime.now())) {
      debugPrint('La fecha del recordatorio ya pasó.');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      ticker: 'Recordatorio',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = _baseIdStable('reminder/$reminderId');

    await _plugin.zonedSchedule(
      notificationId,
      'Recordatorio',
      body == null || body.trim().isEmpty ? title : '$title\n$body',
      tz.TZDateTime.from(dateTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'reminder/$reminderId',
      matchDateTimeComponents: null,
    );

    await _saveReminderInAppNotifications(
      reminderId: reminderId,
      title: title,
      body: body,
      dateTime: dateTime,
    );

    debugPrint('Recordatorio programado correctamente: $title');
  }

  static Future<void> cancelReminderNotification(String reminderId) async {
    await ensureInitialized();

    if (kIsWeb) return;

    final notificationId = _baseIdStable('reminder/$reminderId');
    await _plugin.cancel(notificationId);
  }

  static Future<void> _saveReminderInAppNotifications({
    required String reminderId,
    required String title,
    String? body,
    required DateTime dateTime,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc('reminder_$reminderId')
          .set({
        'title': 'Recordatorio',
        'body': body == null || body.trim().isEmpty ? title : '$title\n$body',
        'type': 'reminder',
        'reminderId': reminderId,
        'timestamp': Timestamp.fromDate(dateTime),
        'read': false,
        'deleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('No se pudo guardar la notificación interna: $e');
    }
  }

  static Future<int> getUnreadAppNotificationCount() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .where('deleted', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error contando notificaciones no leídas: $e');
      return 0;
    }
  }

  static Stream<int> watchUnreadAppNotificationCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .where('deleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  static Future<void> markAppNotificationAsRead(String notificationId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marcando notificación como leída: $e');
    }
  }

  static Future<void> deleteAppNotification(String notificationId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .set({
        'deleted': true,
        'read': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error eliminando notificación interna: $e');
    }
  }

  static Future<void> scheduleForMemory({
    required String memoryId,
    required String title,
    required DateTime anchorDate,
    required MemoryCadence cadence,
  }) async {
    await ensureInitialized();

    if (kIsWeb) return;

    await cancelForMemory(memoryId);
    await _trimPending();

    final now = DateTime.now();

    final adjustedDate =
        anchorDate.isBefore(now) ? now.add(const Duration(minutes: 1)) : anchorDate;

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = _baseIdStable(memoryId);

    try {
      await _plugin.zonedSchedule(
        notificationId,
        'Recordatorio de recuerdo',
        title,
        tz.TZDateTime.from(adjustedDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: memoryId,
        matchDateTimeComponents: null,
      );
    } catch (e) {
      debugPrint('Error al programar recordatorio de recuerdo: $e');
    }

    debugPrint('Recordatorio de recuerdo programado correctamente.');
  }

  static Future<void> rescheduleNextFromPayload(String memoryId) async {
    try {
      final parts = memoryId.split('/');

      if (parts.length != 2) return;

      final uid = parts[0];
      final docId = parts[1];

      final doc = await FirebaseFirestore.instance
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .doc(docId)
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final reminder = data['reminder'];

      if (reminder is! Map) return;
      if (reminder['enabled'] != true) return;

      final cadenceRaw =
          (reminder['cadence'] as String?)?.toLowerCase().trim() ?? 'monthly';

      final cadence = cadenceFromString(cadenceRaw);

      final timeText = (reminder['time'] as String?) ?? '09:00';
      final timeParts = timeText.split(':');

      final hour = int.tryParse(timeParts[0]) ?? 9;
      final minute =
          int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

      final now = DateTime.now();

      DateTime nextAt = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (!nextAt.isAfter(now)) {
        nextAt = _addCadence(nextAt, cadence);

        while (!nextAt.isAfter(now)) {
          nextAt = _addCadence(nextAt, cadence);
        }
      }

      final text = (data['text'] as String?)?.trim() ?? '';
      final safeTitle = text.isEmpty ? 'Tu recuerdo' : text;

      await FirebaseFirestore.instance
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .doc(docId)
          .update({
        'reminder.nextAt': Timestamp.fromDate(nextAt),
      });

      await scheduleForMemory(
        memoryId: memoryId,
        title: safeTitle,
        anchorDate: nextAt,
        cadence: cadence,
      );
    } catch (e) {
      debugPrint('Error al reprogramar el siguiente recuerdo: $e');
    }
  }

  static Future<void> cancelForMemory(String memoryId) async {
    await ensureInitialized();

    if (kIsWeb) return;

    final notificationId = _baseIdStable(memoryId);
    await _plugin.cancel(notificationId);
  }

  static Future<void> cancelAllForMemory(String memoryId) async {
    await cancelForMemory(memoryId);
  }

  static Future<void> cancel(int id) async {
    await ensureInitialized();

    if (kIsWeb) return;

    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await ensureInitialized();

    if (kIsWeb) return;

    await _plugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async {
    await ensureInitialized();

    if (kIsWeb) return [];

    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error al obtener notificaciones pendientes: $e');
      return [];
    }
  }

  static Future<int> getPendingCount() async {
    return getUnreadAppNotificationCount();
  }

  static Future<void> showEmergencyAlert({
    required String title,
    required String body,
  }) async {
    await ensureInitialized();

    if (kIsWeb) return;

    await _trimPending();

    const groupKey = 'emergency_group';

    const androidDetails = AndroidNotificationDetails(
      _emergencyChannelId,
      _emergencyChannelName,
      channelDescription: _emergencyChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      groupKey: groupKey,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = _safeId();

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: 'emergency',
    );

    final pending = await _plugin.pendingNotificationRequests();
    final emergencies = pending.where((n) => n.payload == 'emergency').toList();

    if (emergencies.length > 5) {
      for (var i = 0; i < emergencies.length - 5; i++) {
        await _plugin.cancel(emergencies[i].id);
      }
    }

    await _plugin.show(
      0,
      'Emergencias activas',
      'Tienes ${min(emergencies.length, 5)} emergencias recientes.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _emergencyChannelId,
          _emergencyChannelName,
          channelDescription: 'Resumen de emergencias activas',
          importance: Importance.high,
          priority: Priority.high,
          setAsGroupSummary: true,
          groupKey: groupKey,
        ),
      ),
    );
  }

  static int _baseIdStable(String value) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final combined = '$uid-$value';
    final hash = _fnv1a32(combined);

    return (hash % 900000) + 100000;
  }

  static int _fnv1a32(String input) {
    const int fnvPrime = 16777619;
    const int offsetBasis = 2166136261;

    int hash = offsetBasis;

    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    return hash & 0x7FFFFFFF;
  }

  static DateTime _addCadence(DateTime date, MemoryCadence cadence) {
    switch (cadence) {
      case MemoryCadence.hourly1:
        return date.add(const Duration(hours: 1));
      case MemoryCadence.hourly2:
        return date.add(const Duration(hours: 2));
      case MemoryCadence.hourly6:
        return date.add(const Duration(hours: 6));
      case MemoryCadence.daily1:
        return date.add(const Duration(days: 1));
      case MemoryCadence.daily2:
        return date.add(const Duration(days: 2));
      case MemoryCadence.weekly:
        return date.add(const Duration(days: 7));
      case MemoryCadence.biweekly:
        return date.add(const Duration(days: 14));
      case MemoryCadence.monthly:
        return _addMonths(date, 1);
      case MemoryCadence.quarterly:
        return _addMonths(date, 3);
      case MemoryCadence.semiannual:
        return _addMonths(date, 6);
      case MemoryCadence.annual:
        return _addMonths(date, 12);
    }
  }

  static DateTime _addMonths(DateTime date, int monthsToAdd) {
    final newMonth = date.month + monthsToAdd;
    final year = date.year + ((newMonth - 1) ~/ 12);
    final month = ((newMonth - 1) % 12) + 1;
    final day = min(date.day, _daysInMonth(year, month));

    return DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
    );
  }

  static int _daysInMonth(int year, int month) {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    return nextMonth.difference(DateTime(year, month, 1)).inDays;
  }

  static Future<void> scheduleTest() async {
    await ensureInitialized();

    await showInstant(
      title: 'Prueba de WhoAmI',
      body: 'El sistema de notificaciones está funcionando.',
    );
  }
}