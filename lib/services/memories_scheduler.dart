import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_service.dart';

/// Nuevo esquema (OFICIAL):
/// displayDate: "YYYY-MM-DD"
/// reminder: {
///   enabled: bool,
///   cadence: "weekly"|"biweekly"|"monthly"|...,
///   time: "HH:mm",
///   timezone: "America/Mexico_City",
///   nextAt: Timestamp
/// }
///
/// Regla:
/// - Para programar notificaciones SIEMPRE usamos reminder.nextAt.
/// - Si un doc está en esquema viejo (date/frequency), lo migramos una vez.
class MemoriesScheduler {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Programa recordatorios para TODOS los recuerdos del usuario.
  static Future<void> scheduleAllForUser(String uid) async {
    final coll = _db.collection('memories').doc(uid).collection('user_memories');

    final snap = await coll.get();
    for (final doc in snap.docs) {
      await _scheduleFromDoc(uid, doc);
    }
  }

  /// Programa recordatorio para UN recuerdo por id.
  static Future<void> scheduleOneById(String uid, String memoryId) async {
    final ref = _db
        .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .doc(memoryId);

    final doc = await ref.get();
    if (!doc.exists) return;

    await _scheduleFromDoc(uid, doc);
  }

  /// Lee campos del doc y llama a NotificationsService.scheduleForMemory().
  static Future<void> _scheduleFromDoc(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;

    final memoryDocId = doc.id;

    // title: usa 'text' si existe, si no, un texto genérico
    final title = (data['text'] as String?)?.trim();
    final safeTitle = (title == null || title.isEmpty) ? 'Tu recuerdo' : title;

    // 1) Intentar nuevo esquema
    final reminder = data['reminder'];
    if (reminder is Map) {
      final enabled = reminder['enabled'] == true;
      if (!enabled) return;

      final nextAtField = reminder['nextAt'];
      DateTime? nextAt;

      if (nextAtField is Timestamp) {
        nextAt = nextAtField.toDate().toLocal();
      } else if (nextAtField is String) {
        try {
          nextAt = DateTime.parse(nextAtField).toLocal();
        } catch (_) {}
      }

      if (nextAt == null) return;

      // Si nextAt quedó en el pasado, lo empujamos a futuro y actualizamos Firestore
      final now = DateTime.now();
      if (nextAt.isBefore(now)) {
        nextAt = now.add(const Duration(minutes: 1));
        await _db
            .collection('memories')
            .doc(uid)
            .collection('user_memories')
            .doc(memoryDocId)
            .update({
          'reminder.nextAt': Timestamp.fromDate(nextAt),
        });
      }

      final cadenceRaw =
          (reminder['cadence'] as String?)?.toLowerCase().trim() ?? 'monthly';

      // ✅ USAR LA FUNCIÓN REAL DE notifications_service.dart (NO duplicar)
      final MemoryCadence cadence = cadenceFromString(cadenceRaw);

      await NotificationsService.scheduleForMemory(
        memoryId: '$uid/$memoryDocId',
        title: safeTitle,
        anchorDate: nextAt,
        cadence: cadence,
      );

      return;
    }

    // 2) Si NO existe reminder, es doc viejo -> migramos y programamos
    final migrated = await _migrateLegacyDoc(uid, memoryDocId, data);
    if (!migrated) return;

    // Releer ya migrado y programar
    final fresh = await _db
        .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .doc(memoryDocId)
        .get();

    if (!fresh.exists) return;
    await _scheduleFromDoc(uid, fresh);
  }

  /// Migra un doc con esquema viejo (date/frequency) al nuevo esquema.
  static Future<bool> _migrateLegacyDoc(
    String uid,
    String memoryDocId,
    Map<String, dynamic> data,
  ) async {
    DateTime? anchor;
    final dateField = data['date'];

    if (dateField is String) {
      try {
        anchor = DateTime.parse(dateField).toLocal();
      } catch (_) {}
    } else if (dateField is Timestamp) {
      anchor = dateField.toDate().toLocal();
    }

    if (anchor == null) return false;

    final freqRaw =
        (data['frequency'] as String?)?.toLowerCase().trim() ?? 'monthly';

    final displayDate =
        "${anchor.year}-${anchor.month.toString().padLeft(2, '0')}-${anchor.day.toString().padLeft(2, '0')}";

    final timeStr =
        "${anchor.hour.toString().padLeft(2, '0')}:${anchor.minute.toString().padLeft(2, '0')}";

    final now = DateTime.now();
    DateTime nextAt = anchor;
    if (nextAt.isBefore(now)) {
      nextAt = now.add(const Duration(minutes: 1));
    }

    await _db
        .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .doc(memoryDocId)
        .update({
      'displayDate': (data['displayDate'] as String?) ?? displayDate,
      'reminder': {
        'enabled': true,
        'cadence': freqRaw,
        'time': timeStr,
        'timezone': 'America/Mexico_City',
        'nextAt': Timestamp.fromDate(nextAt),
      },

      // recomendado: limpiar campos viejos
      'date': FieldValue.delete(),
      'frequency': FieldValue.delete(),
    });

    return true;
  }
}
