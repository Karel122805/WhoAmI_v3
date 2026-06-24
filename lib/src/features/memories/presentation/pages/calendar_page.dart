import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
  });

  @override
  State<CalendarPage> createState() {
    return _CalendarPageState();
  }
}

class _CalendarPageState extends State<CalendarPage> {
  static final DateTime _firstDay =
      DateTime(2020, 1, 1);

  static final DateTime _lastDay =
      DateTime(2100, 12, 31);

  DateTime _focusedDay =
      DateTime.now();

  DateTime? _selectedDay;

  final Set<String> _memoryDayIds =
      <String>{};

  final TextEditingController _searchCtrl =
      TextEditingController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _selectedMemories = [];

  DateTime _onlyDate(
    DateTime date,
  ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  String _dateId(
    DateTime date,
  ) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _isFutureDay(
    DateTime day,
  ) {
    return _onlyDate(day).isAfter(
      _onlyDate(
        DateTime.now(),
      ),
    );
  }

  bool _isToday(
    DateTime day,
  ) {
    return isSameDay(
      _onlyDate(day),
      _onlyDate(
        DateTime.now(),
      ),
    );
  }

  DateTime? _getCreatedAt(
    Map<String, dynamic> data,
  ) {
    final value =
        data['createdAt'];

    if (value is Timestamp) {
      return value
          .toDate()
          .toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      )?.toLocal();
    }

    return null;
  }

  bool _canEditMemory(
    Map<String, dynamic> data,
  ) {
    final createdAt =
        _getCreatedAt(data);

    if (createdAt == null) {
      return false;
    }

    final difference =
        DateTime.now().difference(
      createdAt,
    );

    return !difference.isNegative &&
        difference <=
            const Duration(
              hours: 24,
            );
  }

  String _editTimeRemaining(
    Map<String, dynamic> data,
  ) {
    final createdAt =
        _getCreatedAt(data);

    if (createdAt == null) {
      return 'Tiempo de edición no disponible';
    }

    final limit =
        createdAt.add(
      const Duration(
        hours: 24,
      ),
    );

    final remaining =
        limit.difference(
      DateTime.now(),
    );

    if (remaining.isNegative ||
        remaining.inSeconds <= 0) {
      return 'El tiempo para editar ya venció';
    }

    final hours =
        remaining.inHours;

    final minutes =
        remaining.inMinutes % 60;

    if (hours > 0) {
      return 'Puedes editarlo por '
          '$hours h $minutes min más';
    }

    return 'Puedes editarlo por '
        '$minutes min más';
  }

  @override
  void initState() {
    super.initState();

    initializeDateFormatting(
      'es_ES',
    );

    final today =
        _onlyDate(
      DateTime.now(),
    );

    _focusedDay =
        today;

    _selectedDay =
        today;

    _loadMemories(
      today,
    );

    _loadMonthMemories(
      today,
    );
  }

  String _formatDateEs(
    DateTime date,
  ) {
    return DateFormat(
      "d 'de' MMMM 'de' y",
      'es_ES',
    ).format(date);
  }

  String _formatTimeEs(
    DateTime date,
  ) {
    return DateFormat(
      'hh:mm a',
      'es_ES',
    ).format(date);
  }

