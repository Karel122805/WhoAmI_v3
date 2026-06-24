// lib/src/features/notifications/presentation/pages/notifications_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/emergency/presentation/pages/emergency_map_page.dart';
import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
  });

  static const String route = '/notifications';

  @override
  State<NotificationsPage> createState() {
    return _NotificationsPageState();
  }
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<PendingNotificationRequest> _pendingReminders =
      <PendingNotificationRequest>[];

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _appNotifications =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _emergencies =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _memoryNotifications =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  final Set<String> _selectedKeys = <String>{};

  bool _loading = false;
  bool _selectMode = false;
  bool _resolvingEmergency = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAll();
      }
    });
  }

  // ============================================================
  // CLAVES DE SELECCIÓN
  // ============================================================

  String _pendingKey(int id) {
    return 'pending_$id';
  }

  String _appKey(String id) {
    return 'app_$id';
  }

  String _emergencyKey(String id) {
    return 'emergency_$id';
  }

  String _memoryKey(String id) {
    return 'memory_$id';
  }

  // ============================================================
  // FECHAS
  // ============================================================

  DateTime _parseDateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _parseNullableDateValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatDateTime(DateTime date) {
    final String day =
        date.day.toString().padLeft(2, '0');

    final String month =
        date.month.toString().padLeft(2, '0');

    final String year =
        date.year.toString();

    final String hour =
        date.hour.toString().padLeft(2, '0');

    final String minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }

  // ============================================================
  // IDENTIFICAR NOTIFICACIONES INTERNAS DE EMERGENCIA
  // ============================================================

  bool _isInternalEmergency(
    Map<String, dynamic> data,
  ) {
    final String type =
        data['type']?.toString().trim().toLowerCase() ?? '';

    final String payload =
        data['payload']?.toString().trim().toLowerCase() ?? '';

    return type == 'emergency' ||
        type == 'emergencia' ||
        type == 'emergency_alert' ||
        type == 'panic' ||
        type == 'panic_alert' ||
        payload == 'emergency' ||
        payload == 'emergencia' ||
        payload.startsWith('emergency/') ||
        payload.startsWith('emergencia/');
  }

  bool _matchesEmergencyDocument(
    Map<String, dynamic> data,
    String emergencyId,
  ) {
    if (!_isInternalEmergency(data)) {
      return false;
    }

    final String emergencyKey =
        data['emergencyKey']?.toString().trim() ?? '';

    final String storedEmergencyId =
        data['emergencyId']?.toString().trim() ?? '';

    final String payload =
        data['payload']?.toString().trim() ?? '';

    return emergencyKey == emergencyId ||
        storedEmergencyId == emergencyId ||
        payload == 'emergency/$emergencyId' ||
        payload == 'emergencia/$emergencyId';
  }

  // ============================================================
  // ACTUALIZAR COPIAS INTERNAS DE UNA EMERGENCIA
  // ============================================================

  Future<void> _updateInternalEmergencyNotifications({
    required String emergencyId,
    required bool read,
    required bool deleted,
    required bool resolved,
  }) async {
    final String? uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .get();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> matches =
        snapshot.docs.where((document) {
      return _matchesEmergencyDocument(
        document.data(),
        emergencyId,
      );
    }).toList();

    if (matches.isEmpty) {
      return;
    }

    final WriteBatch batch =
        firestore.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in matches) {
      final Map<String, dynamic> values =
          <String, dynamic>{
        'read': read,
        'deleted': deleted,
        'resolved': resolved,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (read) {
        values['readAt'] =
            FieldValue.serverTimestamp();
      }

      if (resolved) {
        values.addAll(
          <String, dynamic>{
            'active': false,
            'completed': true,
            'resolvedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      if (deleted) {
        values.addAll(
          <String, dynamic>{
            'active': false,
            'completed': true,
            'deletedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      batch.set(
        document.reference,
        values,
        SetOptions(
          merge: true,
        ),
      );
    }

    await batch.commit();
  }

  // ============================================================
  // OPERACIONES SECUNDARIAS SEGURAS
  // No deben hacer fallar la actualización principal.
  // ============================================================

  Future<void> _safeUpdateInternalEmergencyNotifications({
    required String emergencyId,
    required bool read,
    required bool deleted,
    required bool resolved,
  }) async {
    try {
      await _updateInternalEmergencyNotifications(
        emergencyId: emergencyId,
        read: read,
        deleted: deleted,
        resolved: resolved,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo actualizar la copia interna de emergencia: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  Future<void> _cancelEmergencyLocalNotification(
    String emergencyId,
  ) async {
    try {
      final List<PendingNotificationRequest> pending =
          await NotificationsService.pendingNotificationRequests();

      for (final PendingNotificationRequest notification in pending) {
        final String payload =
            notification.payload?.trim() ?? '';

        final bool belongsToEmergency =
            payload == 'emergency/$emergencyId' ||
                payload == 'emergencia/$emergencyId';

        if (belongsToEmergency) {
          await NotificationsService.cancel(
            notification.id,
          );
        }
      }

      await NotificationsService.cancel(0);
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo cancelar la alerta local de emergencia: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // MARCAR EMERGENCIA COMO LEÍDA
  // ============================================================

  Future<bool> _markEmergencyAsRead(
    String documentId,
  ) async {
    try {
      final DocumentReference<Map<String, dynamic>> emergencyReference =
          FirebaseFirestore.instance
              .collection('emergencies')
              .doc(documentId);

      await emergencyReference.update(
        <String, dynamic>{
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await _safeUpdateInternalEmergencyNotifications(
        emergencyId: documentId,
        read: true,
        deleted: false,
        resolved: false,
      );

      await _cancelEmergencyLocalNotification(
        documentId,
      );

      if (mounted) {
        setState(() {
          final int index = _emergencies.indexWhere(
            (document) => document.id == documentId,
          );

          if (index >= 0) {
            // La lista se refrescará desde Firestore.
          }
        });

        await _loadAll();
      }

      return true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firebase error marcando emergencia como leída: '
        '${error.code} - ${error.message}',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (mounted) {
        await _showOkDialog(
          context,
          title: 'No se pudo actualizar',
          message: error.code == 'permission-denied'
              ? 'Tu cuenta no tiene permiso para actualizar esta emergencia.'
              : 'No se pudo marcar la emergencia como leída.',
        );
      }

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'Error marcando emergencia como leída: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (mounted) {
        await _showOkDialog(
          context,
          title: 'Error',
          message:
              'No se pudo marcar la emergencia como leída.',
        );
      }

      return false;
    }
  }

  // ============================================================
  // MARCAR EMERGENCIA COMO ATENDIDA
  // ============================================================

  Future<bool> _resolveEmergency(
    String documentId,
  ) async {
    if (_resolvingEmergency) {
      return false;
    }

    if (mounted) {
      setState(() {
        _resolvingEmergency = true;
      });
    }

    try {
      final FirebaseFirestore firestore =
          FirebaseFirestore.instance;

      final DocumentReference<Map<String, dynamic>> emergencyReference =
          firestore
              .collection('emergencies')
              .doc(documentId);

      await firestore.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(
            emergencyReference,
          );

          if (!snapshot.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'not-found',
              message:
                  'La emergencia ya no existe.',
            );
          }

          transaction.update(
            emergencyReference,
            <String, dynamic>{
              'active': false,
              'read': true,
              'resolved': true,
              'completed': true,
              'resolvedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );

      await _safeUpdateInternalEmergencyNotifications(
        emergencyId: documentId,
        read: true,
        deleted: false,
        resolved: true,
      );

      await _cancelEmergencyLocalNotification(
        documentId,
      );

      if (!mounted) {
        return true;
      }

      setState(() {
        _resolvingEmergency = false;
      });

      await _loadAll();

      return true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firebase error resolviendo emergencia: '
        '${error.code} - ${error.message}',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (mounted) {
        setState(() {
          _resolvingEmergency = false;
        });

        String message =
            'No se pudo marcar la emergencia como atendida.';

        if (error.code == 'permission-denied') {
          message =
              'Tu cuenta de cuidador no tiene permiso para actualizar esta emergencia. '
              'Debes permitir la actualización en las reglas de Firestore.';
        } else if (error.code == 'not-found') {
          message =
              'La emergencia ya no existe o fue eliminada.';
        } else if (error.message != null &&
            error.message!.trim().isNotEmpty) {
          message =
              error.message!.trim();
        }

        await _showOkDialog(
          context,
          title: 'No se pudo actualizar',
          message: message,
        );
      }

      return false;
    } catch (error, stackTrace) {
      debugPrint(
        'Error resolviendo emergencia: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (mounted) {
        setState(() {
          _resolvingEmergency = false;
        });

        await _showOkDialog(
          context,
          title: 'Error',
          message:
              'No se pudo marcar la emergencia como atendida.',
        );
      }

      return false;
    } finally {
      if (mounted && _resolvingEmergency) {
        setState(() {
          _resolvingEmergency = false;
        });
      }
    }
  }

  // ============================================================
  // ELIMINAR EMERGENCIA
  // ============================================================

  Future<void> _deleteEmergency(
    String documentId,
  ) async {
    final DocumentReference<Map<String, dynamic>> emergencyReference =
        FirebaseFirestore.instance
            .collection('emergencies')
            .doc(documentId);

    await emergencyReference.update(
      <String, dynamic>{
        'active': false,
        'read': true,
        'deleted': true,
        'resolved': true,
        'completed': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await _safeUpdateInternalEmergencyNotifications(
      emergencyId: documentId,
      read: true,
      deleted: true,
      resolved: true,
    );

    await _cancelEmergencyLocalNotification(
      documentId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _emergencies.removeWhere(
        (emergency) => emergency.id == documentId,
      );

      _selectedKeys.remove(
        _emergencyKey(documentId),
      );
    });
  }
    // ============================================================
  // MARCAR RECUERDO COMO VISTO
  // ============================================================

  Future<void> _markMemoryAsRead(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final String? uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw Exception(
        'No hay un usuario autenticado.',
      );
    }

    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    final String memoryPayload =
        '$uid/${document.id}';

    await document.reference.set(
      <String, dynamic>{
        'reminder.read': true,
        'reminder.readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );

    final QuerySnapshot<Map<String, dynamic>> notificationSnapshot =
        await firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where(
              'memoryId',
              isEqualTo: memoryPayload,
            )
            .get();

    if (notificationSnapshot.docs.isEmpty) {
      return;
    }

    final WriteBatch batch =
        firestore.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> notification
        in notificationSnapshot.docs) {
      batch.set(
        notification.reference,
        <String, dynamic>{
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

  // ============================================================
  // ELIMINAR NOTIFICACIÓN DE RECUERDO
  // ============================================================

  Future<void> _deleteMemoryNotification({
    required String userId,
    required String memoryId,
  }) async {
    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;

    final String memoryPayload =
        '$userId/$memoryId';

    final DocumentReference<Map<String, dynamic>> memoryReference =
        firestore
            .collection('memories')
            .doc(userId)
            .collection('user_memories')
            .doc(memoryId);

    await memoryReference.set(
      <String, dynamic>{
        'reminder.enabled': false,
        'reminder.nextAt': null,
        'reminder.read': true,
        'reminder.completed': false,
        'reminder.deleted': true,
        'reminder.deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );

    final QuerySnapshot<Map<String, dynamic>> notificationSnapshot =
        await firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where(
              'memoryId',
              isEqualTo: memoryPayload,
            )
            .get();

    if (notificationSnapshot.docs.isNotEmpty) {
      final WriteBatch batch =
          firestore.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> notification
          in notificationSnapshot.docs) {
        batch.set(
          notification.reference,
          <String, dynamic>{
            'read': true,
            'deleted': true,
            'active': false,
            'deletedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();
    }

    try {
      await NotificationsService.cancelForMemory(
        memoryPayload,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo cancelar la notificación local del recuerdo: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _memoryNotifications.removeWhere(
        (memory) => memory.id == memoryId,
      );

      _selectedKeys.remove(
        _memoryKey(memoryId),
      );
    });
  }

  // ============================================================
  // MARCAR RECORDATORIO LOCAL COMO VISTO
  // ============================================================

  Future<void> _markLocalReminderAsRead(
    PendingNotificationRequest notification,
  ) async {
    final String payload =
        notification.payload?.trim() ?? '';

    if (!payload.startsWith('reminder/')) {
      return;
    }

    final String reminderId =
        payload
            .replaceFirst(
              'reminder/',
              '',
            )
            .trim();

    if (reminderId.isEmpty) {
      return;
    }

    try {
      await NotificationsService.markAppNotificationAsRead(
        'reminder_$reminderId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'No se pudo marcar la copia interna del recordatorio como leída: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // ELIMINAR ALARMA LOCAL
  // ============================================================

  Future<void> _deleteLocalReminder(
    PendingNotificationRequest notification,
  ) async {
    final String payload =
        notification.payload?.trim() ?? '';

    await NotificationsService.cancel(
      notification.id,
    );

    if (payload.startsWith('reminder/')) {
      final String reminderId =
          payload
              .replaceFirst(
                'reminder/',
                '',
              )
              .trim();

      if (reminderId.isNotEmpty) {
        try {
          await NotificationsService.cancelReminderNotification(
            reminderId,
          );
        } catch (error, stackTrace) {
          debugPrint(
            'No se pudo cancelar completamente el recordatorio: $error',
          );

          debugPrint(
            stackTrace.toString(),
          );
        }

        try {
          await NotificationsService.deleteAppNotification(
            'reminder_$reminderId',
          );
        } catch (error, stackTrace) {
          debugPrint(
            'No se pudo eliminar la copia interna del recordatorio: $error',
          );

          debugPrint(
            stackTrace.toString(),
          );
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingReminders.removeWhere(
        (item) => item.id == notification.id,
      );

      _selectedKeys.remove(
        _pendingKey(notification.id),
      );
    });
  }

  // ============================================================
  // CARGAR TODAS LAS NOTIFICACIONES
  // ============================================================

  Future<void> _loadAll() async {
    if (!mounted || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _selectedKeys.clear();
      _selectMode = false;
    });

    try {
      final String? uid =
          FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _pendingReminders =
              <PendingNotificationRequest>[];

          _appNotifications =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          _emergencies =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          _memoryNotifications =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          _loading = false;
        });

        return;
      }

      // ========================================================
      // 1. ALARMAS LOCALES
      // ========================================================

      final List<PendingNotificationRequest> pendingList =
          await NotificationsService.pendingNotificationRequests();

      final List<PendingNotificationRequest> localReminders =
          pendingList.where(
        (PendingNotificationRequest notification) {
          final String payload =
              notification.payload?.trim() ?? '';

          return payload.startsWith(
            'reminder/',
          );
        },
      ).toList()
        ..sort(
          (
            PendingNotificationRequest first,
            PendingNotificationRequest second,
          ) {
            return first.id.compareTo(
              second.id,
            );
          },
        );

      // ========================================================
      // 2. NOTIFICACIONES GENERALES
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> appSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .get();

      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          appDocuments =
          appSnapshot.docs.where(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          final Map<String, dynamic> data =
              document.data();

          final bool deleted =
              data['deleted'] == true;

          final String type =
              data['type']
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  'general';

          final bool duplicateType =
              type == 'reminder' ||
                  type == 'memory' ||
                  type == 'emergency' ||
                  type == 'emergencia' ||
                  type == 'emergency_alert' ||
                  type == 'panic' ||
                  type == 'panic_alert';

          return !deleted &&
              !duplicateType;
        },
      ).toList()
            ..sort(
              (
                QueryDocumentSnapshot<Map<String, dynamic>> first,
                QueryDocumentSnapshot<Map<String, dynamic>> second,
              ) {
                final DateTime firstDate =
                    _parseDateValue(
                  first.data()['timestamp'] ??
                      first.data()['createdAt'] ??
                      first.data()['updatedAt'],
                );

                final DateTime secondDate =
                    _parseDateValue(
                  second.data()['timestamp'] ??
                      second.data()['createdAt'] ??
                      second.data()['updatedAt'],
                );

                return secondDate.compareTo(
                  firstDate,
                );
              },
            );

      // ========================================================
      // 3. EMERGENCIAS
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> emergencySnapshot =
          await FirebaseFirestore.instance
              .collection('emergencies')
              .where(
                'caregiverId',
                isEqualTo: uid,
              )
              .get();

      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          emergencyDocuments =
          emergencySnapshot.docs.where(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          final Map<String, dynamic> data =
              document.data();

          return data['deleted'] != true;
        },
      ).toList()
            ..sort(
              (
                QueryDocumentSnapshot<Map<String, dynamic>> first,
                QueryDocumentSnapshot<Map<String, dynamic>> second,
              ) {
                final Map<String, dynamic> firstData =
                    first.data();

                final Map<String, dynamic> secondData =
                    second.data();

                final DateTime firstDate =
                    _parseDateValue(
                  firstData['timestamp'] ??
                      firstData['triggeredAt'] ??
                      firstData['createdAt'],
                );

                final DateTime secondDate =
                    _parseDateValue(
                  secondData['timestamp'] ??
                      secondData['triggeredAt'] ??
                      secondData['createdAt'],
                );

                return secondDate.compareTo(
                  firstDate,
                );
              },
            );

      // ========================================================
      // 4. RECUERDOS CON RECORDATORIO
      // ========================================================

      final QuerySnapshot<Map<String, dynamic>> memoriesSnapshot =
          await FirebaseFirestore.instance
              .collection('memories')
              .doc(uid)
              .collection('user_memories')
              .get();

      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
          memoryDocuments =
          memoriesSnapshot.docs.where(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          final Map<String, dynamic> data =
              document.data();

          final dynamic reminderValue =
              data['reminder'];

          if (reminderValue is! Map) {
            return false;
          }

          final Map<String, dynamic> reminder =
              Map<String, dynamic>.from(
            reminderValue,
          );

          final bool enabled =
              reminder['enabled'] == true;

          final bool deleted =
              reminder['deleted'] == true;

          final bool completed =
              reminder['completed'] == true;

          final dynamic nextAt =
              reminder['nextAt'];

          return enabled &&
              !deleted &&
              !completed &&
              nextAt != null;
        },
      ).toList()
            ..sort(
              (
                QueryDocumentSnapshot<Map<String, dynamic>> first,
                QueryDocumentSnapshot<Map<String, dynamic>> second,
              ) {
                final dynamic firstReminderValue =
                    first.data()['reminder'];

                final dynamic secondReminderValue =
                    second.data()['reminder'];

                final Map<String, dynamic> firstReminder =
                    firstReminderValue is Map
                        ? Map<String, dynamic>.from(
                            firstReminderValue,
                          )
                        : <String, dynamic>{};

                final Map<String, dynamic> secondReminder =
                    secondReminderValue is Map
                        ? Map<String, dynamic>.from(
                            secondReminderValue,
                          )
                        : <String, dynamic>{};

                final DateTime firstDate =
                    _parseDateValue(
                  firstReminder['nextAt'],
                );

                final DateTime secondDate =
                    _parseDateValue(
                  secondReminder['nextAt'],
                );

                return firstDate.compareTo(
                  secondDate,
                );
              },
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingReminders =
            localReminders;

        _appNotifications =
            appDocuments;

        _emergencies =
            emergencyDocuments;

        _memoryNotifications =
            memoryDocuments;

        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Error cargando notificaciones: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      await _showOkDialog(
        context,
        title: 'Error',
        message:
            'No se pudieron cargar las notificaciones.',
      );
    }
  }

  // ============================================================
  // SELECCIÓN
  // ============================================================

  void _toggleSelectMode() {
    setState(() {
      _selectMode =
          !_selectMode;

      if (!_selectMode) {
        _selectedKeys.clear();
      }
    });
  }

  void _toggleSelect(
    String key,
  ) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  void _selectAll() {
    final List<String> allKeys =
        <String>[
      ..._emergencies.map(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return _emergencyKey(
            document.id,
          );
        },
      ),
      ..._appNotifications.map(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return _appKey(
            document.id,
          );
        },
      ),
      ..._memoryNotifications.map(
        (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return _memoryKey(
            document.id,
          );
        },
      ),
      ..._pendingReminders.map(
        (PendingNotificationRequest notification) {
          return _pendingKey(
            notification.id,
          );
        },
      ),
    ];

    setState(() {
      final bool allSelected =
          allKeys.isNotEmpty &&
              allKeys.every(
                _selectedKeys.contains,
              );

      if (allSelected) {
        _selectedKeys.clear();
      } else {
        _selectedKeys
          ..clear()
          ..addAll(allKeys);
      }
    });
  }
    // ============================================================
  // ELIMINAR NOTIFICACIONES SELECCIONADAS
  // ============================================================

  Future<void> _confirmDeleteSelected() async {
    if (_selectedKeys.isEmpty) {
      await _showOkDialog(
        context,
        title: 'Atención',
        message:
            'Debes seleccionar al menos una notificación para eliminar.',
      );

      return;
    }

    final int count =
        _selectedKeys.length;

    final bool confirmed =
        await _showDeleteDialog(
      context,
      message: count == 1
          ? '¿Deseas eliminar esta notificación?'
          : '¿Deseas eliminar las $count notificaciones seleccionadas?',
    );

    if (!confirmed) {
      return;
    }

    final Set<String> selectedKeys =
        Set<String>.from(
      _selectedKeys,
    );

    try {
      for (final String key in selectedKeys) {
        if (key.startsWith('emergency_')) {
          final String documentId =
              key.replaceFirst(
            'emergency_',
            '',
          );

          if (documentId.isNotEmpty) {
            await _deleteEmergency(
              documentId,
            );
          }

          continue;
        }

        if (key.startsWith('app_')) {
          final String documentId =
              key.replaceFirst(
            'app_',
            '',
          );

          if (documentId.isNotEmpty) {
            await NotificationsService.deleteAppNotification(
              documentId,
            );
          }

          continue;
        }

        if (key.startsWith('memory_')) {
          final String memoryId =
              key.replaceFirst(
            'memory_',
            '',
          );

          final String? uid =
              FirebaseAuth.instance.currentUser?.uid;

          if (uid != null &&
              memoryId.isNotEmpty) {
            await _deleteMemoryNotification(
              userId: uid,
              memoryId: memoryId,
            );
          }

          continue;
        }

        if (key.startsWith('pending_')) {
          final String rawId =
              key.replaceFirst(
            'pending_',
            '',
          );

          final int? notificationId =
              int.tryParse(
            rawId,
          );

          if (notificationId == null) {
            continue;
          }

          PendingNotificationRequest?
              selectedNotification;

          for (final PendingNotificationRequest notification
              in _pendingReminders) {
            if (notification.id ==
                notificationId) {
              selectedNotification =
                  notification;

              break;
            }
          }

          if (selectedNotification != null) {
            await _deleteLocalReminder(
              selectedNotification,
            );
          } else {
            await NotificationsService.cancel(
              notificationId,
            );
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedKeys.clear();
        _selectMode = false;
      });

      await _loadAll();

      if (!mounted) {
        return;
      }

      await _showOkDialog(
        context,
        title: 'Eliminadas',
        message: count == 1
            ? 'La notificación fue eliminada correctamente.'
            : '$count notificaciones fueron eliminadas correctamente.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error eliminando notificaciones: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      await _showOkDialog(
        context,
        title: 'Error',
        message:
            'No se pudieron eliminar todas las notificaciones seleccionadas.',
      );
    }
  }

  // ============================================================
  // CONTADORES
  // ============================================================

  int get _totalNotifications {
    return _emergencies.length +
        _appNotifications.length +
        _memoryNotifications.length +
        _pendingReminders.length;
  }

  int get _unreadNotifications {
    int count = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> emergency
        in _emergencies) {
      final Map<String, dynamic> data =
          emergency.data();

      final bool read =
          data['read'] == true;

      final bool deleted =
          data['deleted'] == true;

      final bool resolved =
          data['resolved'] == true;

      if (!read &&
          !deleted &&
          !resolved) {
        count++;
      }
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> notification
        in _appNotifications) {
      final Map<String, dynamic> data =
          notification.data();

      final bool read =
          data['read'] == true;

      final bool deleted =
          data['deleted'] == true;

      final bool completed =
          data['completed'] == true;

      if (!read &&
          !deleted &&
          !completed) {
        count++;
      }
    }

    for (final QueryDocumentSnapshot<Map<String, dynamic>> memory
        in _memoryNotifications) {
      final dynamic reminderValue =
          memory.data()['reminder'];

      if (reminderValue is Map) {
        final Map<String, dynamic> reminder =
            Map<String, dynamic>.from(
          reminderValue,
        );

        final bool read =
            reminder['read'] == true;

        final bool deleted =
            reminder['deleted'] == true;

        if (!read &&
            !deleted) {
          count++;
        }
      }
    }

    for (final PendingNotificationRequest notification
        in _pendingReminders) {
      final String payload =
          notification.payload?.trim() ?? '';

      if (payload.startsWith('reminder/')) {
        count++;
      }
    }

    return count;
  }

  // ============================================================
  // INTERFAZ PRINCIPAL
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final AppColors colors =
        context.appColors;

    final int total =
        _totalNotifications;

    final int unread =
        _unreadNotifications;

    return Scaffold(
      backgroundColor:
          colors.pageBackground,
      appBar: AppBar(
        backgroundColor:
            colors.pageBackground,
        foregroundColor:
            colors.textPrimary,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: FittedBox(
          fit:
              BoxFit.scaleDown,
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                'Notificaciones',
                style: TextStyle(
                  color:
                      colors.textPrimary,
                  fontWeight:
                      FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(
                  width: 8,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        colors.secondaryButton.withValues(
                      alpha: 0.18,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border: Border.all(
                      color:
                          colors.border,
                    ),
                  ),
                  child: Text(
                    '$unread',
                    style: TextStyle(
                      color:
                          colors.textPrimary,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                'Actualizar',
            onPressed:
                _loading
                    ? null
                    : _loadAll,
            icon: Icon(
              Icons.refresh_rounded,
              color:
                  colors.textPrimary,
            ),
          ),
          if (_selectMode) ...[
            IconButton(
              tooltip:
                  'Seleccionar todas',
              onPressed:
                  _selectAll,
              icon: Icon(
                Icons.select_all_rounded,
                color:
                    colors.secondaryButton,
              ),
            ),
            IconButton(
              tooltip:
                  'Eliminar seleccionadas',
              onPressed:
                  _selectedKeys.isEmpty
                      ? null
                      : _confirmDeleteSelected,
              icon: Icon(
                Icons.delete_rounded,
                color:
                    colors.emergency,
              ),
            ),
          ],
          IconButton(
            tooltip:
                _selectMode
                    ? 'Salir de selección'
                    : 'Seleccionar notificaciones',
            onPressed:
                _toggleSelectMode,
            icon: Icon(
              _selectMode
                  ? Icons.close_rounded
                  : Icons.check_box_rounded,
              color:
                  colors.textPrimary,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color:
            colors.primaryButtonText,
        backgroundColor:
            colors.primaryButton,
        onRefresh:
            _loadAll,
        child: _loading
            ? ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height:
                        MediaQuery.of(context).size.height *
                            0.65,
                    child: Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            colors.primaryButton,
                      ),
                    ),
                  ),
                ],
              )
            : total == 0
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 500,
                        child:
                            _NotificationsEmptyState(),
                      ),
                    ],
                  )
                : ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      24,
                    ),
                    children: [
                      if (_emergencies.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon:
                              Icons.warning_amber_rounded,
                          title:
                              'Emergencias',
                          count:
                              _emergencies.length,
                          color:
                              colors.emergency,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        ..._emergencies.map(
                          _buildEmergencyCard,
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                      ],
                      if (_appNotifications.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon:
                              Icons.notifications_active_rounded,
                          title:
                              'Notificaciones',
                          count:
                              _appNotifications.length,
                          color:
                              colors.secondaryButton,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        ..._appNotifications.map(
                          _buildAppNotificationCard,
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                      ],
                      if (_memoryNotifications.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon:
                              Icons.photo_album_rounded,
                          title:
                              'Recuerdos',
                          count:
                              _memoryNotifications.length,
                          color:
                              colors.categoryPurple,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        ..._memoryNotifications.map(
                          _buildFirebaseMemoryCard,
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                      ],
                      if (_pendingReminders.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon:
                              Icons.alarm_rounded,
                          title:
                              'Alarmas programadas',
                          count:
                              _pendingReminders.length,
                          color:
                              colors.categoryBlue,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        ..._pendingReminders.map(
                          _buildLocalReminderCard,
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  // ============================================================
  // TÍTULO DE SECCIÓN
  // ============================================================

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    final AppColors colors =
        context.appColors;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: 0.14,
            ),
            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(
          width: 10,
        ),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color:
                  colors.textPrimary,
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color:
                colors.cardBackground,
            borderRadius:
                BorderRadius.circular(
              999,
            ),
            border: Border.all(
              color:
                  colors.border,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color:
                  colors.textPrimary,
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
    // ============================================================
  // TARJETA DE NOTIFICACIÓN GENERAL
  // ============================================================

  Widget _buildAppNotificationCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final AppColors colors =
        context.appColors;

    final Map<String, dynamic> data =
        document.data();

    final String key =
        _appKey(
      document.id,
    );

    final bool selected =
        _selectedKeys.contains(
      key,
    );

    final bool isRead =
        data['read'] == true;

    final String rawTitle =
        data['title']?.toString().trim() ?? '';

    final String title =
        rawTitle.isNotEmpty
            ? rawTitle
            : 'Notificación';

    final String rawBody =
        data['body']?.toString().trim() ?? '';

    final String body =
        rawBody.isNotEmpty
            ? rawBody
            : 'Sin descripción';

    final String type =
        data['type']?.toString().trim().toLowerCase() ??
            'general';

    final DateTime? date =
        _parseNullableDateValue(
      data['timestamp'] ??
          data['createdAt'] ??
          data['updatedAt'],
    );

    IconData icon =
        Icons.notifications_active_rounded;

    Color accentColor =
        colors.secondaryButton;

    if (type == 'phrase') {
      icon =
          Icons.format_quote_rounded;

      accentColor =
          colors.categoryPurple;
    } else if (type == 'preventive') {
      icon =
          Icons.health_and_safety_rounded;

      accentColor =
          colors.categoryGreen;
    } else if (type == 'message') {
      icon =
          Icons.message_rounded;

      accentColor =
          colors.categoryBlue;
    }

    return GestureDetector(
      onTap: _selectMode
          ? () {
              _toggleSelect(
                key,
              );
            }
          : null,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.secondaryButton.withValues(
                  alpha: 0.14,
                )
              : colors.cardBackground,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: selected
                ? colors.secondaryButton
                : isRead
                    ? colors.border
                    : accentColor.withValues(
                        alpha: 0.75,
                      ),
            width: selected
                ? 2
                : isRead
                    ? 1
                    : 1.5,
          ),
          boxShadow: context.isDark
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: colors.textPrimary.withValues(
                      alpha: 0.05,
                    ),
                    blurRadius: 12,
                    offset:
                        const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (_selectMode) ...[
                  Checkbox(
                    value:
                        selected,
                    activeColor:
                        colors.secondaryButton,
                    checkColor:
                        colors.secondaryButtonText,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    onChanged: (_) {
                      _toggleSelect(
                        key,
                      );
                    },
                  ),
                  const SizedBox(
                    width: 2,
                  ),
                ],
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color:
                        accentColor.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        isRead
                            ? 'Leída'
                            : 'Pendiente',
                        style: TextStyle(
                          color: isRead
                              ? colors.textSecondary
                              : accentColor,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              body,
              style: TextStyle(
                color:
                    colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (date != null) ...[
              const SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color:
                        colors.textSecondary,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Text(
                    _formatDateTime(
                      date,
                    ),
                    style: TextStyle(
                      color:
                          colors.textSecondary,
                      fontSize: 12.5,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (!_selectMode &&
                !isRead) ...[
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await NotificationsService
                          .markAppNotificationAsRead(
                        document.id,
                      );

                      await _loadAll();
                    } catch (error, stackTrace) {
                      debugPrint(
                        'Error marcando notificación como leída: $error',
                      );

                      debugPrint(
                        stackTrace.toString(),
                      );

                      if (!mounted) {
                        return;
                      }

                      await _showOkDialog(
                        context,
                        title: 'Error',
                        message:
                            'No se pudo marcar la notificación como leída.',
                      );
                    }
                  },
                  icon: Icon(
                    Icons.mark_email_read_rounded,
                    color:
                        colors.textPrimary,
                  ),
                  label: Text(
                    'Marcar leída',
                    style: TextStyle(
                      color:
                          colors.textPrimary,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        colors.textPrimary,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    shape:
                        const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TARJETA DE RECUERDO
  // ============================================================

  Widget _buildFirebaseMemoryCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final AppColors colors =
        context.appColors;

    final Map<String, dynamic> data =
        document.data();

    final String key =
        _memoryKey(
      document.id,
    );

    final bool selected =
        _selectedKeys.contains(
      key,
    );

    final dynamic reminderValue =
        data['reminder'];

    final Map<String, dynamic> reminder =
        reminderValue is Map
            ? Map<String, dynamic>.from(
                reminderValue,
              )
            : <String, dynamic>{};

    final bool isRead =
        reminder['read'] == true;

    final String rawTitle =
        data['title']?.toString().trim() ?? '';

    final String title =
        rawTitle.isNotEmpty
            ? rawTitle
            : 'Recordatorio de recuerdo';

    final String rawText =
        data['text']?.toString().trim() ?? '';

    final String rawDescription =
        data['description']?.toString().trim() ?? '';

    final String body =
        rawText.isNotEmpty
            ? rawText
            : rawDescription.isNotEmpty
                ? rawDescription
                : 'Tienes un recuerdo programado.';

    final DateTime? nextDate =
        _parseNullableDateValue(
      reminder['nextAt'],
    );

    return GestureDetector(
      onTap: _selectMode
          ? () {
              _toggleSelect(
                key,
              );
            }
          : null,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.secondaryButton.withValues(
                  alpha: 0.14,
                )
              : colors.cardBackground,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: selected
                ? colors.secondaryButton
                : isRead
                    ? colors.border
                    : colors.categoryPurple.withValues(
                        alpha: 0.8,
                      ),
            width: selected
                ? 2
                : isRead
                    ? 1
                    : 1.5,
          ),
          boxShadow: context.isDark
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: colors.textPrimary.withValues(
                      alpha: 0.05,
                    ),
                    blurRadius: 12,
                    offset:
                        const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (_selectMode) ...[
                  Checkbox(
                    value:
                        selected,
                    activeColor:
                        colors.secondaryButton,
                    checkColor:
                        colors.secondaryButtonText,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    onChanged: (_) {
                      _toggleSelect(
                        key,
                      );
                    },
                  ),
                  const SizedBox(
                    width: 2,
                  ),
                ],
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.categoryPurple.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_album_rounded,
                    color:
                        colors.categoryPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        isRead
                            ? 'Visto'
                            : 'Pendiente',
                        style: TextStyle(
                          color: isRead
                              ? colors.textSecondary
                              : colors.categoryPurple,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              body,
              style: TextStyle(
                color:
                    colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (nextDate != null) ...[
              const SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color:
                        colors.textSecondary,
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  Expanded(
                    child: Text(
                      'Próximo aviso: ${_formatDateTime(nextDate)}',
                      style: TextStyle(
                        color:
                            colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!_selectMode) ...[
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await _markMemoryAsRead(
                        document,
                      );

                      if (!mounted) {
                        return;
                      }

                      await _showFirebaseMemoryDialog(
                        context,
                        document,
                      );

                      await _loadAll();
                    } catch (error, stackTrace) {
                      debugPrint(
                        'Error abriendo recuerdo: $error',
                      );

                      debugPrint(
                        stackTrace.toString(),
                      );

                      if (!mounted) {
                        return;
                      }

                      await _showOkDialog(
                        context,
                        title: 'Error',
                        message:
                            'No se pudo abrir el recuerdo.',
                      );
                    }
                  },
                  icon: Icon(
                    Icons.photo_rounded,
                    color:
                        colors.textPrimary,
                  ),
                  label: Text(
                    'Ver recuerdo',
                    style: TextStyle(
                      color:
                          colors.textPrimary,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        colors.textPrimary,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    shape:
                        const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
    // ============================================================
  // TARJETA DE ALARMA LOCAL
  // ============================================================

  Widget _buildLocalReminderCard(
    PendingNotificationRequest notification,
  ) {
    final AppColors colors =
        context.appColors;

    final String key =
        _pendingKey(
      notification.id,
    );

    final bool selected =
        _selectedKeys.contains(
      key,
    );

    final String rawTitle =
        notification.title?.trim() ?? '';

    final String title =
        rawTitle.isNotEmpty
            ? rawTitle
            : 'Recordatorio';

    final String rawBody =
        notification.body?.trim() ?? '';

    final String body =
        rawBody.isNotEmpty
            ? rawBody
            : 'Alarma programada en el dispositivo.';

    return GestureDetector(
      onTap: _selectMode
          ? () {
              _toggleSelect(
                key,
              );
            }
          : null,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.secondaryButton.withValues(
                  alpha: 0.14,
                )
              : colors.cardBackground,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: selected
                ? colors.secondaryButton
                : colors.categoryBlue.withValues(
                    alpha: 0.75,
                  ),
            width: selected
                ? 2
                : 1.4,
          ),
          boxShadow: context.isDark
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: colors.textPrimary.withValues(
                      alpha: 0.05,
                    ),
                    blurRadius: 12,
                    offset:
                        const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (_selectMode) ...[
                  Checkbox(
                    value:
                        selected,
                    activeColor:
                        colors.secondaryButton,
                    checkColor:
                        colors.secondaryButtonText,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    onChanged: (_) {
                      _toggleSelect(
                        key,
                      );
                    },
                  ),
                  const SizedBox(
                    width: 2,
                  ),
                ],
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.categoryBlue.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    Icons.alarm_rounded,
                    color:
                        colors.categoryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Programada',
                        style: TextStyle(
                          color:
                              colors.categoryBlue,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              body,
              style: TextStyle(
                color:
                    colors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (!_selectMode) ...[
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await _markLocalReminderAsRead(
                        notification,
                      );

                      if (!mounted) {
                        return;
                      }

                      await Navigator.pushNamed(
                        context,
                        '/reminders',
                      );

                      if (!mounted) {
                        return;
                      }

                      await _loadAll();
                    } catch (error, stackTrace) {
                      debugPrint(
                        'Error abriendo recordatorio: $error',
                      );

                      debugPrint(
                        stackTrace.toString(),
                      );

                      if (!mounted) {
                        return;
                      }

                      await _showOkDialog(
                        context,
                        title: 'Error',
                        message:
                            'No se pudo abrir el recordatorio.',
                      );
                    }
                  },
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    color:
                        colors.textPrimary,
                  ),
                  label: Text(
                    'Ver alarma',
                    style: TextStyle(
                      color:
                          colors.textPrimary,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        colors.textPrimary,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    shape:
                        const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIÁLOGO PARA VER RECUERDO
  // ============================================================

  Future<void> _showFirebaseMemoryDialog(
    BuildContext dialogParentContext,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final Map<String, dynamic> data =
        document.data();

    final String rawText =
        data['text']?.toString().trim() ?? '';

    final String rawDescription =
        data['description']?.toString().trim() ?? '';

    final String rawTitle =
        data['title']?.toString().trim() ?? '';

    final String text =
        rawText.isNotEmpty
            ? rawText
            : rawDescription.isNotEmpty
                ? rawDescription
                : rawTitle.isNotEmpty
                    ? rawTitle
                    : 'Sin descripción';

    final String rawImageUrl =
        data['imageUrl']?.toString().trim() ?? '';

    final String rawImage =
        data['image']?.toString().trim() ?? '';

    final String? imageUrl =
        rawImageUrl.isNotEmpty
            ? rawImageUrl
            : rawImage.isNotEmpty
                ? rawImage
                : null;

    final dynamic rawDate =
        data['displayDate'] ??
            data['date'] ??
            data['timestamp'] ??
            data['createdAt'];

    String formattedDate =
        'Sin fecha';

    DateTime? parsedDate;

    if (rawDate is Timestamp) {
      parsedDate =
          rawDate.toDate();
    } else if (rawDate is DateTime) {
      parsedDate =
          rawDate;
    } else if (rawDate is String) {
      final String value =
          rawDate.trim();

      if (value.isNotEmpty) {
        parsedDate =
            DateTime.tryParse(
          value,
        );

        if (parsedDate == null) {
          formattedDate =
              value;
        }
      }
    }

    if (parsedDate != null) {
      final String day =
          parsedDate.day.toString().padLeft(
                2,
                '0',
              );

      final String month =
          parsedDate.month.toString().padLeft(
                2,
                '0',
              );

      final String year =
          parsedDate.year.toString();

      formattedDate =
          '$day/$month/$year';
    }

    if (!dialogParentContext.mounted) {
      return;
    }

    await showGeneralDialog<void>(
      context:
          dialogParentContext,
      barrierDismissible:
          false,
      barrierLabel:
          'Diálogo de recuerdo',
      transitionDuration:
          const Duration(
        milliseconds: 300,
      ),
      pageBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        final AppColors colors =
            dialogContext.appColors;

        return Material(
          color: Colors.black.withValues(
            alpha: 0.45,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Container(
                  width:
                      double.infinity,
                  constraints:
                      const BoxConstraints(
                    maxWidth: 520,
                  ),
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  decoration: BoxDecoration(
                    color:
                        colors.elevatedCard,
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                    border: Border.all(
                      color:
                          colors.border,
                    ),
                    boxShadow: context.isDark
                        ? const <BoxShadow>[]
                        : <BoxShadow>[
                            BoxShadow(
                              color: colors.textPrimary.withValues(
                                alpha: 0.10,
                              ),
                              blurRadius: 24,
                              offset:
                                  const Offset(
                                0,
                                10,
                              ),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration:
                                BoxDecoration(
                              color:
                                  colors.categoryPurple.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                            child: Icon(
                              Icons.photo_album_rounded,
                              color:
                                  colors.categoryPurple,
                              size: 24,
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              'El recuerdo ha llegado',
                              style: TextStyle(
                                color:
                                    colors.textPrimary,
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 18,
                      ),
                      if (imageUrl != null &&
                          imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                          child: Image.network(
                            imageUrl,
                            width:
                                double.infinity,
                            height:
                                220,
                            fit:
                                BoxFit.cover,
                            errorBuilder: (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return Container(
                                width:
                                    double.infinity,
                                height:
                                    180,
                                alignment:
                                    Alignment.center,
                                decoration:
                                    BoxDecoration(
                                  color:
                                      colors.inputFill,
                                  borderRadius:
                                      BorderRadius.circular(
                                    18,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        colors.border,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      color:
                                          colors.textSecondary,
                                      size:
                                          46,
                                    ),
                                    const SizedBox(
                                      height:
                                          8,
                                    ),
                                    Text(
                                      'No se pudo cargar la imagen',
                                      style: TextStyle(
                                        color:
                                            colors.textSecondary,
                                        fontSize:
                                            13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                      ],
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              colors.cardBackground,
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          border:
                              Border.all(
                            color:
                                colors.border,
                          ),
                        ),
                        child: Text(
                          text,
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            color:
                                colors.textPrimary,
                            fontSize: 16,
                            height: 1.45,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              colors.categoryPurple.withValues(
                            alpha: 0.13,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            999,
                          ),
                          border:
                              Border.all(
                            color:
                                colors.categoryPurple.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Text(
                          formattedDate == 'Sin fecha'
                              ? '¿Lo recuerdas?'
                              : '¿Lo recuerdas? · $formattedDate',
                          style: TextStyle(
                            color:
                                colors.textPrimary,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      SizedBox(
                        width:
                            double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(
                              dialogContext,
                            ).pop();
                          },
                          icon: Icon(
                            Icons.check_rounded,
                            color:
                                colors.primaryButtonText,
                          ),
                          label: Text(
                            'Cerrar',
                            style: TextStyle(
                              color:
                                  colors.primaryButtonText,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          style:
                              FilledButton.styleFrom(
                            backgroundColor:
                                colors.primaryButton,
                            foregroundColor:
                                colors.primaryButtonText,
                            minimumSize:
                                const Size.fromHeight(
                              52,
                            ),
                            shape:
                                const StadiumBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<double> curvedAnimation =
            CurvedAnimation(
          parent:
              animation,
          curve:
              Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity:
              curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin:
                  0.94,
              end:
                  1,
            ).animate(
              curvedAnimation,
            ),
            child:
                child,
          ),
        );
      },
    );
  }
    // ============================================================
  // TARJETA DE EMERGENCIA
  // ============================================================

  Widget _buildEmergencyCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final AppColors colors =
        context.appColors;

    final Map<String, dynamic> data =
        document.data();

    final String key =
        _emergencyKey(
      document.id,
    );

    final bool selected =
        _selectedKeys.contains(
      key,
    );

    final bool isRead =
        data['read'] == true;

    final bool isResolved =
        data['resolved'] == true ||
            data['completed'] == true ||
            data['active'] == false;

    final String rawConsultantName =
        data['consultantName']
                ?.toString()
                .trim() ??
            '';

    final String consultantName =
        rawConsultantName.isNotEmpty
            ? rawConsultantName
            : 'Consultante';

    final String consultantId =
        data['consultantId']
                ?.toString()
                .trim() ??
            '';

    final dynamic rawLatitude =
        data['lat'] ??
            data['latitude'];

    final dynamic rawLongitude =
        data['lng'] ??
            data['longitude'];

    final double? latitude =
        rawLatitude is num
            ? rawLatitude.toDouble()
            : double.tryParse(
                rawLatitude?.toString() ?? '',
              );

    final double? longitude =
        rawLongitude is num
            ? rawLongitude.toDouble()
            : double.tryParse(
                rawLongitude?.toString() ?? '',
              );

    final DateTime? date =
        _parseNullableDateValue(
      data['timestamp'] ??
          data['triggeredAt'] ??
          data['createdAt'],
    );

    final Color accentColor =
        isResolved
            ? colors.categoryGreen
            : colors.emergency;

    return GestureDetector(
      onTap: _selectMode
          ? () {
              _toggleSelect(
                key,
              );
            }
          : null,
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.secondaryButton.withValues(
                  alpha: 0.14,
                )
              : accentColor.withValues(
                  alpha: isResolved || isRead
                      ? 0.08
                      : 0.14,
                ),
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: selected
                ? colors.secondaryButton
                : isResolved || isRead
                    ? colors.border
                    : accentColor.withValues(
                        alpha: 0.75,
                      ),
            width: selected
                ? 2
                : isResolved || isRead
                    ? 1
                    : 1.5,
          ),
          boxShadow: context.isDark
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: colors.textPrimary.withValues(
                      alpha: 0.05,
                    ),
                    blurRadius: 12,
                    offset:
                        const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (_selectMode) ...[
                  Checkbox(
                    value:
                        selected,
                    activeColor:
                        colors.secondaryButton,
                    checkColor:
                        colors.secondaryButtonText,
                    side: BorderSide(
                      color:
                          colors.border,
                    ),
                    onChanged: (_) {
                      _toggleSelect(
                        key,
                      );
                    },
                  ),
                  const SizedBox(
                    width: 2,
                  ),
                ],
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color:
                        accentColor.withValues(
                      alpha: 0.16,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    isResolved
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    color:
                        accentColor,
                    size: 25,
                  ),
                ),
                const SizedBox(
                  width: 11,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        isResolved
                            ? 'Emergencia atendida'
                            : 'Emergencia detectada',
                        style: TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        isResolved
                            ? 'Atendida'
                            : isRead
                                ? 'Leída'
                                : 'Pendiente',
                        style: TextStyle(
                          color: isResolved
                              ? colors.categoryGreen
                              : isRead
                                  ? colors.textSecondary
                                  : colors.emergency,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                13,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colors.cardBackground,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border:
                    Border.all(
                  color:
                      colors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        color:
                            colors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      Expanded(
                        child: Text(
                          'Paciente: $consultantName',
                          style: TextStyle(
                            color:
                                colors.textPrimary,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (date != null) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color:
                              colors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(
                          width: 7,
                        ),
                        Text(
                          _formatDateTime(
                            date,
                          ),
                          style: TextStyle(
                            color:
                                colors.textSecondary,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!_selectMode) ...[
              const SizedBox(
                height: 12,
              ),
              Align(
                alignment:
                    Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment:
                      WrapAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await _showEmergencyDialog(
                          emergencyId:
                              document.id,
                          consultantName:
                              consultantName,
                          consultantId:
                              consultantId,
                          latitude:
                              latitude,
                          longitude:
                              longitude,
                          isResolved:
                              isResolved,
                        );
                      },
                      icon: Icon(
                        isResolved
                            ? Icons.visibility_rounded
                            : Icons.map_rounded,
                        color:
                            colors.primaryButtonText,
                      ),
                      label: Text(
                        isResolved
                            ? 'Ver detalles'
                            : 'Ver emergencia',
                        style: TextStyle(
                          color:
                              colors.primaryButtonText,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            colors.primaryButton,
                        foregroundColor:
                            colors.primaryButtonText,
                        shape:
                            const StadiumBorder(),
                      ),
                    ),
                    if (!isRead &&
                        !isResolved)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final bool success =
                              await _markEmergencyAsRead(
                            document.id,
                          );

                          if (!success ||
                              !mounted) {
                            return;
                          }

                          await _showOkDialog(
                            context,
                            title:
                                'Emergencia leída',
                            message:
                                'La emergencia permanecerá en el historial, pero ya no aparecerá como pendiente.',
                          );
                        },
                        icon: Icon(
                          Icons.mark_email_read_rounded,
                          color:
                              colors.textPrimary,
                        ),
                        label: Text(
                          'Marcar leída',
                          style: TextStyle(
                            color:
                                colors.textPrimary,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              colors.textPrimary,
                          side: BorderSide(
                            color:
                                colors.border,
                          ),
                          shape:
                              const StadiumBorder(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIÁLOGO DE EMERGENCIA
  // ============================================================

  Future<void> _showEmergencyDialog({
    required String emergencyId,
    required String consultantName,
    required String consultantId,
    required double? latitude,
    required double? longitude,
    required bool isResolved,
  }) async {
    if (!mounted) {
      return;
    }

    bool resolvedInDialog =
        isResolved;

    await showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder: (
        BuildContext dialogContext,
      ) {
        final AppColors colors =
            dialogContext.appColors;

        bool processing =
            false;

        return StatefulBuilder(
          builder: (
            BuildContext statefulContext,
            StateSetter setDialogState,
          ) {
            final bool hasLocation =
                latitude != null &&
                    longitude != null;

            return AlertDialog(
              backgroundColor:
                  colors.elevatedCard,
              surfaceTintColor:
                  Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
                side: BorderSide(
                  color:
                      colors.border,
                ),
              ),
              titlePadding:
                  const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                8,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12,
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              title: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      color:
                          (resolvedInDialog
                                  ? colors.categoryGreen
                                  : colors.emergency)
                              .withValues(
                        alpha: 0.16,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: Icon(
                      resolvedInDialog
                          ? Icons.check_circle_rounded
                          : Icons.location_on_rounded,
                      color: resolvedInDialog
                          ? colors.categoryGreen
                          : colors.emergency,
                      size: 26,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedInDialog
                              ? 'Emergencia atendida'
                              : 'Emergencia activa',
                          style: TextStyle(
                            color:
                                colors.textPrimary,
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          consultantName,
                          style: TextStyle(
                            color:
                                colors.textSecondary,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width:
                          double.infinity,
                      height:
                          300,
                      decoration:
                          BoxDecoration(
                        color:
                            colors.cardBackground,
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                        border:
                            Border.all(
                          color:
                              colors.border,
                        ),
                      ),
                      child: hasLocation
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                              child:
                                  EmergencyMapPage(
                                consultantId:
                                    consultantId,
                                lat:
                                    latitude,
                                lng:
                                    longitude,
                                isDialog:
                                    true,
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.all(
                                24,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          colors.inputFill,
                                      shape:
                                          BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_off_rounded,
                                      color:
                                          colors.textSecondary,
                                      size:
                                          36,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 14,
                                  ),
                                  Text(
                                    'Ubicación no disponible',
                                    textAlign:
                                        TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          colors.textPrimary,
                                      fontSize:
                                          16,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 6,
                                  ),
                                  Text(
                                    'Esta emergencia no contiene coordenadas de ubicación.',
                                    textAlign:
                                        TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          colors.textSecondary,
                                      fontSize:
                                          14,
                                      height:
                                          1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (resolvedInDialog) ...[
                      const SizedBox(
                        height: 14,
                      ),
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              colors.categoryGreen.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                          border:
                              Border.all(
                            color:
                                colors.categoryGreen.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color:
                                  colors.categoryGreen,
                              size:
                                  22,
                            ),
                            const SizedBox(
                              width:
                                  9,
                            ),
                            Expanded(
                              child: Text(
                                'Esta emergencia ya fue marcada como atendida.',
                                style: TextStyle(
                                  color:
                                      colors.textPrimary,
                                  fontSize:
                                      14,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (hasLocation)
                  OutlinedButton.icon(
                    onPressed: processing
                        ? null
                        : () async {
                            final Uri uri =
                                Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
                            );

                            try {
                              final bool opened =
                                  await launchUrl(
                                uri,
                                mode:
                                    LaunchMode.externalApplication,
                              );

                              if (!opened &&
                                  dialogContext.mounted) {
                                await _showOkDialog(
                                  dialogContext,
                                  title:
                                      'No se pudo abrir',
                                  message:
                                      'No fue posible abrir Google Maps.',
                                );
                              }
                            } catch (error) {
                              if (!dialogContext.mounted) {
                                return;
                              }

                              await _showOkDialog(
                                dialogContext,
                                title:
                                    'No se pudo abrir',
                                message:
                                    'No fue posible abrir Google Maps.',
                              );
                            }
                          },
                    icon: Icon(
                      Icons.directions_rounded,
                      color:
                          colors.textPrimary,
                    ),
                    label: Text(
                      'Abrir mapa',
                      style: TextStyle(
                        color:
                            colors.textPrimary,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          colors.textPrimary,
                      side: BorderSide(
                        color:
                            colors.border,
                      ),
                      shape:
                          const StadiumBorder(),
                    ),
                  ),
                if (!resolvedInDialog)
                  FilledButton.icon(
                    onPressed: processing
                        ? null
                        : () async {
                            setDialogState(() {
                              processing =
                                  true;
                            });

                            final bool success =
                                await _resolveEmergency(
                              emergencyId,
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            if (!success) {
                              setDialogState(() {
                                processing =
                                    false;
                              });

                              return;
                            }

                            setDialogState(() {
                              processing =
                                  false;

                              resolvedInDialog =
                                  true;
                            });

                            await _showOkDialog(
                              dialogContext,
                              title:
                                  'Emergencia atendida',
                              message:
                                  'La emergencia fue marcada como atendida correctamente.',
                            );
                          },
                    icon: processing
                        ? SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color:
                                  colors.primaryButtonText,
                            ),
                          )
                        : Icon(
                            Icons.check_circle_rounded,
                            color:
                                colors.primaryButtonText,
                          ),
                    label: Text(
                      processing
                          ? 'Guardando...'
                          : 'Marcar atendida',
                      style: TextStyle(
                        color:
                            colors.primaryButtonText,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          colors.categoryGreen,
                      foregroundColor:
                          colors.primaryButtonText,
                      shape:
                          const StadiumBorder(),
                    ),
                  ),
                TextButton(
                  onPressed: processing
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  style:
                      TextButton.styleFrom(
                    foregroundColor:
                        colors.textPrimary,
                  ),
                  child: Text(
                    'Cerrar',
                    style: TextStyle(
                      color:
                          colors.textPrimary,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      await _loadAll();
    }
  }
  }

// ============================================================
// DIÁLOGO DE CONFIRMACIÓN DE ELIMINACIÓN
// ============================================================

Future<bool> _showDeleteDialog(
  BuildContext context, {
  required String message,
}) async {
  final bool? result =
      await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (
      BuildContext dialogContext,
    ) {
      final AppColors colors =
          dialogContext.appColors;

      return AlertDialog(
        backgroundColor:
            colors.elevatedCard,
        surfaceTintColor:
            Colors.transparent,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          side: BorderSide(
            color:
                colors.border,
          ),
        ),
        titlePadding:
            const EdgeInsets.fromLTRB(
          22,
          22,
          22,
          8,
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(
          22,
          8,
          22,
          8,
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16,
        ),
        title: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    colors.emergency.withValues(
                  alpha: 0.15,
                ),
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color:
                    colors.emergency,
                size: 25,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Text(
                'Confirmar eliminación',
                style: TextStyle(
                  color:
                      colors.textPrimary,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color:
                colors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(
                false,
              );
            },
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  colors.textPrimary,
              side: BorderSide(
                color:
                    colors.border,
              ),
              shape:
                  const StadiumBorder(),
            ),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color:
                    colors.textPrimary,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(
                true,
              );
            },
            icon: Icon(
              Icons.delete_rounded,
              color:
                  colors.emergencyText,
            ),
            label: Text(
              'Eliminar',
              style: TextStyle(
                color:
                    colors.emergencyText,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  colors.emergency,
              foregroundColor:
                  colors.emergencyText,
              shape:
                  const StadiumBorder(),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

// ============================================================
// DIÁLOGO INFORMATIVO
// ============================================================

Future<void> _showOkDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (
      BuildContext dialogContext,
    ) {
      final AppColors colors =
          dialogContext.appColors;

      final bool isError =
          title.toLowerCase().contains(
                'error',
              ) ||
              title.toLowerCase().contains(
                'no se pudo',
              );

      final Color accentColor =
          isError
              ? colors.emergency
              : colors.categoryGreen;

      final IconData icon =
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded;

      return AlertDialog(
        backgroundColor:
            colors.elevatedCard,
        surfaceTintColor:
            Colors.transparent,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          side: BorderSide(
            color:
                colors.border,
          ),
        ),
        titlePadding:
            const EdgeInsets.fromLTRB(
          22,
          22,
          22,
          8,
        ),
        contentPadding:
            const EdgeInsets.fromLTRB(
          22,
          8,
          22,
          12,
        ),
        actionsPadding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        title: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    accentColor.withValues(
                  alpha: 0.15,
                ),
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),
              child: Icon(
                icon,
                color:
                    accentColor,
                size: 25,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color:
                      colors.textPrimary,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color:
                colors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            width:
                double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    accentColor,
                foregroundColor:
                    isError
                        ? colors.emergencyText
                        : colors.primaryButtonText,
                minimumSize:
                    const Size.fromHeight(
                  50,
                ),
                shape:
                    const StadiumBorder(),
              ),
              child: Text(
                'Aceptar',
                style: TextStyle(
                  color:
                      isError
                          ? colors.emergencyText
                          : colors.primaryButtonText,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ============================================================
// ESTADO VACÍO DE NOTIFICACIONES
// ============================================================

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(
    BuildContext context,
  ) {
    final AppColors colors =
        context.appColors;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration:
                  BoxDecoration(
                color:
                    colors.secondaryButton.withValues(
                  alpha: 0.13,
                ),
                shape:
                    BoxShape.circle,
                border: Border.all(
                  color:
                      colors.secondaryButton.withValues(
                    alpha: 0.30,
                  ),
                ),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                color:
                    colors.secondaryButton,
                size: 48,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              'No hay notificaciones',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    colors.textPrimary,
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Aquí aparecerán las emergencias, los recuerdos, '
              'las alarmas programadas y las demás notificaciones.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    colors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}