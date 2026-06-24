import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

// Vistas
import 'package:whoami_app/src/features/memories/presentation/pages/calendar_page.dart';
import 'package:whoami_app/src/features/games/presentation/pages/game_page.dart'
    as games;
import 'package:whoami_app/src/features/phrases/presentation/pages/motivational_phrases_page.dart';
import 'package:whoami_app/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:whoami_app/src/features/assistant/presentation/pages/assistant_page.dart';
import 'package:whoami_app/src/features/preventive_info/presentation/preventive_info_screen.dart';

import 'package:whoami_app/src/features/memories/data/memories_scheduler.dart';
import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';

class HomeConsultantPage extends StatefulWidget {
  const HomeConsultantPage({
    super.key,
    this.displayName,
  });

  static const route = '/home/consultant';

  final String? displayName;

  @override
  State<HomeConsultantPage> createState() {
    return _HomeConsultantPageState();
  }
}

class _HomeConsultantPageState extends State<HomeConsultantPage> {
  bool _hasCaregiver = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) {
          return;
        }

        await _initializeHome();
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

        await _checkCaregiver(
          uid,
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error inicializando la pantalla del consultante: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  Future<void> _checkCaregiver(
    String uid,
  ) async {
    try {
      final document =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

      final data =
          document.data();

      final caregiverId =
          data?['caregiverId']
              ?.toString()
              .trim();

      if (!mounted) {
        return;
      }

      setState(() {
        _hasCaregiver =
            caregiverId != null &&
            caregiverId.isNotEmpty;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Error comprobando cuidador: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasCaregiver = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(
      context,
      NotificationsPage.route,
    );
  }

  Future<void> _sendEmergencyAlert() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data =
          userDocument.data() ??
              <String, dynamic>{};

      final caregiverId =
          data['caregiverId']
              ?.toString()
              .trim();

      if (caregiverId == null ||
          caregiverId.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hasCaregiver = false;
        });

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        permission =
            await Geolocator.requestPermission();

        if (permission ==
                LocationPermission.denied ||
            permission ==
                LocationPermission.deniedForever) {
          throw Exception(
            'Permiso de ubicación denegado.',
          );
        }
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final firstName =
          data['firstName']
                  ?.toString()
                  .trim() ??
              '';

      final lastName =
          data['lastName']
                  ?.toString()
                  .trim() ??
              '';

      final fullName = [
        firstName,
        lastName,
      ]
          .where(
            (value) => value.isNotEmpty,
          )
          .join(' ');

      final name =
          fullName.isEmpty
              ? 'Tu consultante'
              : fullName;

      final emergencyReference =
          FirebaseFirestore.instance
              .collection('emergencies')
              .doc();

      await emergencyReference.set({
        'consultantId': user.uid,
        'caregiverId': caregiverId,
        'consultantName': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'title': 'Emergencia detectada',
        'body': '$name necesita ayuda.',
        'timestamp':
            FieldValue.serverTimestamp(),
        'triggeredAt':
            FieldValue.serverTimestamp(),
        'active': true,
        'read': false,
        'deleted': false,
        'resolved': false,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .collection('notifications')
          .add({
        'title': 'Emergencia detectada',
        'body': '$name necesita ayuda.',
        'type': 'emergency',
        'emergencyId':
            emergencyReference.id,
        'consultantId': user.uid,
        'consultantName': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp':
            FieldValue.serverTimestamp(),
        'read': false,
        'deleted': false,
        'completed': false,
        'active': true,
      });

      await NotificationsService.showEmergencyAlert(
        title: 'Emergencia detectada',
        body: '$name necesita ayuda.',
      );

      if (!mounted) {
        return;
      }

      final colors =
          context.appColors;

      final dialogBackground =
          colors.elevatedCard;

      final textColor =
          colors.textPrimary;

      final secondaryTextColor =
          colors.textSecondary;

      final emergencyBorder =
          context.isDark
              ? const Color(0xFFD4767B)
              : const Color(0xFFFF9FA1);

      final emergencyFill =
          context.isDark
              ? const Color(0xFF4B2A30)
              : const Color(0xFFFFE0E2);

      final emergencyIcon =
          context.isDark
              ? const Color(0xFFFFA6AC)
              : const Color(0xFFFF7E86);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (
          dialogContext,
        ) {
          return Dialog(
            backgroundColor:
                Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Container(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              decoration: BoxDecoration(
                color:
                    dialogBackground,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color: emergencyBorder,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.isDark
                        ? Colors.black.withValues(
                            alpha: 0.28,
                          )
                        : Colors.black.withValues(
                            alpha: 0.08,
                          ),
                    blurRadius: 12,
                    offset:
                        const Offset(
                      0,
                      6,
                    ),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration: BoxDecoration(
                      color:
                          emergencyFill,
                      shape:
                          BoxShape.circle,
                    ),
                    child: Icon(
                      Icons
                          .warning_amber_rounded,
                      color:
                          emergencyIcon,
                      size: 48,
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Text(
                    'Alerta enviada',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          textColor,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  Text(
                    'Tu cuidador ha sido notificado con tu ubicación en tiempo real.\n'
                    'Mantén la calma, la ayuda está en camino.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color:
                          secondaryTextColor,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                  const SizedBox(
                    height: 22,
                  ),
                  SizedBox(
                    width:
                        double.infinity,
                    height: 48,
                    child: FilledButton(
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            context.isDark
                                ? colors
                                    .secondaryButton
                                : kPurple,
                        foregroundColor:
                            context.isDark
                                ? colors
                                    .secondaryButtonText
                                : Colors.black,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop();
                      },
                      child:
                          const Text(
                        'Entendido',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error al enviar emergencia: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      final colors =
          context.appColors;

      await showDialog<void>(
        context: context,
        builder: (
          dialogContext,
        ) {
          return AlertDialog(
            backgroundColor:
                colors.elevatedCard,
            title: Text(
              'Error',
              style: TextStyle(
                color:
                    colors.textPrimary,
              ),
            ),
            content: Text(
              'Ocurrió un error al enviar la alerta:\n$error',
              style: TextStyle(
                color:
                    colors.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },
                child: Text(
                  'Cerrar',
                  style: TextStyle(
                    color:
                        colors.primaryButton,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }
    @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/settings',
                              );
                            },
                            icon: Icon(
                              Icons.settings,
                              color: colors.textPrimary,
                              size: 28,
                            ),
                            tooltip: 'Ajustes',
                          ),
                          StreamBuilder<int>(
                            stream: NotificationsService
                                .watchUnreadAppNotificationCount(),
                            builder: (
                              context,
                              snapshot,
                            ) {
                              final loading =
                                  snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      !snapshot.hasData;

                              final count =
                                  snapshot.data ?? 0;

                              return _NotificationBell(
                                count: count,
                                loading: loading,
                                onTap: _openNotifications,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.userChanges(),
                      builder: (
                        context,
                        authSnapshot,
                      ) {
                        final user =
                            authSnapshot.data ??
                                FirebaseAuth.instance.currentUser;

                        if (user == null) {
                          return const SizedBox.shrink();
                        }

                        final uid =
                            user.uid;

                        return StreamBuilder<
                            DocumentSnapshot<
                                Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (
                            context,
                            documentSnapshot,
                          ) {
                            String name =
                                'Usuario';

                            final data =
                                documentSnapshot.data?.data();

                            if (data != null) {
                              final firstName =
                                  data['firstName']
                                          ?.toString()
                                          .trim() ??
                                      '';

                              final lastName =
                                  data['lastName']
                                          ?.toString()
                                          .trim() ??
                                      '';

                              final firestoreName = [
                                firstName,
                                lastName,
                              ]
                                  .where(
                                    (value) =>
                                        value.isNotEmpty,
                                  )
                                  .join(' ');

                              if (firestoreName.isNotEmpty) {
                                name =
                                    firestoreName;
                              }
                            }

                            if (name == 'Usuario') {
                              final displayName =
                                  user.displayName?.trim() ??
                                      '';

                              if (displayName.isNotEmpty) {
                                name =
                                    displayName;
                              }
                            }

                            if (name == 'Usuario') {
                              final email =
                                  user.email ?? '';

                              if (email.contains('@')) {
                                name =
                                    email.split('@').first;
                              }
                            }

                            if (name.trim().isEmpty) {
                              name =
                                  widget.displayName ??
                                      'Usuario';
                            }

                            return Text(
                              'Bienvenido $name',
                              textAlign:
                                  TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
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
                      height: 8,
                    ),

                    Text(
                      'Selecciona una opción',
                      style: TextStyle(
                        color: colors.textSecondary,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.auto_stories_outlined,
                      text: 'Frases',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MotivationalPhrasesPage(),
                          ),
                        );
                      },
                    ),

                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.health_and_safety_outlined,
                      text: 'Prevención',
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          PreventiveInfoScreen.route,
                        );
                      },
                    ),

                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.event_note_outlined,
                      text: 'Recuerdos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CalendarPage(),
                          ),
                        );
                      },
                    ),

                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.alarm_rounded,
                      text: 'Recordatorios',
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/reminders',
                        );
                      },
                    ),

                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.videogame_asset_outlined,
                      text: 'Juegos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const games.GamesPage(),
                          ),
                        );
                      },
                    ),

                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.chat_bubble_outline,
                      text: 'Asistente',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AssistantPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Opacity(
                      opacity:
                          _hasCaregiver
                              ? 1
                              : 0.5,
                      child: AbsorbPointer(
                        absorbing:
                            !_hasCaregiver,
                        child: _PillButton(
                          color: context.isDark
                              ? colors.emergency
                              : const Color(
                                  0xFFFF9AA0,
                                ),
                          icon:
                              Icons.warning_amber_rounded,
                          text: _hasCaregiver
                              ? 'Emergencia'
                              : 'Emergencia (sin cuidador)',
                          onTap:
                              _sendEmergencyAlert,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
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
          icon: Icon(
            showBadge
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color:
                colors.textPrimary,
            size: 28,
          ),
          tooltip:
              showBadge
                  ? '$count notificaciones no leídas'
                  : 'Notificaciones',
        ),

        if (loading)
          Positioned(
            right: 10,
            top: 10,
            child: SizedBox(
              width: 14,
              height: 14,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color:
                    colors.primaryButton,
              ),
            ),
          ),

        if (!loading &&
            showBadge)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration:
                  BoxDecoration(
                color: context.isDark
                    ? const Color(
                        0xFFC35B5B,
                      )
                    : Colors.red,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              constraints:
                  const BoxConstraints(
                minWidth: 20,
                minHeight: 18,
              ),
              alignment:
                  Alignment.center,
              child: Text(
                display,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 11,
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
  Widget build(BuildContext context) {
    final colors =
        context.appColors;

    final buttonTextColor =
        context.isDark
            ? Colors.white
            : colors.textPrimary;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: SizedBox(
        width:
            double.infinity,
        height: 56,
        child: FilledButton(
          style:
              FilledButton.styleFrom(
            backgroundColor:
                color,
            foregroundColor:
                buttonTextColor,
            shape:
                const StadiumBorder(),
            elevation: 0,
          ),
          onPressed:
              onTap,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color:
                    buttonTextColor,
              ),
              const SizedBox(
                width: 12,
              ),
              Flexible(
                child: Text(
                  text,
                  textAlign:
                      TextAlign.center,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    fontSize: 16,
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