  void _showDialog(
    String title,
    String message, {
    bool success = true,
  }) {
    if (!mounted) {
      return;
    }

    final colors =
        context.appColors;

    showDialog<void>(
      context:
          context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              colors.elevatedCard,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title:
              Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle
                    : Icons.error_outline,
                color:
                    success
                        ? colors.categoryGreen
                        : colors.emergency,
              ),
              const SizedBox(
                width:
                    8,
              ),
              Expanded(
                child:
                    Text(
                  title,
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontWeight:
                        FontWeight.bold,
                    fontSize:
                        18,
                  ),
                ),
              ),
            ],
          ),
          content:
              Text(
            message,
            style:
                TextStyle(
              color:
                  colors.textPrimary,
              fontSize:
                  15,
              height:
                  1.3,
            ),
          ),
          actions: [
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.secondaryButton,
                foregroundColor:
                    colors.secondaryButtonText,
                shape:
                    const StadiumBorder(),
                minimumSize:
                    const Size.fromHeight(
                  44,
                ),
              ),
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'Aceptar',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDialog(
    String title,
    String message,
  ) async {
    final colors =
        context.appColors;

    final result =
        await showDialog<bool>(
      context:
          context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              colors.elevatedCard,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title:
              Text(
            title,
            style:
                TextStyle(
              color:
                  colors.textPrimary,
              fontWeight:
                  FontWeight.bold,
              fontSize:
                  18,
            ),
          ),
          content:
              Text(
            message,
            style:
                TextStyle(
              color:
                  colors.textPrimary,
              fontSize:
                  15,
              height:
                  1.3,
            ),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actionsPadding:
              const EdgeInsets.symmetric(
            vertical:
                12,
            horizontal:
                8,
          ),
          actions: [
            Column(
              children: [
                FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        colors.emergency,
                    foregroundColor:
                        colors.emergencyText,
                    shape:
                        const StadiumBorder(),
                    minimumSize:
                        const Size.fromHeight(
                      48,
                    ),
                    elevation:
                        0,
                  ),
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child:
                      const Text(
                    'Cancelar',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(
                  height:
                      10,
                ),
                FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        colors.primaryButton,
                    foregroundColor:
                        colors.primaryButtonText,
                    shape:
                        const StadiumBorder(),
                    minimumSize:
                        const Size.fromHeight(
                      48,
                    ),
                    elevation:
                        0,
                  ),
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                      true,
                    );
                  },
                  child:
                      const Text(
                    'Confirmar',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    return result ??
        false;
  }

  Future<void> _showDateInfoDialog(
    DateTime selected,
  ) async {
    final isToday =
        _isToday(
      selected,
    );

    final count =
        _selectedMemories.length;

    if (isToday &&
        count > 0) {
      _showDialog(
        'Recuerdos de hoy',
        'Ya tienes $count '
        'recuerdo${count == 1 ? '' : 's'} '
        'guardado${count == 1 ? '' : 's'} hoy. '
        'Puedes agregar más o revisar la galería.',
      );

      return;
    }

    if (isToday &&
        count == 0) {
      _showDialog(
        'Recuerdos de hoy',
        'Aún no has guardado recuerdos hoy. '
        'Puedes subir uno ahora.',
      );

      return;
    }

    if (!isToday &&
        count > 0) {
      _showDialog(
        'Galería de recuerdos',
        'Estás viendo recuerdos de una fecha anterior. '
        'Puedes abrirlos para verlos en grande.',
      );

      return;
    }

    _showDialog(
      'Sin recuerdos',
      'No hay recuerdos guardados para esta fecha.',
      success:
          false,
    );
  }

  Future<void> _loadMemories(
    DateTime date,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection(
                'memories',
              )
              .doc(
                user.uid,
              )
              .collection(
                'user_memories',
              )
              .where(
                'displayDate',
                isEqualTo:
                    _dateId(
                  date,
                ),
              )
              .orderBy(
                'createdAt',
                descending:
                    false,
              )
              .get();

      if (!mounted) {
        return;
      }

      setState(
        () {
          _selectedMemories =
              snapshot.docs;
        },
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error cargando recuerdos del día: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  Future<void> _loadMonthMemories(
    DateTime date,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection(
                'memories',
              )
              .doc(
                user.uid,
              )
              .collection(
                'user_memories',
              )
              .get();

      if (!mounted) {
        return;
      }

      setState(
        () {
          _memoryDayIds
            ..clear()
            ..addAll(
              snapshot.docs
                  .map(
                    (
                      document,
                    ) {
                      return document
                              .data()['displayDate']
                              ?.toString() ??
                          '';
                    },
                  )
                  .where(
                    (
                      value,
                    ) {
                      return value.isNotEmpty;
                    },
                  ),
            );
        },
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error cargando días con recuerdos: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // GUARDAR NOTIFICACIÓN INMEDIATA
  // ============================================================

  Future<void> _saveImmediateMemoryNotification({
    required String userId,
    required String memoryId,
    required String title,
    required DateTime createdAt,
  }) async {
    final memoryPayload =
        '$userId/$memoryId';

    await FirebaseFirestore.instance
        .collection(
          'users',
        )
        .doc(
          userId,
        )
        .collection(
          'notifications',
        )
        .doc(
          'memory_saved_$memoryId',
        )
        .set(
      {
        'title':
            'Recuerdo guardado',
        'body':
            title.isEmpty
                ? 'Tienes un nuevo recuerdo guardado.'
                : title,
        'type':
            'memory_saved',
        'memoryId':
            memoryPayload,
        'payload':
            memoryPayload,
        'timestamp':
            Timestamp.fromDate(
          createdAt,
        ),
        'read':
            false,
        'deleted':
            false,
        'completed':
            false,
        'active':
            true,
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge:
            true,
      ),
    );
  }

  // ============================================================
  // CREAR NOTIFICACIONES SIN INTERRUMPIR EL GUARDADO
  // ============================================================

  Future<void> _createMemoryNotifications({
    required String userId,
    required String memoryId,
    required String title,
    required DateTime createdAt,
    required DateTime firstReminder,
  }) async {
    try {
      await _saveImmediateMemoryNotification(
        userId:
            userId,
        memoryId:
            memoryId,
        title:
            title,
        createdAt:
            createdAt,
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'El recuerdo se guardó, pero no se pudo crear '
        'la notificación interna: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    try {
      await NotificationsService.showInstant(
        title:
            'Recuerdo guardado',
        body:
            'Tienes un nuevo recuerdo guardado.',
        payload:
            '$userId/$memoryId',
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'El recuerdo se guardó, pero no se pudo mostrar '
        'la notificación inmediata: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }

    try {
      await NotificationsService.scheduleForMemory(
        memoryId:
            '$userId/$memoryId',
        title:
            title,
        anchorDate:
            firstReminder,
        cadence:
            MemoryCadence.weekly,
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'El recuerdo se guardó, pero no se pudo programar '
        'el recordatorio semanal: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }
    // ============================================================
  // ABRIR FORMULARIO PARA AGREGAR RECUERDO
  // ============================================================

  Future<void> _openAddMemoryDialog(
    DateTime date,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showDialog(
        'Sesión no disponible',
        'Debes iniciar sesión para guardar recuerdos.',
        success:
            false,
      );

      return;
    }

    if (!_isToday(
      date,
    )) {
      _showDialog(
        'Solo recuerdos de hoy',
        'Solo puedes agregar recuerdos en el día actual.',
        success:
            false,
      );

      return;
    }

    final result =
        await showModalBottomSheet<_NewMemoryResult>(
      context:
          context,
      isScrollControlled:
          true,
      backgroundColor:
          Colors.transparent,
      builder: (
        bottomSheetContext,
      ) {
        return _NewMemoryBottomSheet(
          dateText:
              _formatDateEs(
            date,
          ),
        );
      },
    );

    if (result == null ||
        !mounted) {
      return;
    }

    final selectedImage =
        result.image;

    final memoryText =
        result.text.trim();

    bool loadingDialogOpen =
        false;

    try {
      loadingDialogOpen =
          true;

      showDialog<void>(
        context:
            context,
        barrierDismissible:
            false,
        builder: (
          loadingContext,
        ) {
          final colors =
              loadingContext.appColors;

          return PopScope(
            canPop:
                false,
            child:
                AlertDialog(
              backgroundColor:
                  colors.elevatedCard,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              content:
                  Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical:
                      18,
                ),
                child:
                    Row(
                  children: [
                    const SizedBox(
                      width:
                          28,
                      height:
                          28,
                      child:
                          CircularProgressIndicator(),
                    ),
                    const SizedBox(
                      width:
                          18,
                    ),
                    Expanded(
                      child:
                          Text(
                        'Guardando recuerdo...',
                        style:
                            TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final userId =
          user.uid;

      final now =
          DateTime.now();

      final firstWeeklyReminder =
          now.add(
        const Duration(
          days:
              7,
        ),
      );

      final memoryReference =
          FirebaseFirestore.instance
              .collection(
                'memories',
              )
              .doc(
                userId,
              )
              .collection(
                'user_memories',
              )
              .doc();

      final memoryId =
          memoryReference.id;

      final storageReference =
          FirebaseStorage.instance
              .ref()
              .child(
                'user_memories',
              )
              .child(
                userId,
              )
              .child(
                '$memoryId.jpg',
              );

      await storageReference.putFile(
        selectedImage,
      );

      final imageUrl =
          await storageReference.getDownloadURL();

      final notificationText =
          memoryText.isEmpty
              ? 'Tienes un recuerdo guardado para volver a ver.'
              : memoryText;

      await memoryReference.set({
        'text':
            memoryText,
        'imageUrl':
            imageUrl,
        'displayDate':
            _dateId(
          now,
        ),
        'createdAt':
            Timestamp.fromDate(
          now,
        ),
        'updatedAt':
            Timestamp.fromDate(
          now,
        ),
        'reminder':
            <String, dynamic>{
          'enabled':
              true,
          'cadence':
              'weekly',
          'time':
              '${firstWeeklyReminder.hour.toString().padLeft(2, '0')}:'
                  '${firstWeeklyReminder.minute.toString().padLeft(2, '0')}',
          'timezone':
              'America/Mexico_City',
          'nextAt':
              Timestamp.fromDate(
            firstWeeklyReminder,
          ),
          'read':
              false,
          'deleted':
              false,
          'completed':
              false,
        },
      });

      await _createMemoryNotifications(
        userId:
            userId,
        memoryId:
            memoryId,
        title:
            notificationText,
        createdAt:
            now,
        firstReminder:
            firstWeeklyReminder,
      );

      if (loadingDialogOpen &&
          mounted) {
        Navigator.of(
          context,
          rootNavigator:
              true,
        ).pop();

        loadingDialogOpen =
            false;
      }

      if (!mounted) {
        return;
      }

      await _loadMemories(
        _selectedDay ??
            now,
      );

      if (!mounted) {
        return;
      }

      await _loadMonthMemories(
        _focusedDay,
      );

      if (!mounted) {
        return;
      }

      _showDialog(
        'Recuerdo guardado',
        'El recuerdo se guardó correctamente.\n\n'
            'Recibirás el primer recordatorio dentro de 7 días '
            'y después cada semana.',
      );
    } on FirebaseException catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error de Firebase guardando recuerdo: '
        '${error.code} - ${error.message}',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (loadingDialogOpen &&
          mounted) {
        Navigator.of(
          context,
          rootNavigator:
              true,
        ).pop();

        loadingDialogOpen =
            false;
      }

      if (!mounted) {
        return;
      }

      _showDialog(
        'Error al guardar',
        _firebaseErrorMessage(
          error,
        ),
        success:
            false,
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error guardando recuerdo: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (loadingDialogOpen &&
          mounted) {
        Navigator.of(
          context,
          rootNavigator:
              true,
        ).pop();

        loadingDialogOpen =
            false;
      }

      if (!mounted) {
        return;
      }

      _showDialog(
        'Error al guardar',
        'No se pudo guardar el recuerdo. '
            'Inténtalo nuevamente.',
        success:
            false,
      );
    }
  }

  String _firebaseErrorMessage(
    FirebaseException error,
  ) {
    switch (
      error.code
    ) {
      case 'permission-denied':
        return 'No tienes permiso para guardar este recuerdo. '
            'Verifica que las reglas de Firestore estén publicadas.';

      case 'unauthenticated':
        return 'Tu sesión terminó. Inicia sesión nuevamente.';

      case 'network-request-failed':
      case 'unavailable':
        return 'No hay conexión con Firebase. '
            'Comprueba tu conexión a internet.';

      case 'object-not-found':
        return 'No se pudo encontrar el archivo solicitado.';

      case 'unauthorized':
        return 'No tienes permiso para subir la imagen.';

      default:
        return error.message ??
            'Ocurrió un problema al guardar el recuerdo.';
    }
  }
    // ============================================================
  // EDITAR RECUERDO
  // ============================================================

  Future<void> _openEditMemoryDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> memoryDocument,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showDialog(
        'Sesión no disponible',
        'Debes iniciar sesión para editar recuerdos.',
        success: false,
      );

      return;
    }

    final memoryData =
        memoryDocument.data();

    if (!_canEditMemory(
      memoryData,
    )) {
      _showDialog(
        'Edición no disponible',
        'Solo puedes editar este recuerdo durante las primeras '
            '24 horas después de haberlo guardado.',
        success: false,
      );

      return;
    }

    final currentText =
        memoryData['text']
                ?.toString() ??
            '';

    final currentImageUrl =
        memoryData['imageUrl']
                ?.toString()
                .trim() ??
            '';

    final result =
        await showModalBottomSheet<_EditMemoryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (
        bottomSheetContext,
      ) {
        return _EditMemoryBottomSheet(
          currentText:
              currentText,
          currentImageUrl:
              currentImageUrl,
          editTimeText:
              _editTimeRemaining(
            memoryData,
          ),
        );
      },
    );

    if (result == null ||
        !mounted) {
      return;
    }

    bool loadingDialogOpen =
        false;

    try {
      loadingDialogOpen =
          true;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (
          loadingContext,
        ) {
          final colors =
              loadingContext.appColors;

          return PopScope(
            canPop: false,
            child: AlertDialog(
              backgroundColor:
                  colors.elevatedCard,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              content: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child:
                          CircularProgressIndicator(),
                    ),
                    const SizedBox(
                      width: 18,
                    ),
                    Expanded(
                      child: Text(
                        'Guardando cambios...',
                        style: TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final userId =
          user.uid;

      final memoryId =
          memoryDocument.id;

      String finalImageUrl =
          currentImageUrl;

      final newImage =
          result.image;

      if (newImage != null) {
        final storageReference =
            FirebaseStorage.instance
                .ref()
                .child(
                  'user_memories',
                )
                .child(
                  userId,
                )
                .child(
                  '$memoryId.jpg',
                );

        await storageReference.putFile(
          newImage,
        );

        finalImageUrl =
            await storageReference.getDownloadURL();
      }

      final updatedText =
          result.text.trim();

      await memoryDocument.reference.update({
        'text':
            updatedText,
        'imageUrl':
            finalImageUrl,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      await _updateMemoryNotificationTexts(
        userId:
            userId,
        memoryId:
            memoryId,
        text:
            updatedText,
      );

      if (loadingDialogOpen &&
          mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        loadingDialogOpen =
            false;
      }

      if (!mounted) {
        return;
      }

      await _loadMemories(
        _selectedDay ??
            DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      await _loadMonthMemories(
        _focusedDay,
      );

      if (!mounted) {
        return;
      }

      _showDialog(
        'Recuerdo actualizado',
        'El recuerdo se editó correctamente.',
      );
    } on FirebaseException catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error de Firebase editando recuerdo: '
        '${error.code} - ${error.message}',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (loadingDialogOpen &&
          mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        loadingDialogOpen =
            false;
      }

      if (!mounted) {
        return;
      }

      _showDialog(
        'Error al editar',
        _firebaseErrorMessage(
          error,
        ),
        success: false,
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error editando recuerdo: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (loadingDialogOpen &&
          mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop();

        loadingDialogOpen =
            false;
      }

      if (!mounted) {
        return;
      }

      _showDialog(
        'Error al editar',
        'No se pudo actualizar el recuerdo. '
            'Inténtalo nuevamente.',
        success: false,
      );
    }
  }

  // ============================================================
  // ACTUALIZAR TEXTOS DE NOTIFICACIONES DEL RECUERDO
  // ============================================================

  Future<void> _updateMemoryNotificationTexts({
    required String userId,
    required String memoryId,
    required String text,
  }) async {
    final memoryPayload =
        '$userId/$memoryId';

    final notificationText =
        text.isEmpty
            ? 'Tienes un recuerdo guardado para volver a ver.'
            : text;

    try {
      final notificationsCollection =
          FirebaseFirestore.instance
              .collection(
                'users',
              )
              .doc(
                userId,
              )
              .collection(
                'notifications',
              );

      final snapshot =
          await notificationsCollection
              .where(
                'memoryId',
                isEqualTo:
                    memoryPayload,
              )
              .get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch =
          FirebaseFirestore.instance.batch();

      for (final notificationDocument
          in snapshot.docs) {
        batch.set(
          notificationDocument.reference,
          {
            'body':
                notificationText,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'El recuerdo se actualizó, pero no se pudieron '
        'actualizar sus notificaciones: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }
    // ============================================================
  // VISOR DE RECUERDO
  // ============================================================

  Future<void> _openMemoryViewer(
    QueryDocumentSnapshot<Map<String, dynamic>> memoryDocument,
    int index,
  ) async {
    final colors =
        context.appColors;

    final memoryData =
        memoryDocument.data();

    final createdAt =
        _getCreatedAt(
      memoryData,
    );

    final canEdit =
        _canEditMemory(
      memoryData,
    );

    final imageUrl =
        memoryData['imageUrl']
                ?.toString()
                .trim() ??
            '';

    final text =
        memoryData['text']
                ?.toString()
                .trim() ??
            '';

    await showDialog<void>(
      context:
          context,
      builder: (
        dialogContext,
      ) {
        return Dialog.fullscreen(
          backgroundColor:
              Theme.of(
                context,
              ).scaffoldBackgroundColor,
          child:
              SafeArea(
            child:
                Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        12,
                    vertical:
                        8,
                  ),
                  child:
                      Row(
                    children: [
                      IconButton(
                        onPressed:
                            () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                        icon:
                            Icon(
                          Icons.arrow_back,
                          color:
                              colors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child:
                            Text(
                          'Recuerdo ${index + 1}',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                colors.textPrimary,
                            fontSize:
                                20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width:
                            48,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      24,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              20,
                            ),
                            child:
                                Image.network(
                              imageUrl,
                              width:
                                  double.infinity,
                              fit:
                                  BoxFit.cover,
                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return Container(
                                  width:
                                      double.infinity,
                                  height:
                                      260,
                                  alignment:
                                      Alignment.center,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        colors.inputFill,
                                    borderRadius:
                                        BorderRadius.circular(
                                      20,
                                    ),
                                  ),
                                  child:
                                      Icon(
                                    Icons.broken_image_outlined,
                                    color:
                                        colors.textSecondary,
                                    size:
                                        54,
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(
                          height:
                              16,
                        ),
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
                                colors.elevatedCard,
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
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recuerdo ${index + 1}',
                                style:
                                    TextStyle(
                                  color:
                                      colors.textPrimary,
                                  fontSize:
                                      19,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              const SizedBox(
                                height:
                                    8,
                              ),
                              Text(
                                _selectedDay !=
                                        null
                                    ? _formatDateEs(
                                        _selectedDay!,
                                      )
                                    : '',
                                style:
                                    TextStyle(
                                  color:
                                      colors.textSecondary,
                                  fontSize:
                                      14,
                                ),
                              ),
                              if (createdAt !=
                                  null) ...[
                                const SizedBox(
                                  height:
                                      6,
                                ),
                                Text(
                                  'Guardado a las ${_formatTimeEs(createdAt)}',
                                  style:
                                      TextStyle(
                                    color:
                                        colors.textSecondary,
                                    fontSize:
                                        13,
                                  ),
                                ),
                                const SizedBox(
                                  height:
                                      6,
                                ),
                                Text(
                                  canEdit
                                      ? _editTimeRemaining(
                                          memoryData,
                                        )
                                      : 'Este recuerdo ya no se puede editar',
                                  style:
                                      TextStyle(
                                    color:
                                        canEdit
                                            ? colors.categoryGreen
                                            : colors.emergency,
                                    fontSize:
                                        13,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(
                                height:
                                    14,
                              ),
                              Text(
                                text.isEmpty
                                    ? 'Sin descripción'
                                    : text,
                                style:
                                    TextStyle(
                                  color:
                                      colors.textPrimary,
                                  fontSize:
                                      16,
                                  height:
                                      1.4,
                                ),
                              ),
                              const SizedBox(
                                height:
                                    18,
                              ),
                              SizedBox(
                                width:
                                    double.infinity,
                                child:
                                    FilledButton.icon(
                                  style:
                                      FilledButton.styleFrom(
                                    backgroundColor:
                                        canEdit
                                            ? colors.secondaryButton
                                            : colors.border,
                                    foregroundColor:
                                        canEdit
                                            ? colors.secondaryButtonText
                                            : colors.textSecondary,
                                    shape:
                                        const StadiumBorder(),
                                    minimumSize:
                                        const Size.fromHeight(
                                      46,
                                    ),
                                  ),
                                  onPressed:
                                      canEdit
                                          ? () async {
                                              Navigator.pop(
                                                dialogContext,
                                              );

                                              await _openEditMemoryDialog(
                                                memoryDocument,
                                              );
                                            }
                                          : null,
                                  icon:
                                      const Icon(
                                    Icons.edit_outlined,
                                  ),
                                  label:
                                      const Text(
                                    'Editar',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ELIMINAR NOTIFICACIONES INTERNAS DE UN RECUERDO
  // ============================================================

  Future<void> _deleteMemoryNotifications({
    required String userId,
    required String memoryPayload,
    required String memoryId,
  }) async {
    try {
      final notificationsCollection =
          FirebaseFirestore.instance
              .collection(
                'users',
              )
              .doc(
                userId,
              )
              .collection(
                'notifications',
              );

      final notificationsSnapshot =
          await notificationsCollection.get();

      final batch =
          FirebaseFirestore.instance.batch();

      var changes =
          0;

      for (final notificationDocument
          in notificationsSnapshot.docs) {
        final notificationData =
            notificationDocument.data();

        final storedMemoryId =
            notificationData['memoryId']
                    ?.toString()
                    .trim() ??
                '';

        final payload =
            notificationData['payload']
                    ?.toString()
                    .trim() ??
                '';

        final isImmediateNotification =
            notificationDocument.id ==
                'memory_saved_$memoryId';

        final belongsToMemory =
            storedMemoryId ==
                    memoryPayload ||
                payload ==
                    memoryPayload ||
                isImmediateNotification;

        if (!belongsToMemory) {
          continue;
        }

        batch.set(
          notificationDocument.reference,
          {
            'read':
                true,
            'deleted':
                true,
            'active':
                false,
            'deletedAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge:
                true,
          ),
        );

        changes++;
      }

      if (changes > 0) {
        await batch.commit();
      }
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'No se pudieron actualizar las notificaciones '
        'del recuerdo eliminado: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // ELIMINAR RECUERDO
  // ============================================================

  Future<void> _deleteMemory(
    QueryDocumentSnapshot<Map<String, dynamic>> memoryDocument,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showDialog(
        'Sesión no disponible',
        'Debes iniciar sesión para eliminar recuerdos.',
        success:
            false,
      );

      return;
    }

    final confirmed =
        await _confirmDialog(
      'Eliminar recuerdo',
      '¿Deseas eliminar este recuerdo?\n\n'
          'También se cancelará su recordatorio semanal.',
    );

    if (!confirmed) {
      return;
    }

    final memoryData =
        memoryDocument.data();

    final userId =
        user.uid;

    final memoryId =
        memoryDocument.id;

    final memoryPayload =
        '$userId/$memoryId';

    try {
      await NotificationsService.cancelAllForMemory(
        memoryPayload,
      );

      await _deleteMemoryNotifications(
        userId:
            userId,
        memoryPayload:
            memoryPayload,
        memoryId:
            memoryId,
      );

      await memoryDocument.reference.delete();

      final imageUrl =
          memoryData['imageUrl']
                  ?.toString()
                  .trim() ??
              '';

      if (imageUrl.isNotEmpty) {
        try {
          final storageReference =
              FirebaseStorage.instance
                  .ref()
                  .child(
                    'user_memories',
                  )
                  .child(
                    userId,
                  )
                  .child(
                    '$memoryId.jpg',
                  );

          await storageReference.delete();
        } catch (
          error,
          stackTrace
        ) {
          debugPrint(
            'El recuerdo se eliminó, pero no se pudo '
            'eliminar su imagen: $error',
          );

          debugPrint(
            stackTrace.toString(),
          );
        }
      }

      await _loadMemories(
        _selectedDay ??
            DateTime.now(),
      );

      if (!mounted) {
        return;
      }

      await _loadMonthMemories(
        _focusedDay,
      );

      if (!mounted) {
        return;
      }

      _showDialog(
        'Recuerdo eliminado',
        'El recuerdo y su recordatorio semanal '
            'se eliminaron correctamente.',
      );
    } on FirebaseException catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error de Firebase eliminando recuerdo: '
        '${error.code} - ${error.message}',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      _showDialog(
        'Error al eliminar',
        _firebaseErrorMessage(
          error,
        ),
        success:
            false,
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error eliminando recuerdo: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      _showDialog(
        'Error al eliminar',
        'No se pudo eliminar el recuerdo. '
            'Inténtalo nuevamente.',
        success:
            false,
      );
    }
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    final selectedDate =
        _selectedDay ??
            _onlyDate(
              DateTime.now(),
            );

    final isSelectedToday =
        _isToday(
      selectedDate,
    );

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Recuerdos',
        ),
        centerTitle:
            true,
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.only(
          bottom:
              24,
        ),
        child:
            Column(
          children: [
            const SizedBox(
              height:
                  12,
            ),

            // ==================================================
            // BUSCADOR DE FECHA
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    16,
              ),
              child:
                  TextField(
                controller:
                    _searchCtrl,
                keyboardType:
                    TextInputType.number,
                style:
                    TextStyle(
                  color:
                      colors.textPrimary,
                ),
                decoration:
                    InputDecoration(
                  hintText:
                      'Ir a fecha (D/M/A)',
                  prefixIcon:
                      Icon(
                    Icons.calendar_today_outlined,
                    color:
                        colors.textSecondary,
                  ),
                  suffixIcon:
                      _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed:
                                  () {
                                setState(
                                  () {
                                    _searchCtrl.clear();
                                  },
                                );
                              },
                              icon:
                                  Icon(
                                Icons.clear,
                                color:
                                    colors.textSecondary,
                              ),
                            )
                          : null,
                ),
                onChanged:
                    _onDateInputChanged,
              ),
            ),

            const SizedBox(
              height:
                  16,
            ),
                        // ==================================================
            // CALENDARIO
            // ==================================================

            Container(
              margin:
                  const EdgeInsets.symmetric(
                horizontal:
                    16,
                vertical:
                    12,
              ),
              padding:
                  const EdgeInsets.all(
                8,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colors.calendarSurface,
                border:
                    Border.all(
                  color:
                      colors.primaryButton,
                  width:
                      2,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child:
                  TableCalendar<String>(
                locale:
                    'es_ES',
                firstDay:
                    _firstDay,
                lastDay:
                    _lastDay,
                focusedDay:
                    _focusedDay,
                calendarFormat:
                    CalendarFormat.month,
                headerStyle:
                    HeaderStyle(
                  formatButtonVisible:
                      false,
                  titleCentered:
                      true,
                  leftChevronIcon:
                      Icon(
                    Icons.chevron_left,
                    color:
                        colors.textSecondary,
                  ),
                  rightChevronIcon:
                      Icon(
                    Icons.chevron_right,
                    color:
                        colors.textSecondary,
                  ),
                  titleTextStyle:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                daysOfWeekStyle:
                    DaysOfWeekStyle(
                  weekdayStyle:
                      TextStyle(
                    color:
                        colors.textSecondary,
                  ),
                  weekendStyle:
                      TextStyle(
                    color:
                        colors.textSecondary,
                  ),
                ),
                calendarStyle:
                    CalendarStyle(
                  defaultTextStyle:
                      TextStyle(
                    color:
                        colors.textPrimary,
                  ),
                  weekendTextStyle:
                      TextStyle(
                    color:
                        colors.textPrimary,
                  ),
                  outsideTextStyle:
                      TextStyle(
                    color:
                        colors.textSecondary,
                  ),
                  todayDecoration:
                      BoxDecoration(
                    color:
                        colors.primaryButton,
                    shape:
                        BoxShape.circle,
                  ),
                  todayTextStyle:
                      TextStyle(
                    color:
                        colors.primaryButtonText,
                  ),
                  selectedDecoration:
                      BoxDecoration(
                    color:
                        colors.secondaryButton,
                    shape:
                        BoxShape.circle,
                  ),
                  selectedTextStyle:
                      TextStyle(
                    color:
                        colors.secondaryButtonText,
                  ),
                  defaultDecoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                  ),
                  weekendDecoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                  ),
                  markersAlignment:
                      Alignment.bottomCenter,
                  markersMaxCount:
                      1,
                  disabledTextStyle:
                      TextStyle(
                    color:
                        colors.textSecondary,
                  ),
                ),
                enabledDayPredicate:
                    (
                  day,
                ) {
                  return true;
                },
                eventLoader:
                    (
                  day,
                ) {
                  return _memoryDayIds.contains(
                    _dateId(
                      day,
                    ),
                  )
                      ? const <String>[
                          'memory',
                        ]
                      : const <String>[];
                },
                calendarBuilders:
                    CalendarBuilders<String>(
                  markerBuilder:
                      (
                    context,
                    day,
                    events,
                  ) {
                    if (events.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom:
                            3,
                      ),
                      child:
                          Container(
                        width:
                            6,
                        height:
                            6,
                        decoration:
                            BoxDecoration(
                          color:
                              colors.primaryButton,
                          shape:
                              BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
                selectedDayPredicate:
                    (
                  day,
                ) {
                  return isSameDay(
                    day,
                    _selectedDay,
                  );
                },
                onDaySelected:
                    (
                  selected,
                  focused,
                ) async {
                  if (_isFutureDay(
                    selected,
                  )) {
                    _showDialog(
                      'Fecha no permitida',
                      'No puedes seleccionar una fecha futura '
                          'para agregar o ver recuerdos.',
                      success:
                          false,
                    );

                    return;
                  }

                  setState(
                    () {
                      _selectedDay =
                          selected;

                      _focusedDay =
                          focused;
                    },
                  );

                  await _loadMemories(
                    selected,
                  );

                  if (!mounted) {
                    return;
                  }

                  await _showDateInfoDialog(
                    selected,
                  );
                },
                onPageChanged:
                    (
                  focused,
                ) {
                  setState(
                    () {
                      _focusedDay =
                          focused;
                    },
                  );

                  _loadMonthMemories(
                    focused,
                  );
                },
              ),
            ),

            // ==================================================
            // BOTÓN AGREGAR
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    16,
                vertical:
                    8,
              ),
              child:
                  FilledButton.icon(
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      isSelectedToday
                          ? colors.secondaryButton
                          : colors.border,
                  foregroundColor:
                      isSelectedToday
                          ? colors.secondaryButtonText
                          : colors.textSecondary,
                  minimumSize:
                      const Size.fromHeight(
                    48,
                  ),
                  shape:
                      const StadiumBorder(),
                ),
                icon:
                    Icon(
                  isSelectedToday
                      ? Icons.add_a_photo_outlined
                      : Icons.lock_outline,
                ),
                label:
                    Text(
                  isSelectedToday
                      ? 'Agregar recuerdo de hoy'
                      : 'Solo disponible hoy',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                onPressed:
                    () async {
                  if (!isSelectedToday) {
                    _showDialog(
                      'Edición no disponible',
                      'Solo puedes agregar recuerdos '
                          'en el día actual.',
                      success:
                          false,
                    );

                    return;
                  }

                  final wantsToAdd =
                      await _confirmDialog(
                    'Agregar recuerdo',
                    '¿Deseas agregar un nuevo recuerdo para hoy?',
                  );

                  if (!wantsToAdd) {
                    return;
                  }

                  await _openAddMemoryDialog(
                    selectedDate,
                  );
                },
              ),
            ),

            // ==================================================
            // TÍTULO DE GALERÍA
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    16,
                vertical:
                    6,
              ),
              child:
                  Align(
                alignment:
                    Alignment.centerLeft,
                child:
                    Text(
                  _selectedMemories.isEmpty
                      ? 'Galería de recuerdos'
                      : 'Galería de recuerdos '
                          '(${_selectedMemories.length})',
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            // ==================================================
            // ESTADO VACÍO
            // ==================================================

            if (_selectedMemories.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      16,
                  vertical:
                      8,
                ),
                child:
                    Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    18,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        colors.elevatedCard,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    border:
                        Border.all(
                      color:
                          colors.border,
                    ),
                  ),
                  child:
                      Column(
                    children: [
                      Icon(
                        Icons.photo_album_outlined,
                        color:
                            colors.textSecondary,
                        size:
                            34,
                      ),
                      const SizedBox(
                        height:
                            8,
                      ),
                      Text(
                        'No hay recuerdos guardados para esta fecha.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              colors.textPrimary,
                          fontSize:
                              15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height:
                    290,
                child:
                    ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        16,
                    vertical:
                        8,
                  ),
                  scrollDirection:
                      Axis.horizontal,
                  itemCount:
                      _selectedMemories.length,
                  separatorBuilder:
                      (
                    context,
                    index,
                  ) {
                    return const SizedBox(
                      width:
                          12,
                    );
                  },
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final memoryDocument =
                        _selectedMemories[index];

                    final memoryData =
                        memoryDocument.data();

                    final canEdit =
                        _canEditMemory(
                      memoryData,
                    );

                    final imageUrl =
                        memoryData['imageUrl']
                                ?.toString()
                                .trim() ??
                            '';

                    final text =
                        memoryData['text']
                                ?.toString()
                                .trim() ??
                            '';

                    return GestureDetector(
                      onTap:
                          () {
                        _openMemoryViewer(
                          memoryDocument,
                          index,
                        );
                      },
                      child:
                          Container(
                        width:
                            220,
                        clipBehavior:
                            Clip.antiAlias,
                        decoration:
                            BoxDecoration(
                          color:
                              colors.elevatedCard,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          border:
                              Border.all(
                            color:
                                colors.border,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  context.isDark
                                      ? Colors.black.withValues(
                                          alpha:
                                              0.18,
                                        )
                                      : Colors.black.withValues(
                                          alpha:
                                              0.05,
                                        ),
                              blurRadius:
                                  16,
                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                          ],
                        ),
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child:
                                  imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit:
                                              BoxFit.cover,
                                          errorBuilder:
                                              (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              color:
                                                  colors.inputFill,
                                              alignment:
                                                  Alignment.center,
                                              child:
                                                  Icon(
                                                Icons.broken_image_outlined,
                                                color:
                                                    colors.textSecondary,
                                                size:
                                                    42,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color:
                                              colors.inputFill,
                                          alignment:
                                              Alignment.center,
                                          child:
                                              Icon(
                                            Icons.photo,
                                            color:
                                                colors.textSecondary,
                                            size:
                                                42,
                                          ),
                                        ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                6,
                              ),
                              child:
                                  Text(
                                'Recuerdo ${index + 1}',
                                style:
                                    TextStyle(
                                  color:
                                      colors.textPrimary,
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal:
                                    12,
                              ),
                              child:
                                  Text(
                                text.isEmpty
                                    ? 'Sin descripción'
                                    : text,
                                maxLines:
                                    2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    TextStyle(
                                  color:
                                      colors.textSecondary,
                                  fontSize:
                                      13,
                                  height:
                                      1.3,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                12,
                                6,
                                12,
                                0,
                              ),
                              child:
                                  Text(
                                canEdit
                                    ? _editTimeRemaining(
                                        memoryData,
                                      )
                                    : 'Ya no se puede editar',
                                maxLines:
                                    2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    TextStyle(
                                  color:
                                      canEdit
                                          ? colors.categoryGreen
                                          : colors.emergency,
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                8,
                                8,
                                8,
                                10,
                              ),
                              child:
                                  Row(
                                children: [
                                  Expanded(
                                    child:
                                        TextButton.icon(
                                      onPressed:
                                          () {
                                        _openMemoryViewer(
                                          memoryDocument,
                                          index,
                                        );
                                      },
                                      icon:
                                          const Icon(
                                        Icons.open_in_full,
                                      ),
                                      label:
                                          const Text(
                                        'Ver',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        'Editar recuerdo',
                                    onPressed:
                                        canEdit
                                            ? () {
                                                _openEditMemoryDialog(
                                                  memoryDocument,
                                                );
                                              }
                                            : null,
                                    icon:
                                        Icon(
                                      Icons.edit_outlined,
                                      color:
                                          canEdit
                                              ? colors.primaryButton
                                              : colors.textSecondary,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        'Eliminar recuerdo',
                                    onPressed:
                                        isSelectedToday
                                            ? () {
                                                _deleteMemory(
                                                  memoryDocument,
                                                );
                                              }
                                            : null,
                                    icon:
                                        Icon(
                                      Icons.delete_outline,
                                      color:
                                          isSelectedToday
                                              ? colors.emergency
                                              : colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
    void _onDateInputChanged(
    String value,
  ) {
    if (value.length == 2 &&
        !value.contains('/')) {
      _searchCtrl.text =
          '$value/';

      _searchCtrl.selection =
          TextSelection.fromPosition(
        TextPosition(
          offset:
              _searchCtrl.text.length,
        ),
      );

      setState(() {});

      return;
    }

    if (value.length == 5 &&
        value.split('/').length == 2) {
      _searchCtrl.text =
          '$value/';

      _searchCtrl.selection =
          TextSelection.fromPosition(
        TextPosition(
          offset:
              _searchCtrl.text.length,
        ),
      );

      setState(() {});

      return;
    }

    final parts =
        value.split('/');

    if (parts.length == 3 &&
        parts[2].length == 4) {
      final day =
          int.tryParse(
        parts[0],
      );

      final month =
          int.tryParse(
        parts[1],
      );

      final year =
          int.tryParse(
        parts[2],
      );

      if (day == null ||
          month == null ||
          year == null) {
        return;
      }

      if (month < 1 ||
          month > 12 ||
          day < 1 ||
          day > 31) {
        return;
      }

      final newDate =
          DateTime(
        year,
        month,
        day,
      );

      if (newDate.year != year ||
          newDate.month != month ||
          newDate.day != day) {
        return;
      }

      if (_isFutureDay(
        newDate,
      )) {
        _showDialog(
          'Fecha no permitida',
          'No puedes seleccionar una fecha futura '
              'para agregar o ver recuerdos.',
          success:
              false,
        );

        return;
      }

      setState(() {
        _selectedDay =
            newDate;

        _focusedDay =
            newDate;
      });

      _loadMemories(
        newDate,
      ).then(
        (_) {
          if (!mounted) {
            return;
          }

          _showDateInfoDialog(
            newDate,
          );
        },
      );

      _loadMonthMemories(
        newDate,
      );

      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();

    super.dispose();
  }
}

// ============================================================
// RESULTADO DEL FORMULARIO DE NUEVO RECUERDO
// ============================================================

class _NewMemoryResult {
  const _NewMemoryResult({
    required this.image,
    required this.text,
  });

  final File image;
  final String text;
}

// ============================================================
// FORMULARIO DE NUEVO RECUERDO
// ============================================================

class _NewMemoryBottomSheet
    extends StatefulWidget {
  const _NewMemoryBottomSheet({
    required this.dateText,
  });

  final String dateText;

  @override
  State<_NewMemoryBottomSheet>
      createState() {
    return _NewMemoryBottomSheetState();
  }
}

class _NewMemoryBottomSheetState
    extends State<_NewMemoryBottomSheet> {
  final TextEditingController
      _textController =
      TextEditingController();

  final ImagePicker _imagePicker =
      ImagePicker();

  File? _selectedImage;

  bool _openingPicker =
      false;

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    if (_openingPicker) {
      return;
    }

    setState(() {
      _openingPicker =
          true;
    });

    try {
      final pickedImage =
          await _imagePicker.pickImage(
        source:
            source,
        imageQuality:
            80,
      );

      if (!mounted ||
          pickedImage == null) {
        return;
      }

      setState(() {
        _selectedImage =
            File(
          pickedImage.path,
        );
      });
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error seleccionando imagen: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'No se pudo seleccionar la imagen.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingPicker =
              false;
        });
      }
    }
  }

  void _submit() {
    final image =
        _selectedImage;

    if (image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Debes subir una foto antes de guardar.',
          ),
        ),
      );

      return;
    }

    Navigator.of(
      context,
    ).pop(
      _NewMemoryResult(
        image:
            image,
        text:
            _textController.text,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    return SafeArea(
      top:
          false,
      child:
          Padding(
        padding:
            EdgeInsets.only(
          bottom:
              MediaQuery.of(
                    context,
                  ).viewInsets.bottom,
        ),
        child:
            Container(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            20,
          ),
          decoration:
              BoxDecoration(
            color:
                colors.elevatedCard,
            borderRadius:
                const BorderRadius.vertical(
              top:
                  Radius.circular(
                24,
              ),
            ),
          ),
          child:
              SingleChildScrollView(
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width:
                      60,
                  height:
                      5,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.border,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(
                  height:
                      12,
                ),
                Text(
                  'Nuevo recuerdo',
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height:
                      6,
                ),
                Text(
                  widget.dateText,
                  style:
                      TextStyle(
                    color:
                        colors.textSecondary,
                    fontSize:
                        14,
                  ),
                ),
                const SizedBox(
                  height:
                      14,
                ),
                TextField(
                  controller:
                      _textController,
                  maxLines:
                      3,
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                  ),
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Escribe algo sobre este recuerdo...',
                  ),
                ),
                const SizedBox(
                  height:
                      12,
                ),
                if (_selectedImage !=
                    null)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    child:
                        Image.file(
                      _selectedImage!,
                      height:
                          170,
                      width:
                          double.infinity,
                      fit:
                          BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height:
                        140,
                    width:
                        double.infinity,
                    decoration:
                        BoxDecoration(
                      color:
                          colors.inputFill,
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
                    child:
                        Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          color:
                              colors.textSecondary,
                          size:
                              34,
                        ),
                        const SizedBox(
                          height:
                              8,
                        ),
                        Text(
                          'Agrega una foto del recuerdo',
                          style:
                              TextStyle(
                            color:
                                colors.textSecondary,
                            fontSize:
                                14,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(
                  height:
                      12,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              colors.secondaryButton,
                          foregroundColor:
                              colors.secondaryButtonText,
                          shape:
                              const StadiumBorder(),
                          minimumSize:
                              const Size(
                            0,
                            46,
                          ),
                        ),
                        onPressed:
                            _openingPicker
                                ? null
                                : () {
                                    _pickImage(
                                      ImageSource.gallery,
                                    );
                                  },
                        icon:
                            const Icon(
                          Icons.image_outlined,
                        ),
                        label:
                            const Text(
                          'Galería',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width:
                          10,
                    ),
                    Expanded(
                      child:
                          ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              colors.categoryGreen,
                          foregroundColor:
                              colors.textPrimary,
                          shape:
                              const StadiumBorder(),
                          minimumSize:
                              const Size(
                            0,
                            46,
                          ),
                        ),
                        onPressed:
                            _openingPicker
                                ? null
                                : () {
                                    _pickImage(
                                      ImageSource.camera,
                                    );
                                  },
                        icon:
                            const Icon(
                          Icons.camera_alt_outlined,
                        ),
                        label:
                            const Text(
                          'Cámara',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height:
                      14,
                ),
                FilledButton.icon(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        colors.primaryButton,
                    foregroundColor:
                        colors.primaryButtonText,
                    shape:
                        const StadiumBorder(),
                    minimumSize:
                        const Size.fromHeight(
                      48,
                    ),
                  ),
                  onPressed:
                      _openingPicker
                          ? null
                          : _submit,
                  icon:
                      const Icon(
                    Icons.save_outlined,
                  ),
                  label:
                      Text(
                    _openingPicker
                        ? 'Abriendo imagen...'
                        : 'Guardar recuerdo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();

    super.dispose();
  }
}

// ============================================================
// RESULTADO DEL FORMULARIO DE EDICIÓN
// ============================================================

class _EditMemoryResult {
  const _EditMemoryResult({
    required this.text,
    this.image,
  });

  final String text;
  final File? image;
}

// ============================================================
// FORMULARIO DE EDICIÓN
// ============================================================

class _EditMemoryBottomSheet
    extends StatefulWidget {
  const _EditMemoryBottomSheet({
    required this.currentText,
    required this.currentImageUrl,
    required this.editTimeText,
  });

  final String currentText;
  final String currentImageUrl;
  final String editTimeText;

  @override
  State<_EditMemoryBottomSheet>
      createState() {
    return _EditMemoryBottomSheetState();
  }
}

class _EditMemoryBottomSheetState
    extends State<_EditMemoryBottomSheet> {
  late final TextEditingController
      _textController;

  final ImagePicker _imagePicker =
      ImagePicker();

  File? _selectedImage;

  bool _openingPicker =
      false;

  @override
  void initState() {
    super.initState();

    _textController =
        TextEditingController(
      text:
          widget.currentText,
    );
  }

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    if (_openingPicker) {
      return;
    }

    setState(() {
      _openingPicker =
          true;
    });

    try {
      final pickedImage =
          await _imagePicker.pickImage(
        source:
            source,
        imageQuality:
            80,
      );

      if (!mounted ||
          pickedImage == null) {
        return;
      }

      setState(() {
        _selectedImage =
            File(
          pickedImage.path,
        );
      });
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error seleccionando nueva imagen: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'No se pudo seleccionar la imagen.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingPicker =
              false;
        });
      }
    }
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop(
      _EditMemoryResult(
        text:
            _textController.text,
        image:
            _selectedImage,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    return SafeArea(
      top:
          false,
      child:
          Padding(
        padding:
            EdgeInsets.only(
          bottom:
              MediaQuery.of(
                    context,
                  ).viewInsets.bottom,
        ),
        child:
            Container(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            20,
          ),
          decoration:
              BoxDecoration(
            color:
                colors.elevatedCard,
            borderRadius:
                const BorderRadius.vertical(
              top:
                  Radius.circular(
                24,
              ),
            ),
          ),
          child:
              SingleChildScrollView(
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width:
                      60,
                  height:
                      5,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.border,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(
                  height:
                      12,
                ),
                Text(
                  'Editar recuerdo',
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height:
                      6,
                ),
                Text(
                  widget.editTimeText,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        colors.textSecondary,
                    fontSize:
                        14,
                  ),
                ),
                const SizedBox(
                  height:
                      14,
                ),
                TextField(
                  controller:
                      _textController,
                  maxLines:
                      3,
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                  ),
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Edita la descripción de este recuerdo...',
                  ),
                ),
                const SizedBox(
                  height:
                      12,
                ),
                if (_selectedImage !=
                    null)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    child:
                        Image.file(
                      _selectedImage!,
                      height:
                          170,
                      width:
                          double.infinity,
                      fit:
                          BoxFit.cover,
                    ),
                  )
                else if (widget.currentImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    child:
                        Image.network(
                      widget.currentImageUrl,
                      height:
                          170,
                      width:
                          double.infinity,
                      fit:
                          BoxFit.cover,
                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return Container(
                          height:
                              170,
                          width:
                              double.infinity,
                          alignment:
                              Alignment.center,
                          decoration:
                              BoxDecoration(
                            color:
                                colors.inputFill,
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color:
                                  colors.border,
                            ),
                          ),
                          child:
                              Icon(
                            Icons.broken_image_outlined,
                            color:
                                colors.textSecondary,
                            size:
                                44,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height:
                        140,
                    width:
                        double.infinity,
                    alignment:
                        Alignment.center,
                    decoration:
                        BoxDecoration(
                      color:
                          colors.inputFill,
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
                    child:
                        Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          color:
                              colors.textSecondary,
                          size:
                              34,
                        ),
                        const SizedBox(
                          height:
                              8,
                        ),
                        Text(
                          'Agrega una foto del recuerdo',
                          style:
                              TextStyle(
                            color:
                                colors.textSecondary,
                            fontSize:
                                14,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(
                  height:
                      12,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              colors.secondaryButton,
                          foregroundColor:
                              colors.secondaryButtonText,
                          shape:
                              const StadiumBorder(),
                          minimumSize:
                              const Size(
                            0,
                            46,
                          ),
                        ),
                        onPressed:
                            _openingPicker
                                ? null
                                : () {
                                    _pickImage(
                                      ImageSource.gallery,
                                    );
                                  },
                        icon:
                            const Icon(
                          Icons.image_outlined,
                        ),
                        label:
                            const Text(
                          'Cambiar foto',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width:
                          10,
                    ),
                    Expanded(
                      child:
                          ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              colors.categoryGreen,
                          foregroundColor:
                              colors.textPrimary,
                          shape:
                              const StadiumBorder(),
                          minimumSize:
                              const Size(
                            0,
                            46,
                          ),
                        ),
                        onPressed:
                            _openingPicker
                                ? null
                                : () {
                                    _pickImage(
                                      ImageSource.camera,
                                    );
                                  },
                        icon:
                            const Icon(
                          Icons.camera_alt_outlined,
                        ),
                        label:
                            const Text(
                          'Cámara',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height:
                      14,
                ),
                FilledButton.icon(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        colors.primaryButton,
                    foregroundColor:
                        colors.primaryButtonText,
                    shape:
                        const StadiumBorder(),
                    minimumSize:
                        const Size.fromHeight(
                      48,
                    ),
                  ),
                  onPressed:
                      _openingPicker
                          ? null
                          : _submit,
                  icon:
                      const Icon(
                    Icons.edit_outlined,
                  ),
                  label:
                      Text(
                    _openingPicker
                        ? 'Abriendo imagen...'
                        : 'Guardar cambios',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();

    super.dispose();
  }
}