import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/core/tutorial/tutorial_manager.dart';

import 'package:whoami_app/src/features/assistant/presentation/pages/assistant_page.dart';
import 'package:whoami_app/src/features/emergency/presentation/pages/emergency_map_page.dart';
import 'package:whoami_app/src/features/emergency/presentation/pages/panic_button_page.dart';
import 'package:whoami_app/src/features/memories/data/memories_scheduler.dart';
import 'package:whoami_app/src/features/memories/presentation/pages/calendar_page.dart';
import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';
import 'package:whoami_app/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:whoami_app/src/features/patients/presentation/pages/patients_list_page.dart';
import 'package:whoami_app/src/features/preventive_info/presentation/preventive_info_screen.dart';
import 'package:whoami_app/src/features/support_contacts/presentation/support_contacts_screen.dart';
import 'package:whoami_app/src/features/tips/presentation/pages/quick_guides_page.dart';

class HomeCaregiverPage extends StatefulWidget {
  const HomeCaregiverPage({
    super.key,
    this.displayName,
  });

  static const route = '/home/caregiver';

  final String? displayName;

  @override
  State<HomeCaregiverPage> createState() {
    return _HomeCaregiverPageState();
  }
}

class _HomeCaregiverPageState extends State<HomeCaregiverPage> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _emergencySubscription;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _patientRequestResponseSubscription;

  final Set<String> _processedEmergencyIds =
      <String>{};

  final Set<String> _processedPatientRequestResponseIds =
      <String>{};

  bool _emergencyDialogVisible = false;

  bool _patientRequestDialogVisible = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) {
          return;
        }

        await _initializeHome();

        if (!mounted) {
          return;
        }

        await TutorialManager.maybeShowCaregiverHome(
          context,
        );

        if (!mounted) {
          return;
        }

        _listenForPatientRequestResponses();
        _listenForEmergencyAlerts();
      },
    );
  }

  Future<void> _initializeHome() async {
    try {
      await NotificationsService.ensureInitialized();

      final uid =
          FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        await MemoriesScheduler.scheduleAllForUser(
          uid,
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error inicializando la pantalla del cuidador: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  int _countUnreadAppNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.where(
      (document) {
        final data =
            document.data();

        final read =
            data['read'] == true;

        final deleted =
            data['deleted'] == true;

        final completed =
            data['completed'] == true;

        final resolved =
            data['resolved'] == true;

        final activeValue =
            data['active'];

        final inactive =
            activeValue != null &&
            activeValue == false;

        final type =
            data['type']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final isEmergency =
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
            !isEmergency;
      },
    ).length;
  }

 int _countUnreadEmergencies(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  return snapshot.docs.where(
    (document) {
      final data = document.data();

      final deleted = data['deleted'] == true;

      return !deleted;
    },
  ).length;
}

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(
      context,
      NotificationsPage.route,
    );
  }

  void _listenForPatientRequestResponses() {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    _patientRequestResponseSubscription?.cancel();

    _patientRequestResponseSubscription =
        FirebaseFirestore.instance
            .collection('notifications')
            .where(
              'userId',
              isEqualTo: uid,
            )
            .where(
              'read',
              isEqualTo: false,
            )
            .snapshots()
            .listen(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) async {
        if (!mounted ||
            snapshot.docs.isEmpty ||
            _patientRequestDialogVisible) {
          return;
        }

        for (final document in snapshot.docs) {
          if (_processedPatientRequestResponseIds.contains(
            document.id,
          )) {
            continue;
          }

          final data =
              document.data();

          final type =
              data['type']
                      ?.toString()
                      .trim() ??
                  '';

          final accepted =
              type ==
                  'patient_request_accepted';

          final rejected =
              type ==
                  'patient_request_rejected';

          if (!accepted &&
              !rejected) {
            continue;
          }

          _processedPatientRequestResponseIds.add(
            document.id,
          );

          _patientRequestDialogVisible =
              true;

          try {
            final patientId =
                data['patientId']
                        ?.toString()
                        .trim() ??
                    '';

            String patientName =
                data['patientName']
                        ?.toString()
                        .trim() ??
                    '';

            if (patientName.isEmpty &&
                patientId.isNotEmpty) {
              try {
                final patientDocument =
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(patientId)
                        .get();

                final patientData =
                    patientDocument.data();

                if (patientData != null) {
                  final firstName =
                      patientData['firstName']
                              ?.toString()
                              .trim() ??
                          '';

                  final lastName =
                      patientData['lastName']
                              ?.toString()
                              .trim() ??
                          '';

                  final displayName =
                      patientData['displayName']
                              ?.toString()
                              .trim() ??
                          '';

                  final fullName = [
                    firstName,
                    lastName,
                  ]
                      .where(
                        (
                          value,
                        ) {
                          return value.isNotEmpty;
                        },
                      )
                      .join(
                        ' ',
                      );

                  patientName =
                      fullName.isNotEmpty
                          ? fullName
                          : displayName;
                }
              } catch (
                error,
                stackTrace
              ) {
                debugPrint(
                  'No se pudo obtener el nombre del consultante: $error',
                );

                debugPrint(
                  stackTrace.toString(),
                );
              }
            }

            if (patientName.isEmpty) {
              patientName =
                  'El consultante';
            }

            if (!mounted) {
              return;
            }

            await _showPatientRequestResponseDialog(
              notificationId:
                  document.id,
              title:
                  accepted
                      ? 'Solicitud aceptada'
                      : 'Solicitud rechazada',
              message:
                  accepted
                      ? '$patientName aceptó tu solicitud de vinculación.\n\n'
                          'Ahora puedes consultar la información que el consultante haya compartido contigo.'
                      : '$patientName rechazó tu solicitud de vinculación.\n\n'
                          'Si lo deseas, puedes enviar una nueva solicitud más adelante.',
            );
          } catch (
            error,
            stackTrace
          ) {
            debugPrint(
              'Error mostrando la respuesta de la solicitud: $error',
            );

            debugPrint(
              stackTrace.toString(),
            );
          } finally {
            _patientRequestDialogVisible =
                false;
          }

          break;
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'Error escuchando respuestas de solicitudes: $error',
        );

        debugPrint(
          stackTrace.toString(),
        );
      },
    );
  }

  Future<void> _showPatientRequestResponseDialog({
    required String notificationId,
    required String title,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }

    final colors =
        context.appColors;

    await showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              colors.cardBackground,
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
                  FontWeight.w800,
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
                  1.35,
            ),
          ),
          actions: [
            Center(
              child:
                  FilledButton(
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      colors.secondaryButton,
                  foregroundColor:
                      colors.secondaryButtonText,
                  padding:
                      const EdgeInsets.symmetric(
                                            horizontal:
                        30,
                    vertical:
                        12,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                  ),
                ),
                onPressed:
                    () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },
                child:
                    const Text(
                  'Aceptar',
                  style:
                      TextStyle(
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

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .set(
        {
          'read': true,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error marcando respuesta de solicitud como leída: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // RESOLVER COPIAS INTERNAS DE UNA EMERGENCIA
  // ============================================================

  Future<void> _resolveInternalEmergencyNotifications(
    String emergencyId,
  ) async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    final firestore =
        FirebaseFirestore.instance;

    final collection =
        firestore
            .collection('users')
            .doc(uid)
            .collection('notifications');

    final documents =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      final byEmergencyKey =
          await collection
              .where(
                'emergencyKey',
                isEqualTo: emergencyId,
              )
              .get();

      for (final document in byEmergencyKey.docs) {
        documents[document.id] =
            document;
      }
    } catch (error) {
      debugPrint(
        'No se encontraron copias por emergencyKey: $error',
      );
    }

    try {
      final byEmergencyId =
          await collection
              .where(
                'emergencyId',
                isEqualTo: emergencyId,
              )
              .get();

      for (final document in byEmergencyId.docs) {
        documents[document.id] =
            document;
      }
    } catch (error) {
      debugPrint(
        'No se encontraron copias por emergencyId: $error',
      );
    }

    /*
     * Busca documentos antiguos que no tengan emergencyKey,
     * pero cuyo payload contenga el ID real de la emergencia.
     */
    try {
      final allNotifications =
          await collection.get();

      for (final document in allNotifications.docs) {
        final data =
            document.data();

        final type =
            data['type']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';

        final payload =
            data['payload']
                    ?.toString()
                    .trim() ??
                '';

        final isEmergency =
            type == 'emergency' ||
            type == 'emergencia' ||
            type == 'emergency_alert' ||
            type == 'panic' ||
            type == 'panic_alert';

        final matchesPayload =
            payload == 'emergency/$emergencyId' ||
            payload == 'emergencia/$emergencyId';

        if (isEmergency &&
            matchesPayload) {
          documents[document.id] =
              document;
        }
      }
    } catch (error) {
      debugPrint(
        'Error buscando copias antiguas de emergencia: $error',
      );
    }

    if (documents.isEmpty) {
      return;
    }

    final batch =
        firestore.batch();

    for (final document in documents.values) {
      batch.set(
        document.reference,
        {
          'read': true,
          'deleted': true,
          'completed': true,
          'active': false,
          'resolved': true,
          'resolvedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );
    }

    await batch.commit();
  }

  // ============================================================
  // RESOLVER EMERGENCIA
  // ============================================================

  Future<void> _resolveEmergency(
    String documentId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(documentId)
          .set(
        {
          'active': false,
          'read': true,
          'resolved': true,
          'resolvedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      /*
       * Cancela solamente la notificación local asociada
       * a esta emergencia.
       */
      await NotificationsService.closeEmergencyAlert(
        emergencyKey: documentId,
      );

      await _resolveInternalEmergencyNotifications(
        documentId,
      );

      _processedEmergencyIds.add(
        documentId,
      );

      debugPrint(
        'Emergencia resuelta correctamente: $documentId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error resolviendo emergencia: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // ESCUCHAR EMERGENCIAS DEL CUIDADOR
  // ============================================================

  void _listenForEmergencyAlerts() {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return;
    }

    _emergencySubscription?.cancel();

    final Query<Map<String, dynamic>> emergenciesQuery =
        FirebaseFirestore.instance
            .collection('emergencies')
            .where(
              'caregiverId',
              isEqualTo: uid,
            )
            .where(
              'active',
              isEqualTo: true,
            )
            .orderBy(
              'timestamp',
              descending: true,
            );

    _emergencySubscription =
        emergenciesQuery.snapshots().listen(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) async {
        if (snapshot.docs.isEmpty) {
          return;
        }

        final changes =
            snapshot.docChanges.where(
          (
            DocumentChange<Map<String, dynamic>> change,
          ) {
            return change.type ==
                    DocumentChangeType.added ||
                change.type ==
                    DocumentChangeType.modified;
          },
        );

        for (final change in changes) {
          final DocumentSnapshot<Map<String, dynamic>> document =
              change.doc;

          final Map<String, dynamic>? rawData =
              document.data();

          if (rawData == null) {
            continue;
          }

          final Map<String, dynamic> data =
              rawData;

          final String alertId =
              document.id;

          final bool active =
              data['active'] == true;

          final bool read =
              data['read'] == true;

          final bool deleted =
              data['deleted'] == true;

          final bool resolved =
              data['resolved'] == true;

          if (!active ||
              read ||
              deleted ||
              resolved) {
            continue;
          }

          if (_processedEmergencyIds.contains(
            alertId,
          )) {
            continue;
          }

          /*
           * Se agrega antes de mostrar la alerta para evitar
           * que el mismo documento vuelva a procesarse.
           */
          _processedEmergencyIds.add(
            alertId,
          );

          final String consultantId =
              data['consultantId']
                      ?.toString()
                      .trim() ??
                  '';

          final String rawConsultantName =
              data['consultantName']
                      ?.toString()
                      .trim() ??
                  '';

          final String consultantName =
              rawConsultantName.isNotEmpty
                  ? rawConsultantName
                  : 'Consultante';

          final dynamic lat =
              data['lat'] ??
                  data['latitude'];

          final dynamic lng =
              data['lng'] ??
                  data['longitude'];

          final String rawTitle =
              data['title']
                      ?.toString()
                      .trim() ??
                  '';

          final String title =
              rawTitle.isNotEmpty
                  ? rawTitle
                  : 'Emergencia detectada';

          final String rawBody =
              data['body']
                      ?.toString()
                      .trim() ??
                  '';

          final String body =
              rawBody.isNotEmpty
                  ? rawBody
                  : '$consultantName necesita ayuda.';

          debugPrint(
            'Emergencia nueva recibida: $alertId',
          );

          if (!kIsWeb) {
            /*
             * La emergencia ya está guardada en Firestore.
             * No se vuelve a guardar para evitar el ciclo de
             * notificaciones.
             */
            unawaited(
              NotificationsService.showEmergencyAlert(
                title: title,
                body: body,
                emergencyKey: alertId,
                saveInFirestore: false,
              ),
            );

            unawaited(
              Vibration.vibrate(
                duration: 1500,
                amplitude: 255,
              ),
            );
          }

          if (!mounted) {
            return;
          }

          /*
           * Evita colocar varios diálogos uno encima de otro.
           */
          if (_emergencyDialogVisible) {
            continue;
          }
                    _emergencyDialogVisible =
              true;

          try {
            await _showEmergencyDialog(
              alertId: alertId,
              consultantId: consultantId,
              consultantName: consultantName,
              body: body,
              lat: lat,
              lng: lng,
            );
          } catch (error, stackTrace) {
            debugPrint(
              'Error mostrando la emergencia: $error',
            );

            debugPrint(
              stackTrace.toString(),
            );
          } finally {
            _emergencyDialogVisible =
                false;
          }
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'Error escuchando emergencias: $error',
        );

        debugPrint(
          stackTrace.toString(),
        );
      },
    );
  }

  // ============================================================
  // MOSTRAR DIÁLOGO DE EMERGENCIA
  // ============================================================

  Future<void> _showEmergencyDialog({
    required String alertId,
    required String consultantId,
    required String consultantName,
    required String body,
    required dynamic lat,
    required dynamic lng,
  }) async {
    if (!mounted) {
      return;
    }

    final colors =
        context.appColors;

    final dialogBgTop =
        context.isDark
            ? const Color(0xFF3B2024)
            : const Color(0xFFFFDDDD);

    final dialogBgBottom =
        context.isDark
            ? const Color(0xFF24161A)
            : const Color(0xFFFFF1F1);

    final shadowColor =
        context.isDark
            ? Colors.black.withValues(
                alpha: 0.45,
              )
            : Colors.black.withValues(
                alpha: 0.20,
              );

    final dangerAccent =
        context.isDark
            ? const Color(0xFFFF8E8E)
            : Colors.red;

    bool resolving =
        false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return PopScope(
              canPop:
                  false,
              child: Dialog(
                backgroundColor:
                    Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: Container(
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    gradient:
                        LinearGradient(
                      colors: [
                        dialogBgTop,
                        dialogBgBottom,
                      ],
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            shadowColor,
                        blurRadius:
                            22,
                        offset:
                            const Offset(
                          0,
                          8,
                        ),
                      ),
                    ],
                    border:
                        Border.all(
                      color:
                          context.isDark
                              ? const Color(
                                  0xFF6B2B33,
                                )
                              : const Color(
                                  0xFFFFC2C2,
                                ),
                    ),
                  ),
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    22,
                    20,
                    18,
                  ),
                  child:
                      SingleChildScrollView(
                    child:
                        Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.all(
                                10,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    dangerAccent.withValues(
                                  alpha:
                                      0.18,
                                ),
                                shape:
                                    BoxShape.circle,
                              ),
                              child:
                                  Icon(
                                Icons.warning_rounded,
                                color:
                                    dangerAccent,
                                size:
                                    32,
                              ),
                            ),
                            const SizedBox(
                              width:
                                  12,
                            ),
                            Expanded(
                              child:
                                  Text(
                                'Emergencia de $consultantName',
                                style:
                                    TextStyle(
                                  fontSize:
                                      20,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      colors.textPrimary,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height:
                              14,
                        ),

                        Text(
                          body,
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                colors.textPrimary,
                            fontSize:
                                16,
                            height:
                                1.3,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),

                        const SizedBox(
                          height:
                              18,
                        ),

                        if (lat != null &&
                            lng != null)
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                            child:
                                SizedBox(
                              width:
                                  double.infinity,
                              height:
                                  240,
                              child:
                                  EmergencyMapPage(
                                consultantId:
                                    consultantId,
                                lat:
                                    lat,
                                lng:
                                    lng,
                                isDialog:
                                    true,
                              ),
                            ),
                          )
                        else
                          Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets.all(
                              20,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  colors.cardBackground.withValues(
                                alpha:
                                    0.65,
                              ),
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
                            child:
                                Column(
                              children: [
                                Icon(
                                  Icons.location_off_rounded,
                                  size:
                                      42,
                                  color:
                                      colors.textSecondary,
                                ),
                                const SizedBox(
                                  height:
                                      10,
                                ),
                                Text(
                                  'La ubicación no está disponible.',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      TextStyle(
                                    color:
                                        colors.textPrimary,
                                    fontSize:
                                        15,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(
                          height:
                              20,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height:
                              48,
                          child:
                              ElevatedButton.icon(
                            icon:
                                resolving
                                    ? const SizedBox(
                                        width:
                                            20,
                                        height:
                                            20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.navigation_rounded,
                                        color:
                                            Colors.white,
                                      ),
                            label:
                                Text(
                              resolving
                                  ? 'Procesando...'
                                  : 'Abrir en Google Maps',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                                fontSize:
                                    16,
                                color:
                                    Colors.white,
                              ),
                            ),
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor:
                                  context.isDark
                                      ? const Color(
                                          0xFFC35B5B,
                                        )
                                      : Colors.redAccent,
                              disabledBackgroundColor:
                                  context.isDark
                                      ? const Color(
                                          0xFF7D4444,
                                        )
                                      : Colors.redAccent.withValues(
                                          alpha:
                                              0.55,
                                        ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                              elevation:
                                  4,
                            ),
                            onPressed:
                                resolving
                                    ? null
                                    : () async {
                                        if (lat == null ||
                                            lng == null) {
                                          await _showHomeMessageDialog(
                                            dialogContext,
                                            title:
                                                'Ubicación no disponible',
                                            message:
                                                'La alerta no contiene coordenadas válidas.',
                                          );

                                          return;
                                        }

                                        setDialogState(
                                          () {
                                            resolving =
                                                true;
                                          },
                                        );

                                        try {
                                          final uri =
                                              Uri.parse(
                                            'https://www.google.com/maps?q=$lat,$lng',
                                          );

                                          final canOpen =
                                              await canLaunchUrl(
                                            uri,
                                          );

                                          if (canOpen) {
                                            await launchUrl(
                                              uri,
                                              mode:
                                                  LaunchMode.externalApplication,
                                            );
                                          } else if (dialogContext.mounted) {
                                            await _showHomeMessageDialog(
                                              dialogContext,
                                              title:
                                                  'No se pudo abrir el mapa',
                                              message:
                                                  'No se encontró una aplicación compatible para abrir la ubicación.',
                                            );
                                          }

                                          await _resolveEmergency(
                                            alertId,
                                          );

                                          if (dialogContext.mounted) {
                                            Navigator.of(
                                              dialogContext,
                                            ).pop();
                                          }
                                        } catch (
                                          error,
                                          stackTrace
                                        ) {
                                          debugPrint(
                                            'Error abriendo Google Maps: $error',
                                          );

                                          debugPrint(
                                            stackTrace.toString(),
                                          );

                                          if (dialogContext.mounted) {
                                            setDialogState(
                                              () {
                                                resolving =
                                                    false;
                                              },
                                            );

                                            await _showHomeMessageDialog(
                                              dialogContext,
                                              title:
                                                  'Error',
                                              message:
                                                  'No se pudo abrir la ubicación de la emergencia.',
                                            );
                                          }
                                        }
                                      },
                          ),
                        ),
                                                const SizedBox(
                          height:
                              12,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height:
                              46,
                          child:
                              OutlinedButton.icon(
                            icon:
                                resolving
                                    ? const SizedBox(
                                        width:
                                            18,
                                        height:
                                            18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                        ),
                                      )
                                    : Icon(
                                        Icons.check_circle_outline_rounded,
                                        color:
                                            colors.textPrimary,
                                      ),
                            label:
                                Text(
                              resolving
                                  ? 'Procesando...'
                                  : 'Cerrar emergencia',
                              style:
                                  TextStyle(
                                color:
                                    colors.textPrimary,
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            style:
                                OutlinedButton.styleFrom(
                              side:
                                  BorderSide(
                                color:
                                    colors.border,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  14,
                                ),
                              ),
                            ),
                            onPressed:
                                resolving
                                    ? null
                                    : () async {
                                        setDialogState(
                                          () {
                                            resolving =
                                                true;
                                          },
                                        );

                                        try {
                                          await _resolveEmergency(
                                            alertId,
                                          );

                                          if (dialogContext.mounted) {
                                            Navigator.of(
                                              dialogContext,
                                            ).pop();
                                          }
                                        } catch (
                                          error,
                                          stackTrace
                                        ) {
                                          debugPrint(
                                            'Error cerrando emergencia: $error',
                                          );

                                          debugPrint(
                                            stackTrace.toString(),
                                          );

                                          if (dialogContext.mounted) {
                                            setDialogState(
                                              () {
                                                resolving =
                                                    false;
                                              },
                                            );

                                            await _showHomeMessageDialog(
                                              dialogContext,
                                              title:
                                                  'Error',
                                              message:
                                                  'No se pudo cerrar la emergencia.',
                                            );
                                          }
                                        }
                                      },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // DIÁLOGO INFORMATIVO DEL HOME
  // ============================================================

  Future<void> _showHomeMessageDialog(
    BuildContext dialogContext, {
    required String title,
    required String message,
  }) async {
    if (!dialogContext.mounted) {
      return;
    }

    await showDialog<void>(
      context:
          dialogContext,
      builder:
          (
        messageContext,
      ) {
        final colors =
            messageContext.appColors;

        return AlertDialog(
          backgroundColor:
              colors.cardBackground,
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
                  FontWeight.w800,
            ),
          ),
          content:
              Text(
            message,
            style:
                TextStyle(
              color:
                  colors.textSecondary,
              fontSize:
                  15,
              height:
                  1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.of(
                  messageContext,
                ).pop();
              },
              child:
                  Text(
                'Aceptar',
                style:
                    TextStyle(
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
  }

  // ============================================================
  // INTERFAZ PRINCIPAL
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    final currentUser =
        FirebaseAuth.instance.currentUser;

    final uid =
        currentUser?.uid;

    return Scaffold(
      backgroundColor:
          colors.pageBackground,
      body:
          Stack(
        children: [
          SafeArea(
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                72,
                20,
                20,
              ),
              child:
                  Center(
                child:
                    ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth:
                        420,
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      StreamBuilder<User?>(
                        stream:
                            FirebaseAuth.instance.userChanges(),
                        builder:
                            (
                          context,
                          authSnapshot,
                        ) {
                          final user =
                              authSnapshot.data ??
                                  FirebaseAuth.instance.currentUser;

                          if (user == null) {
                            return const SizedBox.shrink();
                          }

                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection(
                                      'users',
                                    )
                                    .doc(
                                      user.uid,
                                    )
                                    .snapshots(),
                            builder:
                                (
                              context,
                              userSnapshot,
                            ) {
                              String name =
                                  'Cuidador';

                              final userData =
                                  userSnapshot.data?.data();

                              if (userData != null) {
                                final firstName =
                                    userData['firstName']
                                            ?.toString()
                                            .trim() ??
                                        '';

                                final lastName =
                                    userData['lastName']
                                            ?.toString()
                                            .trim() ??
                                        '';

                                final firestoreName =
                                    [
                                  firstName,
                                  lastName,
                                ]
                                        .where(
                                          (
                                            value,
                                          ) {
                                            return value.isNotEmpty;
                                          },
                                        )
                                        .join(
                                          ' ',
                                        );

                                if (firestoreName.isNotEmpty) {
                                  name =
                                      firestoreName;
                                }
                              }

                              if (name ==
                                  'Cuidador') {
                                final displayName =
                                    user.displayName?.trim() ??
                                        '';

                                if (displayName.isNotEmpty) {
                                  name =
                                      displayName;
                                }
                              }

                              if (name ==
                                  'Cuidador') {
                                final email =
                                    user.email ??
                                        '';

                                if (email.contains(
                                  '@',
                                )) {
                                  name =
                                      email
                                          .split(
                                            '@',
                                          )
                                          .first;
                                }
                              }

                              if (name.trim().isEmpty) {
                                name =
                                    widget.displayName ??
                                        'Cuidador';
                              }

                              return Text(
                                'Bienvenido $name',
                                textAlign:
                                    TextAlign.center,
                                style:
                                    TextStyle(
                                  fontSize:
                                      28,
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      colors.textPrimary,
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            8,
                      ),

                      Text(
                        'Selecciona una opción',
                        style:
                            TextStyle(
                          color:
                              colors.textSecondary,
                        ),
                      ),

                      const SizedBox(
                        height:
                            20,
                      ),

                      _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.people_outline,
                        text:
                            'Pacientes',
                        onTap:
                            () {
                          Navigator.pushNamed(
                            context,
                            PatientsListPage.route,
                          );
                        },
                      ),

                      _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.menu_book_outlined,
                        text:
                            'Guías',
                        onTap:
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder:
                                  (_) {
                                return const QuickGuidesPage();
                              },
                            ),
                          );
                        },
                      ),

                      _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.health_and_safety_outlined,
                        text:
                            'Prevención',
                        onTap:
                            () {
                          Navigator.pushNamed(
                            context,
                            PreventiveInfoScreen.route,
                          );
                        },
                      ),
                                            _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.contact_phone_outlined,
                        text:
                            'Contactos',
                        onTap:
                            () {
                          Navigator.pushNamed(
                            context,
                            SupportContactsScreen.route,
                          );
                        },
                      ),

                      _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.event_note_outlined,
                        text:
                            'Recuerdos',
                        onTap:
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder:
                                  (_) {
                                return const CalendarPage();
                              },
                            ),
                          );
                        },
                      ),

                      _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.alarm_rounded,
                        text:
                            'Recordatorios',
                        onTap:
                            () {
                          Navigator.pushNamed(
                            context,
                            '/reminders',
                          );
                        },
                      ),

                      _PillButton(
                        color:
                            context.isDark
                                ? colors.secondaryButton
                                : kPurple,
                        icon:
                            Icons.chat_bubble_outline,
                        text:
                            'Asistente',
                        onTap:
                            () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder:
                                  (_) {
                                return const AssistantPage();
                              },
                            ),
                          );
                        },
                      ),

                      _PillButton(
                        color:
                            colors.emergency,
                        icon:
                            Icons.emergency_share_rounded,
                        text:
                            'Pánico',
                        onTap:
                            () {
                          Navigator.pushNamed(
                            context,
                            PanicButtonPage.route,
                          );
                        },
                      ),

                      const SizedBox(
                        height:
                            24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child:
                Align(
              alignment:
                  Alignment.topLeft,
              child:
                  Padding(
                padding:
                    const EdgeInsets.only(
                  left:
                      8,
                  top:
                      4,
                ),
                child:
                    IconButton(
                  icon:
                      Icon(
                    Icons.settings,
                    color:
                        colors.textPrimary,
                    size:
                        28,
                  ),
                  onPressed:
                      () {
                    Navigator.pushNamed(
                      context,
                      '/settings',
                    );
                  },
                  tooltip:
                      'Ajustes',
                ),
              ),
            ),
          ),

          SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 8,
                top: 4,
              ),
              child: uid == null
                  ? _NotificationBell(
                      count: 0,
                      loading: false,
                      onTap: _openNotifications,
                    )
                  : StreamBuilder<int>(
                      stream: NotificationsService.watchUnreadNotificationsCountForCurrentUser(),
                      builder: (context, snapshot) {
                        final loading =
                            snapshot.connectionState == ConnectionState.waiting &&
                                !snapshot.hasData;

                        final count = snapshot.data ?? 0;

                        return _NotificationBell(
                          count: count,
                          loading: loading,
                          onTap: _openNotifications,
                        );
                      },
                    ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emergencySubscription?.cancel();
    _patientRequestResponseSubscription?.cancel();

    super.dispose();
  }
}

// ============================================================
// CAMPANA DE NOTIFICACIONES
// ============================================================

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.count,
    required this.onTap,
    this.loading = false,
  });

  final int count;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    final showBadge =
        count > 0;

    final display =
        count > 99
            ? '99+'
            : count.toString();

    return Stack(
      clipBehavior:
          Clip.none,
      children: [
        IconButton(
          onPressed:
              loading
                  ? null
                  : onTap,
          icon:
              Icon(
            showBadge
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color:
                colors.textPrimary,
            size:
                28,
          ),
          tooltip:
              showBadge
                  ? '$count notificaciones no leídas'
                  : 'Notificaciones',
        ),

        if (loading)
          Positioned(
            right:
                9,
            top:
                8,
            child:
                SizedBox(
              width:
                  15,
              height:
                  15,
              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2,
                color:
                    colors.primaryButton,
              ),
            ),
          ),

        if (!loading &&
            showBadge)
          Positioned(
            right:
                3,
            top:
                3,
            child:
                Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    6,
                vertical:
                    2,
              ),
              decoration:
                  BoxDecoration(
                color:
                    context.isDark
                        ? const Color(
                            0xFFC35B5B,
                          )
                        : Colors.red,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                border:
                    Border.all(
                  color:
                      colors.pageBackground,
                  width:
                      1.5,
                ),
              ),
              constraints:
                  const BoxConstraints(
                minWidth:
                    20,
                minHeight:
                    18,
              ),
              alignment:
                  Alignment.center,
              child:
                  Text(
                display,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// BOTÓN DEL MENÚ PRINCIPAL
// ============================================================

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.color,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    final buttonTextColor =
        context.isDark
            ? Colors.white
            : colors.textPrimary;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            8,
      ),
      child:
          SizedBox(
        width:
            double.infinity,
        height:
            56,
        child:
            FilledButton(
          style:
              FilledButton.styleFrom(
            backgroundColor:
                color,
            foregroundColor:
                buttonTextColor,
            shape:
                const StadiumBorder(),
            elevation:
                0,
          ),
          onPressed:
              onTap,
          child:
              Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size:
                    24,
                color:
                    buttonTextColor,
              ),

              const SizedBox(
                width:
                    12,
              ),

              Flexible(
                child:
                    Text(
                  text,
                  textAlign:
                      TextAlign.center,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        buttonTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}