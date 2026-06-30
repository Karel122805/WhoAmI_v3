import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ============================================================
// FRECUENCIAS DE LOS RECUERDOS
// ============================================================

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

MemoryCadence cadenceFromString(
  String value,
) {
  switch (value.toLowerCase().trim()) {
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
      return MemoryCadence.weekly;
  }
}

// ============================================================
// SERVICIO DE NOTIFICACIONES
// ============================================================

class NotificationsService {
  NotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;
  static bool _firebaseListenerRegistered = false;
  static bool _tokenRefreshListenerRegistered = false;

  static final Set<String> _processedEmergencyKeys = <String>{};
  static final Map<String, DateTime> _processedEmergencyTimes =
      <String, DateTime>{};

  static const Duration _emergencyDuplicateWindow = Duration(
    minutes: 10,
  );

  // ============================================================
  // CANAL GENERAL
  // ============================================================

  static const String _androidChannelId = 'whoami_global';
  static const String _androidChannelName = 'Recordatorios y alertas';
  static const String _androidChannelDescription =
      'Canal para recordatorios, mensajes y alertas de la aplicación.';

  // ============================================================
  // CANAL DE EMERGENCIAS
  // ============================================================

  static const String _emergencyChannelId = 'whoami_emergencies';
  static const String _emergencyChannelName = 'Alertas de emergencia';
  static const String _emergencyChannelDescription =
      'Canal para alertas importantes de emergencia.';
  static const String _emergencyGroupKey = 'emergency_group';

  static final Int64List _emergencyVibrationPattern =
      Int64List.fromList(
    <int>[
      0,
      900,
      300,
      900,
      300,
      1300,
    ],
  );

  static int _nextNotificationId = 100000;

  // ============================================================
  // GENERAR ID TEMPORAL
  // ============================================================

  static int _safeId() {
    _nextNotificationId++;

    if (_nextNotificationId > 999999) {
      _nextNotificationId = 100000;
    }

    return _nextNotificationId;
  }

  // ============================================================
  // LIMITAR NOTIFICACIONES PENDIENTES
  // ============================================================

