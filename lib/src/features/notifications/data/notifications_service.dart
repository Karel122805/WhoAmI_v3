import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

MemoryCadence cadenceFromString(String v) {
  switch (v) {
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

  static bool _initialized = false;

  static const String _androidChannelId = 'whoami_global';
  static const String _androidChannelName = 'Recordatorios y emergencias';
  static const String _androidChannelDesc =
      'Canal para recordatorios, mensajes y alertas.';

  static const String _emergencyChannelId = 'whoami_emergencias';
  static const String _emergencyChannelName = 'Emergencias Who Am I';
  static const String _emergencyChannelDesc = 'Alertas urgentes de consultantes';

  static int _nextNotificationId = 100000;

  static int _safeId() {
    _nextNotificationId++;
    if (_nextNotificationId > 999999) _nextNotificationId = 100000;
    return _nextNotificationId;
  }

  static Future<void> _trimPending() async {
    if (kIsWeb) return;
    try {
      final list = await _plugin.pendingNotificationRequests();
      if (list.length <= 60) return;

      final excess = list.length - 60;
      for (var i = 0; i < excess; i++) {
        await _plugin.cancel(list[i].id);
      }
      debugPrint('Podadas $excess notificaciones antiguas (quedan 60).');
    } catch (e) {
      debugPrint('Error al podar notificaciones pendientes: $e');
    }
  }

  static Future<void> init() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        debugPrint('Notificaciones locales deshabilitadas en Web');
        _initialized = true;
        return;
      }

      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      // ✅ IMPORTANTE: callback cuando el usuario toca la notificación
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (resp) async {
          final payload = resp.payload;

          if (payload == null) return;
          if (payload == 'emergency') return;

          // Si viene como uid/docId, reprograma el siguiente
          if (payload.contains('/')) {
            await rescheduleNextFromPayload(payload);
          }
        },
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const globalChannel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const emergencyChannel = AndroidNotificationChannel(
        _emergencyChannelId,
        _emergencyChannelName,
        description: _emergencyChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImpl?.createNotificationChannel(globalChannel);
      await androidImpl?.createNotificationChannel(emergencyChannel);

      await androidImpl?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await FirebaseMessaging.instance.requestPermission();
      FirebaseMessaging.onMessage.listen(_onFirebaseMessage);

      _initialized = true;
      debugPrint('Notificaciones inicializadas correctamente');
    } catch (e) {
      debugPrint('Error al inicializar notificaciones: $e');
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) await init();
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
      channelDescription: _androidChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
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
    final notif = message.notification;
    if (notif != null) {
      await showInstant(
        title: notif.title ?? 'Notificacion',
        body: notif.body ?? '',
      );
    }
  }

  // ============================================================
  // ✅ CLAVE: SOLO 1 NOTIFICACIÓN por recuerdo (la próxima)
  // ============================================================
  static Future<void> scheduleForMemory({
    required String memoryId, // '$uid/$docId'
    required String title,
    required DateTime anchorDate, // reminder.nextAt (FUTURO)
    required MemoryCadence cadence, // no se usa para generar lista, pero lo dejamos por compat
  }) async {
    await ensureInitialized();
    if (kIsWeb) return;

    // ✅ Cancela solo la actual del recuerdo
    await cancelForMemory(memoryId);

    await _trimPending();

    final now = DateTime.now();
    final adjusted =
        anchorDate.isBefore(now) ? now.add(const Duration(minutes: 1)) : anchorDate;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: _androidChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final id = _baseIdStable(memoryId);

    try {
      await _plugin.zonedSchedule(
        id,
        'Recordatorio de recuerdo',
        title,
        tz.TZDateTime.from(adjusted, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: memoryId,
        matchDateTimeComponents: null,
      );
    } catch (e) {
      debugPrint('Error al programar notificación: $e');
    }

    debugPrint('Programada 1 notificación para $memoryId');
  }

  // ============================================================
  // ✅ Reprogramar siguiente usando Firestore (cuando tocan notif)
  // ============================================================
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

      // hora guardada HH:mm
      final timeStr = (reminder['time'] as String?) ?? '09:00';
      final timeParts = timeStr.split(':');
      final hh = int.tryParse(timeParts[0]) ?? 9;
      final mm = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

      final now = DateTime.now();

      // Partimos de "ahora" a la hora elegida
      DateTime nextAt = DateTime(now.year, now.month, now.day, hh, mm);

      // Si ya pasó, avanza según cadence hasta quedar futuro
      if (!nextAt.isAfter(now)) {
        nextAt = _addCadence(nextAt, cadence);
        while (!nextAt.isAfter(now)) {
          nextAt = _addCadence(nextAt, cadence);
        }
      }

      // Título
      final text = (data['text'] as String?)?.trim() ?? '';
      final safeTitle = text.isEmpty ? 'Tu recuerdo' : text;

      // ✅ Guarda nextAt en Firestore para mantener el esquema correcto
      await FirebaseFirestore.instance
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .doc(docId)
          .update({
        'reminder.nextAt': Timestamp.fromDate(nextAt),
      });

      // ✅ Programa solo 1
      await scheduleForMemory(
        memoryId: memoryId,
        title: safeTitle,
        anchorDate: nextAt,
        cadence: cadence,
      );
    } catch (e) {
      debugPrint('Error rescheduleNextFromPayload: $e');
    }
  }

  // ============================================================
  // ✅ Cancelar SOLO 1 notificación por recuerdo
  // ============================================================
  static Future<void> cancelForMemory(String memoryId) async {
    await ensureInitialized();
    if (kIsWeb) return;

    final id = _baseIdStable(memoryId);
    await _plugin.cancel(id);
  }

  // (Opcional) Mantengo este por si lo ocupas en otro lado
  static Future<void> cancelAllForMemory(String memoryId) async {
    await ensureInitialized();
    if (kIsWeb) return;
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

  static Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
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
    await ensureInitialized();
    if (kIsWeb) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('No se pudieron obtener notificaciones pendientes: $e');
      return 0;
    }
  }

  // ============================================================
  // Emergencias (igual que tu versión)
  // ============================================================
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
      channelDescription: _emergencyChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      groupKey: groupKey,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final id = _safeId();
    await _plugin.show(id, title, body, details, payload: 'emergency');

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

  // ============================================================
  // Helpers
  // ============================================================
  static int _baseIdStable(String memoryId) {
    // memoryId viene como uid/docId
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final combined = '$uid-$memoryId';
    final hash = _fnv1a32(combined);
    return (hash % 900000) + 100000;
  }

  static int _fnv1a32(String input) {
    const int fnvPrime = 16777619;
    const int offsetBasis = 2166136261;

    int hash = offsetBasis;
    final units = input.codeUnits;
    for (final unit in units) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  static DateTime _addCadence(DateTime d, MemoryCadence c) {
    switch (c) {
      case MemoryCadence.hourly1:
        return d.add(const Duration(hours: 1));
      case MemoryCadence.hourly2:
        return d.add(const Duration(hours: 2));
      case MemoryCadence.hourly6:
        return d.add(const Duration(hours: 6));
      case MemoryCadence.daily1:
        return d.add(const Duration(days: 1));
      case MemoryCadence.daily2:
        return d.add(const Duration(days: 2));
      case MemoryCadence.weekly:
        return d.add(const Duration(days: 7));
      case MemoryCadence.biweekly:
        return d.add(const Duration(days: 14));
      case MemoryCadence.monthly:
        return _addMonths(d, 1);
      case MemoryCadence.quarterly:
        return _addMonths(d, 3);
      case MemoryCadence.semiannual:
        return _addMonths(d, 6);
      case MemoryCadence.annual:
        return _addMonths(d, 12);
    }
  }

  static DateTime _addMonths(DateTime d, int m) {
    final newMonth = d.month + m;
    final year = d.year + ((newMonth - 1) ~/ 12);
    final month = ((newMonth - 1) % 12) + 1;
    final day = min(d.day, _daysInMonth(year, month));
    return DateTime(year, month, day, d.hour, d.minute);
  }

  static int _daysInMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final next = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return next.difference(first).inDays;
  }

  static Future<void> scheduleTest() async {
    await ensureInitialized();
    await showInstant(
      title: 'Prueba de Who Am I',
      body: 'Tu sistema de notificaciones esta funcionando.',
    );
  }
}






