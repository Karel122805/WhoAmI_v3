// 🔔 NOTIFICATION SERVICE — Who Am I (versión con protecciones anti-crash)

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Frecuencias de recordatorios
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

  static const _androidChannelId = 'whoami_global';
  static const _androidChannelName = 'Recordatorios y emergencias';
  static const _androidChannelDesc =
      'Canal para notificaciones de recuerdos, mensajes y alertas.';

  // =============================================================
  // IDs SEGUROS PARA EVITAR CRASH POR COLISIÓN
  // =============================================================
  static int _nextNotificationId = 100000;

  static int _safeId() {
    _nextNotificationId++;
    if (_nextNotificationId > 999999) _nextNotificationId = 100000;
    return _nextNotificationId;
  }

  // =============================================================
  // LIMITADOR GLOBAL DE NOTIFICACIONES PENDIENTES
  // (evita que se acumulen cientos y reviente la app)
  // =============================================================
  static Future<void> _trimPending() async {
    if (kIsWeb) return;
    try {
      final list = await _plugin.pendingNotificationRequests();
      if (list.length <= 60) return; // límite seguro

      final excess = list.length - 60;
      for (var i = 0; i < excess; i++) {
        await _plugin.cancel(list[i].id);
      }
      debugPrint('🧹 Podadas $excess notificaciones antiguas (quedan 60).');
    } catch (e) {
      debugPrint('⚠️ Error al podar notificaciones pendientes: $e');
    }
  }

  // =============================================================
  // Inicialización global
  // =============================================================
  static Future<void> init() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        debugPrint('🌐 Notificaciones locales deshabilitadas en Web');
        _initialized = true;
        return;
      }

      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(initSettings);

      // 🔹 Canal principal
      const androidChannel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImpl?.createNotificationChannel(androidChannel);
      await androidImpl?.requestNotificationsPermission();

      // 🔹 Canal de emergencias independiente
      const emergChannel = AndroidNotificationChannel(
        'whoami_emergencias',
        'Emergencias Who Am I',
        description: 'Alertas urgentes de consultantes',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidImpl?.createNotificationChannel(emergChannel);

      // 🔹 Permisos iOS
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // 🔹 Permisos FCM
      await FirebaseMessaging.instance.requestPermission();

      // 🔹 Escucha mensajes push (app en primer plano)
      FirebaseMessaging.onMessage.listen(_onFirebaseMessage);

      _initialized = true;
      debugPrint('✅ Notificaciones inicializadas correctamente');
    } catch (e) {
      debugPrint('⚠️ Error al inicializar notificaciones: $e');
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) await init();
  }

  // =============================================================
  // Notificación inmediata
  // =============================================================
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
      _safeId(), // 👈 ID seguro
      title,
      body,
      details,
      payload: payload,
    );
  }

  // =============================================================
  // Sincronización con mensajes FCM (push)
  // =============================================================
  static Future<void> _onFirebaseMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif != null) {
      await showInstant(
        title: notif.title ?? 'Notificación',
        body: notif.body ?? '',
      );
    }
  }

  // =============================================================
  // Programar recordatorios de memoria (con protecciones)
  // =============================================================
  static Future<void> scheduleForMemory({
    required String memoryId,
    required String title,
    required DateTime anchorDate,
    required MemoryCadence cadence,
    int occurrences = 12,
  }) async {
    await ensureInitialized();
    if (kIsWeb) return;

    // Limpiar anteriores de ese recuerdo
    await cancelAllForMemory(memoryId);

    // Limitar programaciones futuras para evitar saturación
    occurrences = min(occurrences, 6);

    await _trimPending();

    // Si la fecha está en el pasado, arranca desde 1 minuto después
    final now = DateTime.now();
    var adjustedDate =
        anchorDate.isBefore(now) ? now.add(const Duration(minutes: 1)) : anchorDate;

    final baseId = _baseId(memoryId);
    final list = _generateOccurrences(adjustedDate, cadence, occurrences);

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

    for (var i = 0; i < list.length; i++) {
  try {
    await _plugin.zonedSchedule(
      baseId + i,
      'Recordatorio de recuerdo',
      title,
      tz.TZDateTime.from(list[i], tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: memoryId,
      matchDateTimeComponents: null, // <- OK
      // ❌ uiLocalNotificationDateInterpretation eliminado
    );
  } catch (e) {
    debugPrint('⚠️ Error al programar notificación $i: $e');
  }
}


    debugPrint('✅ Programadas ${list.length} notificaciones para $memoryId');
  }

  // =============================================================
  // Cancelaciones / consultas
  // =============================================================
  static Future<void> cancelAllForMemory(String memoryId) async {
    await ensureInitialized();
    if (kIsWeb) return;
    final base = _baseId(memoryId);
    // antes eran 50; con 20 estamos sobrad@s y evitamos bucles enormes
    for (var i = 0; i < 20; i++) {
      await _plugin.cancel(base + i);
    }
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
      debugPrint('⚠️ Error al obtener notificaciones pendientes: $e');
      return [];
    }
  }

  /// Contador de notificaciones pendientes
  static Future<int> getPendingCount() async {
    await ensureInitialized();
    if (kIsWeb) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('⚠️ No se pudieron obtener notificaciones pendientes: $e');
      return 0;
    }
  }

  // =============================================================
  // 🚨 EMERGENCIAS (agrupadas y limitadas)
  // =============================================================
  static Future<void> showEmergencyAlert({
    required String title,
    required String body,
  }) async {
    await ensureInitialized();
    if (kIsWeb) return;

    await _trimPending();

    const groupKey = 'emergency_group';

    const androidDetails = AndroidNotificationDetails(
      'whoami_emergencias',
      'Emergencias Who Am I',
      channelDescription: 'Alertas urgentes de consultantes',
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

    // Notificación individual
    final id = _safeId();
    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: 'emergency',
    );

    // Limitar máximo 5 emergencias activas para evitar saturación
    final pending = await _plugin.pendingNotificationRequests();
    final emergencies =
        pending.where((n) => n.payload == 'emergency').toList();
    if (emergencies.length > 5) {
      for (var i = 0; i < emergencies.length - 5; i++) {
        await _plugin.cancel(emergencies[i].id);
      }
    }

    // Resumen del grupo
    await _plugin.show(
      0,
      '🚨 Emergencias activas',
      'Tienes ${min(emergencies.length, 5)} emergencias recientes.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'whoami_emergencias',
          'Emergencias Who Am I',
          channelDescription: 'Resumen de emergencias activas',
          importance: Importance.high,
          priority: Priority.high,
          setAsGroupSummary: true,
          groupKey: groupKey,
        ),
      ),
    );
  }

  // =============================================================
  // Utilidades internas
  // =============================================================
  static int _baseId(String id) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final combined = '$uid-$id';
    return (combined.hashCode & 0x7fffffff) % 900000 + 100000;
  }

  static List<DateTime> _generateOccurrences(
      DateTime start, MemoryCadence c, int count) {
    final result = <DateTime>[];
    var current = start;
    for (int i = 0; i < count; i++) {
      current = _addCadence(current, c);
      result.add(current);
    }
    return result;
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
    final next =
        (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return next.difference(first).inDays;
  }

  // =============================================================
  // TEST GLOBAL
  // =============================================================
  static Future<void> scheduleTest() async {
    await ensureInitialized();
    await showInstant(
      title: '🔔 Prueba de Who Am I',
      body: 'Tu sistema de notificaciones está funcionando 💜',
    );
  }
}