  static Future<void> _trimPending() async {
    if (kIsWeb) {
      return;
    }

    try {
      final pending = await _plugin.pendingNotificationRequests();

      // No se cancelan recordatorios automáticamente. Antes se eliminaban
      // elementos al superar 60 pendientes y eso podía borrar una alarma de
      // recuerdo válida sin avisar al usuario.
      if (pending.length > 200) {
        debugPrint(
          'Advertencia: hay ${pending.length} notificaciones pendientes. '
          'No se eliminó ninguna para proteger los recordatorios programados.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error consultando notificaciones pendientes: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // INICIALIZAR SERVICIO
  // ============================================================

  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      _initialized = true;

      debugPrint(
        'Las notificaciones locales están deshabilitadas en web.',
      );

      return;
    }

    try {
      tzdata.initializeTimeZones();

      tz.setLocalLocation(
        tz.getLocation(
          'America/Mexico_City',
        ),
      );

      const androidInitializationSettings =
          AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const iosInitializationSettings =
          DarwinInitializationSettings();

      const initializationSettings =
          InitializationSettings(
        android: androidInitializationSettings,
        iOS: iosInitializationSettings,
      );

      await _plugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (
          NotificationResponse response,
        ) async {
          await _handleNotificationTap(
            response.payload,
          );
        },
      );

      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
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

      await androidPlugin?.createNotificationChannel(
        globalChannel,
      );

      await androidPlugin?.createNotificationChannel(
        emergencyChannel,
      );

      await androidPlugin?.requestNotificationsPermission();

      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (error) {
        debugPrint(
          'No se pudo solicitar permiso de alarmas exactas: $error',
        );
      }

      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_firebaseListenerRegistered) {
        FirebaseMessaging.onMessage.listen(
          _onFirebaseMessage,
        );

        _firebaseListenerRegistered = true;
      }

      _initialized = true;

      debugPrint(
        'Notificaciones inicializadas correctamente.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error inicializando notificaciones: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      rethrow;
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }
    // ============================================================
  // GUARDAR TOKEN FCM DEL USUARIO ACTUAL
  // ============================================================

  static Future<void> saveFcmTokenForCurrentUser() async {
    if (kIsWeb) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      final token = await messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        debugPrint(
          'No se obtuvo token FCM.',
        );
        return;
      }

      await _saveTokenForUser(
        uid: user.uid,
        token: token,
      );

      if (!_tokenRefreshListenerRegistered) {
        FirebaseMessaging.instance.onTokenRefresh.listen(
          (newToken) async {
            final currentUser = FirebaseAuth.instance.currentUser;

            if (currentUser == null) {
              return;
            }

            await _saveTokenForUser(
              uid: currentUser.uid,
              token: newToken,
            );
          },
        );

        _tokenRefreshListenerRegistered = true;
      }

      debugPrint(
        'Token FCM guardado correctamente.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error guardando token FCM: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  static Future<void> _saveTokenForUser({
    required String uid,
    required String token,
  }) async {
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    final userReference = firestore.collection('users').doc(uid);

    await userReference.set(
      {
        'fcmToken': cleanToken,
        'fcmTokens': FieldValue.arrayUnion(
          <String>[
            cleanToken,
          ],
        ),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );

    await userReference
        .collection('fcm_tokens')
        .doc(cleanToken)
        .set(
      {
        'token': cleanToken,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'active': true,
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  // ============================================================
  // PROCESAR MENSAJE FCM EN SEGUNDO PLANO / APP CERRADA
  // ============================================================

  static Future<void> handleBackgroundFirebaseMessage(
    RemoteMessage message,
  ) async {
    await ensureInitialized();

    await _processFirebaseMessage(
      message,
      saveEmergencyInFirestore: false,
    );
  }

  // ============================================================
  // MANEJAR TOQUE EN UNA NOTIFICACIÓN
  // ============================================================

  static Future<void> _handleNotificationTap(
    String? payload,
  ) async {
    final safePayload = payload?.trim() ?? '';

    if (safePayload.isEmpty) {
      return;
    }

    final normalizedPayload = safePayload.toLowerCase();

    if (normalizedPayload == 'emergency' ||
        normalizedPayload == 'emergencia' ||
        normalizedPayload.startsWith('emergency/') ||
        normalizedPayload.startsWith('emergencia/')) {
      return;
    }

    if (normalizedPayload.startsWith('reminder/')) {
      await markAppNotificationAsRead(
        'reminder_${safePayload.replaceFirst('reminder/', '').trim()}',
      );

      return;
    }

    if (safePayload.contains('/')) {
      await markMemoryNotificationAsRead(
        safePayload,
      );
    }
  }

  // ============================================================
  // ABRIR ALARMA DE RECORDATORIO NORMAL
  // ============================================================

  static Future<void> _openReminderAlarmFromPayload(
    String payload,
  ) async {
    try {
      final reminderId = payload
          .replaceFirst(
            'reminder/',
            '',
          )
          .trim();

      if (reminderId.isEmpty) {
        return;
      }

      await markAppNotificationAsRead(
        'reminder_$reminderId',
      );

      final document = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(reminderId)
          .get();

      String title = 'Recordatorio';
      String? description;

      if (document.exists) {
        final data = document.data() ?? <String, dynamic>{};

        final storedTitle = data['title']?.toString().trim();
        final storedDescription =
            data['description']?.toString().trim();

        if (storedTitle != null && storedTitle.isNotEmpty) {
          title = storedTitle;
        }

        if (storedDescription != null &&
            storedDescription.isNotEmpty) {
          description = storedDescription;
        }
      }

      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        debugPrint(
          'No se pudo abrir la alarma porque el navegador no está disponible.',
        );

        return;
      }

      await navigator.pushNamed(
        '/reminder-alarm',
        arguments: {
          'reminderId': reminderId,
          'title': title,
          'description': description,
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error abriendo alarma de recordatorio: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }
    // ============================================================
  // MOSTRAR NOTIFICACIÓN INMEDIATA
  // ============================================================

  static Future<void> showInstant({
    required String title,
    required String body,
    String? payload,
  }) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

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

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _safeId(),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ============================================================
  // RECIBIR FCM CON LA APP ABIERTA
  // ============================================================

  static Future<void> _onFirebaseMessage(
    RemoteMessage message,
  ) async {
    await _processFirebaseMessage(
      message,
      saveEmergencyInFirestore: false,
    );
  }

  // ============================================================
  // PROCESAR MENSAJE FCM
  // ============================================================

  static Future<void> _processFirebaseMessage(
    RemoteMessage message, {
    required bool saveEmergencyInFirestore,
  }) async {
    final notification = message.notification;
    final data = message.data;

    if (notification == null && data.isEmpty) {
      return;
    }

    final title =
        notification?.title ??
        data['title']?.toString() ??
        'Notificación';

    final body =
        notification?.body ??
        data['body']?.toString() ??
        '';

    final type =
        data['type']?.toString().toLowerCase().trim() ?? '';

    final emergencyValue =
        data['emergency']?.toString().toLowerCase().trim() ?? '';

    final isEmergency =
        type == 'emergency' ||
        type == 'emergencia' ||
        type == 'emergency_alert' ||
        type == 'panic' ||
        type == 'panic_alert' ||
        emergencyValue == 'true';

    if (isEmergency) {
      final emergencyId =
          data['emergencyId']?.toString().trim() ??
          data['alertId']?.toString().trim() ??
          data['notificationId']?.toString().trim() ??
          data['documentId']?.toString().trim() ??
          message.messageId?.trim() ??
          '';

      final consultantId =
          data['consultantId']?.toString().trim() ??
          data['patientId']?.toString().trim() ??
          data['userId']?.toString().trim() ??
          '';

      final emergencyKey =
          emergencyId.isNotEmpty
              ? emergencyId
              : '$consultantId|$title|$body';

      await showEmergencyAlert(
        title: title,
        body: body,
        emergencyKey: emergencyKey,
        saveInFirestore: saveEmergencyInFirestore,
      );

      return;
    }

    await showInstant(
      title: title,
      body: body,
      payload: data['payload']?.toString(),
    );
  }

  // ============================================================
  // PROGRAMAR RECORDATORIO NORMAL
  // ============================================================

  static Future<void> scheduleReminderNotification({
    required String reminderId,
    required String title,
    String? body,
    required DateTime dateTime,
  }) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    if (!dateTime.isAfter(DateTime.now())) {
      debugPrint(
        'No se programó el recordatorio porque la fecha ya pasó.',
      );

      return;
    }

    await _trimPending();

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      ticker: 'Recordatorio',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = _baseIdStable(
      'reminder/$reminderId',
    );

    final scheduledDate = tz.TZDateTime.from(
      dateTime,
      tz.local,
    );

    final notificationBody =
        body == null || body.trim().isEmpty
            ? title
            : '$title\n$body';

    try {
      await _plugin.zonedSchedule(
        notificationId,
        'Recordatorio',
        notificationBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'reminder/$reminderId',
        matchDateTimeComponents: null,
      );
    } catch (error) {
      debugPrint(
        'Android no permitió una alarma exacta. Se usará una aproximada: $error',
      );

      await _plugin.zonedSchedule(
        notificationId,
        'Recordatorio',
        notificationBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'reminder/$reminderId',
        matchDateTimeComponents: null,
      );
    }

    await _saveReminderInAppNotifications(
      reminderId: reminderId,
      title: title,
      body: body,
      dateTime: dateTime,
    );

    debugPrint(
      'Recordatorio programado correctamente: $title',
    );
  }
    // ============================================================
  // CANCELAR RECORDATORIO NORMAL
  // ============================================================

  static Future<void> cancelReminderNotification(
    String reminderId,
  ) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    final notificationId = _baseIdStable(
      'reminder/$reminderId',
    );

    await _plugin.cancel(
      notificationId,
    );
  }

  // ============================================================
  // GUARDAR RECORDATORIO NORMAL EN FIRESTORE
  // ============================================================

  static Future<void> _saveReminderInAppNotifications({
    required String reminderId,
    required String title,
    String? body,
    required DateTime dateTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc('reminder_$reminderId')
          .set(
        {
          'title': 'Recordatorio',
          'body': body == null || body.trim().isEmpty
              ? title
              : '$title\n$body',
          'type': 'reminder',
          'reminderId': reminderId,
          'payload': 'reminder/$reminderId',
          'timestamp': Timestamp.fromDate(dateTime),
          'read': false,
          'deleted': false,
          'completed': false,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error guardando el recordatorio interno: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // CONTAR NOTIFICACIONES NO LEÍDAS
  // ============================================================

  static Future<int> getUnreadAppNotificationCount() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        return 0;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();

      return snapshot.docs.where(
        (document) {
          final data = document.data();

          final isRead = data['read'] == true;
          final isDeleted = data['deleted'] == true;
          final isCompleted = data['completed'] == true;

          return !isRead && !isDeleted && !isCompleted;
        },
      ).length;
    } catch (error, stackTrace) {
      debugPrint(
        'Error contando notificaciones no leídas: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      return 0;
    }
  }

  // ============================================================
  // ESCUCHAR CANTIDAD DE NO LEÍDAS
  // ============================================================

  static Stream<int> watchUnreadAppNotificationCount() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Stream<int>.value(0);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .snapshots()
        .map(
      (snapshot) {
        return snapshot.docs.where(
          (document) {
            final data = document.data();

            final isRead = data['read'] == true;
            final isDeleted = data['deleted'] == true;
            final isCompleted = data['completed'] == true;

            return !isRead && !isDeleted && !isCompleted;
          },
        ).length;
      },
    );
  }

  // ============================================================
  // MARCAR NOTIFICACIÓN COMO LEÍDA
  // ============================================================

  static Future<void> markAppNotificationAsRead(
    String notificationId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception(
        'No hay un usuario autenticado.',
      );
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .set(
        {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        'Notificación marcada como leída: $notificationId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error marcando notificación como leída: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      rethrow;
    }
  }

  // ============================================================
  // MARCAR RECUERDO COMO VISTO
  // ============================================================

  static Future<void> markMemoryNotificationAsRead(
    String memoryId,
  ) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return;
    }

    final parts = memoryId.split('/');

    if (parts.length != 2) {
      return;
    }

    final memoryOwnerId = parts[0].trim();
    final memoryDocumentId = parts[1].trim();

    if (memoryOwnerId.isEmpty || memoryDocumentId.isEmpty) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('memories')
          .doc(memoryOwnerId)
          .collection('user_memories')
          .doc(memoryDocumentId)
          .update(
        {
          'reminder.read': true,
          'reminder.readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      final notificationsSnapshot = await firestore
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .where(
            'memoryId',
            isEqualTo: memoryId,
          )
          .get();

      if (notificationsSnapshot.docs.isNotEmpty) {
        final batch = firestore.batch();

        for (final document in notificationsSnapshot.docs) {
          batch.set(
            document.reference,
            {
              'read': true,
              'readAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(
              merge: true,
            ),
          );
        }

        await batch.commit();
      }

      debugPrint(
        'Recuerdo marcado como visto: $memoryId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error marcando recuerdo como visto: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      rethrow;
    }
  }
    // ============================================================
  // COMPLETAR NOTIFICACIÓN
  // ============================================================

  static Future<void> completeAppNotification(
    String notificationId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    final firestore = FirebaseFirestore.instance;

    final notificationReference = firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId);

    try {
      final snapshot = await notificationReference.get();
      final data = snapshot.data() ?? <String, dynamic>{};

      final type = data['type']?.toString().toLowerCase().trim() ?? '';
      final reminderId = data['reminderId']?.toString().trim();
      final payload = data['payload']?.toString().trim();
      final memoryId = data['memoryId']?.toString().trim();
      final emergencyKey = data['emergencyKey']?.toString().trim();

      if (type == 'emergency' || type == 'emergencia') {
        final resolvedEmergencyKey =
            emergencyKey != null && emergencyKey.isNotEmpty
                ? emergencyKey
                : _extractEmergencyKeyFromPayload(payload);

        if (resolvedEmergencyKey != null &&
            resolvedEmergencyKey.isNotEmpty) {
          await closeEmergencyAlert(
            emergencyKey: resolvedEmergencyKey,
            notificationDocumentId: notificationId,
          );
          return;
        }
      }

      final batch = firestore.batch();

      batch.set(
        notificationReference,
        {
          'read': true,
          'completed': true,
          'active': false,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (reminderId != null && reminderId.isNotEmpty) {
        final reminderReference =
            firestore.collection('reminders').doc(reminderId);

        batch.set(
          reminderReference,
          {
            'completed': true,
            'notificationEnabled': false,
            'active': false,
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      String? resolvedMemoryPayload;

      if (payload != null &&
          payload.contains('/') &&
          !payload.startsWith('reminder/') &&
          !payload.startsWith('emergency/') &&
          !payload.startsWith('emergencia/')) {
        resolvedMemoryPayload = payload;
      } else if (memoryId != null && memoryId.contains('/')) {
        resolvedMemoryPayload = memoryId;
      }

      if (resolvedMemoryPayload != null) {
        final parts = resolvedMemoryPayload.split('/');

        if (parts.length == 2) {
          final memoryUserId = parts[0];
          final memoryDocumentId = parts[1];

          final memoryReference = firestore
              .collection('memories')
              .doc(memoryUserId)
              .collection('user_memories')
              .doc(memoryDocumentId);

          batch.set(
            memoryReference,
            {
              'reminder.enabled': false,
              'reminder.completed': true,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      if (reminderId != null && reminderId.isNotEmpty) {
        await cancelReminderNotification(reminderId);
      }

      if (resolvedMemoryPayload != null) {
        await cancelForMemory(resolvedMemoryPayload);
      }

      debugPrint('Notificación completada: $notificationId');
    } catch (error, stackTrace) {
      debugPrint('Error completando la notificación $notificationId: $error');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // ============================================================
  // ELIMINAR NOTIFICACIÓN INTERNA
  // ============================================================

  static Future<void> deleteAppNotification(
    String notificationId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception('No hay un usuario autenticado.');
    }

    final firestore = FirebaseFirestore.instance;

    final notificationReference = firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId);

    try {
      final snapshot = await notificationReference.get();
      final data = snapshot.data() ?? <String, dynamic>{};

      final type = data['type']?.toString().toLowerCase().trim() ?? '';
      final reminderId = data['reminderId']?.toString().trim();
      final payload = data['payload']?.toString().trim();
      final memoryId = data['memoryId']?.toString().trim();
      final emergencyKey = data['emergencyKey']?.toString().trim();

      if (type == 'emergency' || type == 'emergencia') {
        final resolvedEmergencyKey =
            emergencyKey != null && emergencyKey.isNotEmpty
                ? emergencyKey
                : _extractEmergencyKeyFromPayload(payload);

        if (resolvedEmergencyKey != null &&
            resolvedEmergencyKey.isNotEmpty) {
          await closeEmergencyAlert(
            emergencyKey: resolvedEmergencyKey,
            notificationDocumentId: notificationId,
          );
          return;
        }
      }

      await notificationReference.set(
        {
          'read': true,
          'deleted': true,
          'active': false,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (reminderId != null && reminderId.isNotEmpty) {
        await cancelReminderNotification(reminderId);
      }

      String? resolvedMemoryPayload;

      if (payload != null &&
          payload.contains('/') &&
          !payload.startsWith('reminder/') &&
          !payload.startsWith('emergency/') &&
          !payload.startsWith('emergencia/')) {
        resolvedMemoryPayload = payload;
      } else if (memoryId != null && memoryId.contains('/')) {
        resolvedMemoryPayload = memoryId;
      }

      if (resolvedMemoryPayload != null) {
        await cancelForMemory(resolvedMemoryPayload);
      }

      debugPrint('Notificación eliminada: $notificationId');
    } catch (error, stackTrace) {
      debugPrint('Error eliminando notificación $notificationId: $error');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // ============================================================
  // EXTRAER CLAVE DE EMERGENCIA DESDE PAYLOAD
  // ============================================================

  static String? _extractEmergencyKeyFromPayload(
    String? payload,
  ) {
    final value = payload?.trim() ?? '';

    if (value.isEmpty) {
      return null;
    }

    final lowerValue = value.toLowerCase();

    if (lowerValue.startsWith('emergency/')) {
      final key = value.substring('emergency/'.length);
      return key.isEmpty ? null : key;
    }

    if (lowerValue.startsWith('emergencia/')) {
      final key = value.substring('emergencia/'.length);
      return key.isEmpty ? null : key;
    }

    return null;
  }
    // ============================================================
  // PROGRAMAR RECORDATORIO DE RECUERDO / CALENDARIO
  // ============================================================

  static Future<void> scheduleForMemory({
    required String memoryId,
    required String title,
    required DateTime anchorDate,
    required MemoryCadence cadence,
  }) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    await cancelForMemory(memoryId);
    await _trimPending();

    final now = DateTime.now();
    DateTime adjustedDate = anchorDate;

    while (!adjustedDate.isAfter(now)) {
      adjustedDate = _addCadence(adjustedDate, cadence);
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
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = _baseIdStable(memoryId);

    final scheduledDate = tz.TZDateTime.from(
      adjustedDate,
      tz.local,
    );

    final matchComponents = _matchDateTimeComponentsForCadence(
      cadence,
    );

    try {
      await _plugin.zonedSchedule(
        notificationId,
        'Recordatorio de recuerdo',
        title,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: memoryId,
        matchDateTimeComponents: matchComponents,
      );
    } catch (error) {
      debugPrint(
        'No se pudo usar alarma exacta para el recuerdo. '
        'Se usará una alarma aproximada: $error',
      );

      await _plugin.zonedSchedule(
        notificationId,
        'Recordatorio de recuerdo',
        title,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: memoryId,
        matchDateTimeComponents: matchComponents,
      );
    }

    await _saveMemoryInAppNotifications(
      memoryId: memoryId,
      title: title,
      dateTime: adjustedDate,
      cadence: cadence,
    );

    debugPrint(
      'Recordatorio de recuerdo programado: $memoryId para $adjustedDate',
    );
  }

  // ============================================================
  // COMPONENTES DE REPETICIÓN
  // ============================================================

  static DateTimeComponents? _matchDateTimeComponentsForCadence(
    MemoryCadence cadence,
  ) {
    switch (cadence) {
      case MemoryCadence.weekly:
        return DateTimeComponents.dayOfWeekAndTime;

      case MemoryCadence.daily1:
        return DateTimeComponents.time;

      case MemoryCadence.monthly:
        return DateTimeComponents.dayOfMonthAndTime;

      default:
        return null;
    }
  }

  // ============================================================
  // GUARDAR NOTIFICACIÓN INTERNA DE RECUERDO
  // ============================================================

  static Future<void> _saveMemoryInAppNotifications({
    required String memoryId,
    required String title,
    required DateTime dateTime,
    required MemoryCadence cadence,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    try {
      final notificationDocumentId =
          'memory_${_baseIdStable(memoryId)}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationDocumentId)
          .set(
        {
          'title': 'Recordatorio de recuerdo',
          'body': title,
          'type': 'memory',
          'memoryId': memoryId,
          'payload': memoryId,
          'cadence': cadence.name,
          'timestamp': Timestamp.fromDate(dateTime),
          'read': false,
          'deleted': false,
          'completed': false,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error, stackTrace) {
      debugPrint('Error guardando notificación interna de recuerdo: $error');
      debugPrint(stackTrace.toString());
    }
  }

  // ============================================================
  // REPROGRAMAR UN RECUERDO DESDE SU PAYLOAD
  // ============================================================

  static Future<void> rescheduleNextFromPayload(
    String memoryId,
  ) async {
    try {
      final parts = memoryId.split('/');

      if (parts.length != 2) {
        return;
      }

      final uid = parts[0].trim();
      final documentId = parts[1].trim();

      if (uid.isEmpty || documentId.isEmpty) {
        return;
      }

      final documentReference = FirebaseFirestore.instance
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .doc(documentId);

      final document = await documentReference.get();

      if (!document.exists) {
        return;
      }

      final data = document.data() ?? <String, dynamic>{};
      final reminderValue = data['reminder'];

      if (reminderValue is! Map) {
        return;
      }

      final reminder = Map<String, dynamic>.from(reminderValue);

      final enabled = reminder['enabled'] == true;
      final deleted = reminder['deleted'] == true;
      final completed = reminder['completed'] == true;

      if (!enabled || deleted || completed) {
        await cancelForMemory(memoryId);
        return;
      }

      final cadenceText =
          reminder['cadence']?.toString().toLowerCase().trim() ??
              'weekly';

      final cadence = cadenceFromString(cadenceText);

      DateTime? parsedNextAt;

      final nextAtValue = reminder['nextAt'];

      if (nextAtValue is Timestamp) {
        parsedNextAt = nextAtValue.toDate().toLocal();
      } else if (nextAtValue is DateTime) {
        parsedNextAt = nextAtValue.toLocal();
      } else if (nextAtValue is String) {
        parsedNextAt = DateTime.tryParse(nextAtValue)?.toLocal();
      }

      DateTime? createdAt;

      final createdAtValue = data['createdAt'];

      if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate().toLocal();
      } else if (createdAtValue is DateTime) {
        createdAt = createdAtValue.toLocal();
      } else if (createdAtValue is String) {
        createdAt = DateTime.tryParse(createdAtValue)?.toLocal();
      }

      DateTime nextAt =
          parsedNextAt ?? (createdAt ?? DateTime.now()).add(
            const Duration(days: 7),
          );

      final now = DateTime.now();

      while (!nextAt.isAfter(now)) {
        nextAt = _addCadence(nextAt, cadence);
      }

      final text = data['text']?.toString().trim() ?? '';

      final safeTitle = text.isEmpty
          ? 'Tienes un recuerdo guardado para volver a ver.'
          : text;

      await documentReference.set(
        {
          'reminder.enabled': true,
          'reminder.cadence': cadenceText,
          'reminder.nextAt': Timestamp.fromDate(nextAt),
          'reminder.read': false,
          'reminder.deleted': false,
          'reminder.completed': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await scheduleForMemory(
        memoryId: memoryId,
        title: safeTitle,
        anchorDate: nextAt,
        cadence: cadence,
      );

      debugPrint(
        'Recordatorio recuperado correctamente: $memoryId para $nextAt',
      );
    } catch (error, stackTrace) {
      debugPrint('Error recuperando recordatorio de recuerdo: $error');
      debugPrint(stackTrace.toString());
    }
  }
    // ============================================================
  // CANCELAR RECORDATORIO DE RECUERDO
  // ============================================================

  static Future<void> cancelForMemory(
    String memoryId,
  ) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    final notificationId = _baseIdStable(memoryId);

    await _plugin.cancel(notificationId);
  }

  static Future<void> cancelAllForMemory(
    String memoryId,
  ) async {
    await cancelForMemory(memoryId);
  }

  // ============================================================
  // CANCELAR NOTIFICACIÓN POR ID
  // ============================================================

  static Future<void> cancel(
    int id,
  ) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    await _plugin.cancel(id);
  }

  // ============================================================
  // CANCELAR TODAS LAS NOTIFICACIONES LOCALES
  // ============================================================

  static Future<void> cancelAll() async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    await _plugin.cancelAll();
  }

  // ============================================================
  // OBTENER NOTIFICACIONES PENDIENTES DEL DISPOSITIVO
  // ============================================================

  static Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async {
    await ensureInitialized();

    if (kIsWeb) {
      return <PendingNotificationRequest>[];
    }

    try {
      return await _plugin.pendingNotificationRequests();
    } catch (error, stackTrace) {
      debugPrint('Error obteniendo notificaciones pendientes: $error');
      debugPrint(stackTrace.toString());

      return <PendingNotificationRequest>[];
    }
  }

  // ============================================================
  // OBTENER CANTIDAD DE NOTIFICACIONES INTERNAS PENDIENTES
  // ============================================================

  static Future<int> getPendingCount() async {
    return getUnreadAppNotificationCount();
  }

  // ============================================================
  // MOSTRAR ALERTA DE EMERGENCIA
  // ============================================================

  static Future<void> showEmergencyAlert({
    required String title,
    required String body,
    String? emergencyKey,
    bool saveInFirestore = true,
  }) async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    final normalizedKey =
        emergencyKey?.trim().isNotEmpty == true
            ? emergencyKey!.trim()
            : '$title|$body';

    final now = DateTime.now();

    _removeExpiredEmergencyKeys(now);

    final lastProcessedAt = _processedEmergencyTimes[normalizedKey];

    if (lastProcessedAt != null &&
        now.difference(lastProcessedAt) < _emergencyDuplicateWindow) {
      debugPrint('Emergencia duplicada ignorada: $normalizedKey');
      return;
    }

    if (_processedEmergencyKeys.contains(normalizedKey)) {
      debugPrint('Emergencia ya procesada ignorada: $normalizedKey');
      return;
    }

    _processedEmergencyKeys.add(normalizedKey);
    _processedEmergencyTimes[normalizedKey] = now;

    await _trimPending();

    final androidDetails = AndroidNotificationDetails(
      _emergencyChannelId,
      _emergencyChannelName,
      channelDescription: _emergencyChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: _emergencyVibrationPattern,
      groupKey: _emergencyGroupKey,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
      ticker: 'Emergencia detectada',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = _baseIdStable(
      'emergency/$normalizedKey',
    );

    final payload = 'emergency/$normalizedKey';

    await _plugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    if (saveInFirestore) {
      await _saveEmergencyInAppNotifications(
        notificationId: notificationId,
        title: title,
        body: body,
        emergencyKey: normalizedKey,
      );
    }

    await _updateEmergencySummary();
  }

  // ============================================================
  // LIMPIAR CLAVES DE EMERGENCIA ANTIGUAS
  // ============================================================

  static void _removeExpiredEmergencyKeys(
    DateTime now,
  ) {
    final expiredKeys = _processedEmergencyTimes.entries
        .where(
          (entry) {
            return now.difference(entry.value) >=
                _emergencyDuplicateWindow;
          },
        )
        .map(
          (entry) => entry.key,
        )
        .toList();

    for (final key in expiredKeys) {
      _processedEmergencyTimes.remove(key);
      _processedEmergencyKeys.remove(key);
    }
  }
    // ============================================================
  // ACTUALIZAR RESUMEN DE EMERGENCIAS
  // ============================================================

  static Future<void> _updateEmergencySummary() async {
    if (kIsWeb) {
      return;
    }

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final activeNotifications =
        await androidPlugin?.getActiveNotifications() ??
            <ActiveNotification>[];

    final emergencies = activeNotifications.where(
      (notification) {
        final channelId = notification.channelId ?? '';
        final groupKey = notification.groupKey ?? '';

        return notification.id != 0 &&
            (channelId == _emergencyChannelId ||
                groupKey == _emergencyGroupKey);
      },
    ).toList();

    if (emergencies.length > 5) {
      final excess = emergencies.length - 5;

      for (var index = 0; index < excess; index++) {
        final id = emergencies[index].id;

        if (id != null) {
          await _plugin.cancel(id);
        }
      }
    }

    final updatedNotifications =
        await androidPlugin?.getActiveNotifications() ??
            <ActiveNotification>[];

    final updatedEmergencies = updatedNotifications.where(
      (notification) {
        final channelId = notification.channelId ?? '';
        final groupKey = notification.groupKey ?? '';

        return notification.id != 0 &&
            (channelId == _emergencyChannelId ||
                groupKey == _emergencyGroupKey);
      },
    ).toList();

    final visibleCount = min(updatedEmergencies.length, 5);

    if (visibleCount <= 0) {
      await _plugin.cancel(0);
      return;
    }

    await _plugin.show(
      0,
      'Emergencias activas',
      visibleCount == 1
          ? 'Tienes 1 emergencia reciente.'
          : 'Tienes $visibleCount emergencias recientes.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _emergencyChannelId,
          _emergencyChannelName,
          channelDescription: _emergencyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          setAsGroupSummary: true,
          groupKey: _emergencyGroupKey,
          playSound: false,
          enableVibration: false,
        ),
      ),
      payload: 'emergency/summary',
    );
  }

  // ============================================================
  // GUARDAR EMERGENCIA EN FIRESTORE
  // ============================================================

  static Future<void> _saveEmergencyInAppNotifications({
    required int notificationId,
    required String title,
    required String body,
    required String emergencyKey,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    try {
      final documentId = 'emergency_${_baseIdStable(emergencyKey)}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(documentId)
          .set(
        {
          'title': title,
          'body': body,
          'type': 'emergency',
          'emergencyKey': emergencyKey,
          'payload': 'emergency/$emergencyKey',
          'androidNotificationId': notificationId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'deleted': false,
          'completed': false,
          'active': true,
          'resolved': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (error, stackTrace) {
      debugPrint('Error guardando emergencia interna: $error');
      debugPrint(stackTrace.toString());
    }
  }

  // ============================================================
  // CERRAR UNA EMERGENCIA CONCRETA
  // ============================================================

  static Future<void> closeEmergencyAlert({
    required String emergencyKey,
    String? notificationDocumentId,
  }) async {
    await ensureInitialized();

    final normalizedKey = emergencyKey.trim();

    if (normalizedKey.isEmpty) {
      return;
    }

    final notificationId = _baseIdStable(
      'emergency/$normalizedKey',
    );

    if (!kIsWeb) {
      await _plugin.cancel(notificationId);
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      final documentId =
          notificationDocumentId?.trim().isNotEmpty == true
              ? notificationDocumentId!.trim()
              : 'emergency_${_baseIdStable(normalizedKey)}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(documentId)
          .set(
        {
          'read': true,
          'deleted': true,
          'completed': true,
          'active': false,
          'resolved': true,
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    _processedEmergencyKeys.add(normalizedKey);
    _processedEmergencyTimes[normalizedKey] = DateTime.now();

    await _updateEmergencySummary();

    debugPrint('Emergencia cerrada: $normalizedKey');
  }
    // ============================================================
  // RETIRAR EMERGENCIAS VISIBLES DEL DISPOSITIVO
  // ============================================================

  static Future<void> clearVisibleEmergencyAlerts() async {
    await ensureInitialized();

    if (kIsWeb) {
      return;
    }

    try {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final activeNotifications =
          await androidPlugin?.getActiveNotifications() ??
              <ActiveNotification>[];

      for (final notification in activeNotifications) {
        final channelId = notification.channelId ?? '';
        final groupKey = notification.groupKey ?? '';
        final notificationId = notification.id;

        final isEmergency =
            channelId == _emergencyChannelId ||
            groupKey == _emergencyGroupKey ||
            notificationId == 0;

        if (isEmergency && notificationId != null) {
          await _plugin.cancel(notificationId);
        }
      }

      await _plugin.cancel(0);

      final pendingNotifications =
          await _plugin.pendingNotificationRequests();

      for (final notification in pendingNotifications) {
        final payload =
            notification.payload?.toLowerCase().trim() ?? '';

        final isEmergency =
            payload == 'emergency' ||
            payload == 'emergencia' ||
            payload.startsWith('emergency/') ||
            payload.startsWith('emergencia/');

        if (isEmergency) {
          await _plugin.cancel(notification.id);
        }
      }

      debugPrint('Alertas visibles de emergencia retiradas.');
    } catch (error, stackTrace) {
      debugPrint('Error retirando alertas visibles de emergencia: $error');
      debugPrint(stackTrace.toString());
    }
  }

  // ============================================================
  // ELIMINAR TODAS LAS EMERGENCIAS INTERNAS
  // ============================================================

  static Future<void> clearEmergencyAlerts() async {
    await ensureInitialized();

    try {
      if (!kIsWeb) {
        await clearVisibleEmergencyAlerts();
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        return;
      }

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

      final snapshot = await collection.get();
      final batch = FirebaseFirestore.instance.batch();

      var modifiedCount = 0;

      for (final document in snapshot.docs) {
        final data = document.data();

        final type =
            data['type']?.toString().toLowerCase().trim() ?? '';
        final payload =
            data['payload']?.toString().toLowerCase().trim() ?? '';
        final title =
            data['title']?.toString().toLowerCase().trim() ?? '';
        final body =
            data['body']?.toString().toLowerCase().trim() ?? '';

        final isEmergency =
            type == 'emergency' ||
            type == 'emergencia' ||
            type == 'emergency_alert' ||
            type == 'panic' ||
            type == 'panic_alert' ||
            payload == 'emergency' ||
            payload == 'emergencia' ||
            payload.startsWith('emergency/') ||
            payload.startsWith('emergencia/') ||
            title.contains('emergencia') ||
            body.contains('emergencia');

        if (!isEmergency) {
          continue;
        }

        batch.set(
          document.reference,
          {
            'read': true,
            'deleted': true,
            'completed': true,
            'active': false,
            'resolved': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'resolvedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        final emergencyKey = data['emergencyKey']?.toString().trim();

        if (emergencyKey != null && emergencyKey.isNotEmpty) {
          _processedEmergencyKeys.add(emergencyKey);
          _processedEmergencyTimes[emergencyKey] = DateTime.now();
        }

        modifiedCount++;
      }

      if (modifiedCount > 0) {
        await batch.commit();
      }

      debugPrint('Emergencias internas eliminadas: $modifiedCount');
    } catch (error, stackTrace) {
      debugPrint('Error eliminando alertas de emergencia: $error');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // ============================================================
  // GENERAR ID ESTABLE
  // ============================================================

  static int _baseIdStable(String value) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final combined = '$uid-$value';
    final hash = _fnv1a32(combined);

    return (hash % 900000) + 100000;
  }

  // ============================================================
  // HASH FNV-1A
  // ============================================================

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

  // ============================================================
  // SUMAR FRECUENCIA
  // ============================================================

  static DateTime _addCadence(
    DateTime date,
    MemoryCadence cadence,
  ) {
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

  // ============================================================
  // SUMAR MESES SIN ROMPER FECHAS
  // ============================================================

  static DateTime _addMonths(
    DateTime date,
    int monthsToAdd,
  ) {
    final newMonth = date.month + monthsToAdd;
    final year = date.year + ((newMonth - 1) ~/ 12);
    final month = ((newMonth - 1) % 12) + 1;

    final day = min(
      date.day,
      _daysInMonth(year, month),
    );

    return DateTime(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  // ============================================================
  // OBTENER DÍAS DEL MES
  // ============================================================

  static int _daysInMonth(
    int year,
    int month,
  ) {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);

    return nextMonth.difference(DateTime(year, month, 1)).inDays;
  }

  static Stream<int> watchUnreadNotificationsCountForCurrentUser() async* {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    yield 0;
    return;
  }

  yield await getUnreadNotificationsCountForUser(uid);

  yield* Stream.periodic(
    const Duration(seconds: 2),
  ).asyncMap((_) {
    return getUnreadNotificationsCountForUser(uid);
  });
}

static Future<int> getUnreadNotificationsCountForUser(String uid) async {
  await ensureInitialized();

  final pendingList = await pendingNotificationRequests();

  final unreadLocalReminders = pendingList.where((notification) {
    final payload = notification.payload?.trim() ?? '';

    // Solo se cuentan los recordatorios generales. Los recuerdos se cuentan
    // desde Firestore mediante reminder.read para evitar duplicados.
    return payload.startsWith('reminder/');
  }).length;

  final appSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .get();

  final unreadAppCount = appSnapshot.docs.where((document) {
    final data = document.data();

    final read = data['read'] == true;
    final deleted = data['deleted'] == true;
    final completed = data['completed'] == true;
    final resolved = data['resolved'] == true;

    final activeValue = data['active'];
    final inactive = activeValue != null && activeValue == false;

    final type = data['type']?.toString().trim().toLowerCase() ?? 'general';

    final duplicateType = type == 'reminder' ||
        type == 'memory' ||
        type == 'emergency' ||
        type == 'emergencia' ||
        type == 'emergency_alert' ||
        type == 'panic' ||
        type == 'panic_alert';

    return !read &&
        !deleted &&
        !completed &&
        !resolved &&
        !inactive &&
        !duplicateType;
  }).length;

  final emergencySnapshot = await FirebaseFirestore.instance
      .collection('emergencies')
      .where('caregiverId', isEqualTo: uid)
      .get();

  final unreadEmergencyCount = emergencySnapshot.docs.where((document) {
    final data = document.data();

    final active = data['active'] == true;
    final read = data['read'] == true;
    final deleted = data['deleted'] == true;
    final resolved = data['resolved'] == true;
    final completed = data['completed'] == true;

    return active && !read && !deleted && !resolved && !completed;
  }).length;

  final memoriesSnapshot = await FirebaseFirestore.instance
      .collection('memories')
      .doc(uid)
      .collection('user_memories')
      .get();

  final unreadMemoryCount = memoriesSnapshot.docs.where((document) {
    final data = document.data();
    final reminderValue = data['reminder'];

    if (reminderValue is! Map) {
      return false;
    }

    final reminder = Map<String, dynamic>.from(reminderValue);

    final enabled = reminder['enabled'] == true;
    final read = reminder['read'] == true;
    final deleted = reminder['deleted'] == true;
    final completed = reminder['completed'] == true;
    final nextAt = reminder['nextAt'];

    return enabled && !read && !deleted && !completed && nextAt != null;
  }).length;

  return unreadLocalReminders +
      unreadAppCount +
      unreadEmergencyCount +
      unreadMemoryCount;
}

  // ============================================================
  // PRUEBA DE NOTIFICACIÓN
  // ============================================================

  static Future<void> scheduleTest() async {
    await ensureInitialized();

    await showInstant(
      title: 'Prueba de WhoAmI',
      body: 'El sistema de notificaciones está funcionando.',
      payload: 'test',
    );
  }
}