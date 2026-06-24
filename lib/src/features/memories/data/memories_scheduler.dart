import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';

/// Recupera y programa los recordatorios semanales de los recuerdos.
///
/// Esquema actual de cada recuerdo:
///
/// displayDate: "YYYY-MM-DD"
///
/// reminder: {
///   enabled: true,
///   cadence: "weekly",
///   time: "HH:mm",
///   timezone: "America/Mexico_City",
///   nextAt: Timestamp,
///   read: false,
///   deleted: false,
///   completed: false
/// }
///
/// Funcionamiento:
/// - El primer recordatorio se programa siete días después de guardar.
/// - Después se repite semanalmente.
/// - Si la fecha almacenada ya pasó, se busca la siguiente semana futura.
/// - Los documentos antiguos se migran automáticamente.
/// - La repetición semanal real la registra NotificationsService en Android.
class MemoriesScheduler {
  MemoriesScheduler._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _timezone =
      'America/Mexico_City';

  static const String _weeklyCadence =
      'weekly';

  // ============================================================
  // PROGRAMAR TODOS LOS RECUERDOS DE UN USUARIO
  // ============================================================

  static Future<void> scheduleAllForUser(
    String uid,
  ) async {
    final safeUid =
        uid.trim();

    if (safeUid.isEmpty) {
      return;
    }

    try {
      final snapshot =
          await _memoriesCollection(
        safeUid,
      ).get();

      for (final document in snapshot.docs) {
        try {
          await _scheduleFromDocument(
            uid: safeUid,
            document: document,
          );
        } catch (error, stackTrace) {
          debugPrint(
            'Error programando el recuerdo ${document.id}: $error',
          );

          debugPrint(
            stackTrace.toString(),
          );
        }
      }

      debugPrint(
        'Recordatorios de recuerdos recuperados para el usuario $safeUid.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error cargando los recuerdos del usuario $safeUid: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // PROGRAMAR UN RECUERDO POR ID
  // ============================================================

  static Future<void> scheduleOneById(
    String uid,
    String memoryId,
  ) async {
    final safeUid =
        uid.trim();

    final safeMemoryId =
        memoryId.trim();

    if (safeUid.isEmpty ||
        safeMemoryId.isEmpty) {
      return;
    }

    try {
      final document =
          await _memoriesCollection(
        safeUid,
      ).doc(
        safeMemoryId,
      ).get();

      if (!document.exists) {
        debugPrint(
          'El recuerdo $safeMemoryId no existe.',
        );

        return;
      }

      await _scheduleFromDocument(
        uid: safeUid,
        document: document,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error programando el recuerdo $safeMemoryId: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // LEER Y PROGRAMAR UN DOCUMENTO
  // ============================================================

  static Future<void> _scheduleFromDocument({
    required String uid,
    required DocumentSnapshot<Map<String, dynamic>>
        document,
  }) async {
    final data =
        document.data();

    if (data == null) {
      return;
    }

    final memoryId =
        document.id;

    final payload =
        '$uid/$memoryId';

    final reminderValue =
        data['reminder'];

    // Si todavía utiliza el esquema anterior, se migra.
    if (reminderValue is! Map) {
      final migrated =
          await _migrateLegacyDocument(
        uid: uid,
        memoryId: memoryId,
        data: data,
      );

      if (!migrated) {
        return;
      }

      final migratedDocument =
          await _memoriesCollection(
        uid,
      ).doc(
        memoryId,
      ).get();

      if (!migratedDocument.exists) {
        return;
      }

      await _scheduleFromDocument(
        uid: uid,
        document: migratedDocument,
      );

      return;
    }

    final reminder =
        Map<String, dynamic>.from(
      reminderValue,
    );

    final enabled =
        reminder['enabled'] == true;

    final deleted =
        reminder['deleted'] == true;

    final completed =
        reminder['completed'] == true;

    // Un recordatorio desactivado, eliminado o completado
    // no debe continuar registrado en Android.
    if (!enabled ||
        deleted ||
        completed) {
      await NotificationsService.cancelForMemory(
        payload,
      );

      return;
    }

    final createdAt =
        _resolveCreationDate(
      data,
    );

    DateTime nextAt =
        _parseDateTime(
          reminder['nextAt'],
        ) ??
        createdAt.add(
          const Duration(
            days: 7,
          ),
        );

    nextAt =
        _moveToNextWeeklyDate(
      date: nextAt,
      now: DateTime.now(),
    );

    final title =
        _memoryTitle(
      data,
    );

    await document.reference.set({
      'reminder.enabled':
          true,
      'reminder.cadence':
          _weeklyCadence,
      'reminder.time':
          _formatTime(
        nextAt,
      ),
      'reminder.timezone':
          _timezone,
      'reminder.nextAt':
          Timestamp.fromDate(
        nextAt,
      ),
      'reminder.deleted':
          false,
      'reminder.completed':
          false,
      'updatedAt':
          FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await NotificationsService.scheduleForMemory(
      memoryId:
          payload,
      title:
          title,
      anchorDate:
          nextAt,
      cadence:
          MemoryCadence.weekly,
    );

    debugPrint(
      'Recuerdo $memoryId programado semanalmente desde $nextAt.',
    );
  }

  // ============================================================
  // MIGRAR RECUERDO ANTIGUO
  // ============================================================

  static Future<bool> _migrateLegacyDocument({
    required String uid,
    required String memoryId,
    required Map<String, dynamic> data,
  }) async {
    final creationDate =
        _resolveCreationDateOrNull(
      data,
    );

    if (creationDate == null) {
      debugPrint(
        'No se pudo migrar el recuerdo $memoryId porque no contiene una fecha válida.',
      );

      return false;
    }

    DateTime nextAt =
        creationDate.add(
      const Duration(
        days: 7,
      ),
    );

    nextAt =
        _moveToNextWeeklyDate(
      date: nextAt,
      now: DateTime.now(),
    );

    final storedDisplayDate =
        data['displayDate']
            ?.toString()
            .trim();

    final displayDate =
        storedDisplayDate != null &&
                storedDisplayDate.isNotEmpty
            ? storedDisplayDate
            : _formatDate(
                creationDate,
              );

    await _memoriesCollection(
      uid,
    ).doc(
      memoryId,
    ).set({
      'displayDate':
          displayDate,
      'reminder': {
        'enabled':
            true,
        'cadence':
            _weeklyCadence,
        'time':
            _formatTime(
          nextAt,
        ),
        'timezone':
            _timezone,
        'nextAt':
            Timestamp.fromDate(
          nextAt,
        ),
        'read':
            false,
        'deleted':
            false,
        'completed':
            false,
      },
      'date':
          FieldValue.delete(),
      'frequency':
          FieldValue.delete(),
      'updatedAt':
          FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      'Recuerdo antiguo $memoryId migrado al esquema semanal.',
    );

    return true;
  }

  // ============================================================
  // CALCULAR LA SIGUIENTE SEMANA FUTURA
  // ============================================================

  static DateTime _moveToNextWeeklyDate({
    required DateTime date,
    required DateTime now,
  }) {
    DateTime nextDate =
        date;

    while (!nextDate.isAfter(now)) {
      nextDate =
          nextDate.add(
        const Duration(
          days: 7,
        ),
      );
    }

    return nextDate;
  }

  // ============================================================
  // OBTENER FECHA DE CREACIÓN
  // ============================================================

  static DateTime _resolveCreationDate(
    Map<String, dynamic> data,
  ) {
    return _resolveCreationDateOrNull(
          data,
        ) ??
        DateTime.now();
  }

  static DateTime? _resolveCreationDateOrNull(
    Map<String, dynamic> data,
  ) {
    final createdAt =
        _parseDateTime(
      data['createdAt'],
    );

    if (createdAt != null) {
      return createdAt;
    }

    final legacyDate =
        _parseDateTime(
      data['date'],
    );

    if (legacyDate != null) {
      return legacyDate;
    }

    final displayDate =
        data['displayDate']
            ?.toString()
            .trim();

    if (displayDate == null ||
        displayDate.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      displayDate,
    )?.toLocal();
  }

  // ============================================================
  // CONVERTIR FECHAS
  // ============================================================

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value is Timestamp) {
      return value
          .toDate()
          .toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is String) {
      final safeValue =
          value.trim();

      if (safeValue.isEmpty) {
        return null;
      }

      return DateTime.tryParse(
        safeValue,
      )?.toLocal();
    }

    return null;
  }

  // ============================================================
  // TEXTO DE LA NOTIFICACIÓN
  // ============================================================

  static String _memoryTitle(
    Map<String, dynamic> data,
  ) {
    final text =
        data['text']
                ?.toString()
                .trim() ??
            '';

    if (text.isNotEmpty) {
      return text;
    }

    return 'Tienes un recuerdo guardado para volver a ver.';
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  static String _formatDate(
    DateTime date,
  ) {
    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${date.year}-$month-$day';
  }

  // ============================================================
  // FORMATEAR HORA
  // ============================================================

  static String _formatTime(
    DateTime date,
  ) {
    final hour =
        date.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$hour:$minute';
  }

  // ============================================================
  // REFERENCIA A LA COLECCIÓN DE RECUERDOS
  // ============================================================

  static CollectionReference<Map<String, dynamic>>
      _memoriesCollection(
    String uid,
  ) {
    return _firestore
        .collection('memories')
        .doc(uid)
        .collection('user_memories');
  }
}