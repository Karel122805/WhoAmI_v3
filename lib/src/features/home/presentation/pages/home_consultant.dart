import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/core/widgets/user_avatar.dart';

import 'package:whoami_app/src/features/tips/presentation/pages/tips_page.dart';
import 'package:whoami_app/src/features/memories/presentation/pages/calendar_page.dart';
import 'package:whoami_app/src/features/games/presentation/pages/game_page.dart'
    as games;
import 'package:whoami_app/src/features/phrases/presentation/pages/motivational_phrases_page.dart';
import 'package:whoami_app/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:whoami_app/src/features/assistant/presentation/pages/assistant_page.dart';

import 'package:whoami_app/src/features/memories/data/memories_scheduler.dart';
import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';

class HomeConsultantPage extends StatefulWidget {
  const HomeConsultantPage({super.key, this.displayName});

  static const route = '/home/consultant';

  final String? displayName;

  @override
  State<HomeConsultantPage> createState() => _HomeConsultantPageState();
}

class _HomeConsultantPageState extends State<HomeConsultantPage> {
  bool _hasCaregiver = false;

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  Future<void> _initializeHome() async {
    await NotificationsService.ensureInitialized();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      await MemoriesScheduler.scheduleAllForUser(uid);
      await _checkCaregiver(uid);
    }
  }

  Future<void> _checkCaregiver(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = doc.data();

      if (!mounted) return;

      setState(() {
        _hasCaregiver = data != null &&
            data['caregiverId'] != null &&
            data['caregiverId'] != '';
      });
    } catch (e) {
      debugPrint('Error comprobando cuidador: $e');

      if (!mounted) return;

      setState(() => _hasCaregiver = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, NotificationsPage.route);
  }

  Future<void> _sendEmergencyAlert() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};
      final caregiverId = data['caregiverId'];

      if (caregiverId == null || caregiverId.isEmpty) {
        if (!mounted) return;

        setState(() => _hasCaregiver = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Permiso de ubicación denegado.');
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final fullName =
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();

      final name = fullName.isEmpty ? 'Tu consultante' : fullName;

      final emergencyRef =
          FirebaseFirestore.instance.collection('emergencies').doc();

      await emergencyRef.set({
        'consultantId': user.uid,
        'caregiverId': caregiverId,
        'consultantName': name,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'title': 'Emergencia detectada',
        'body': '$name necesita ayuda.',
        'timestamp': FieldValue.serverTimestamp(),
        'active': true,
      });

      await emergencyRef.update({
        'triggeredAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .collection('notifications')
          .add({
        'title': 'Emergencia detectada',
        'body': '$name necesita ayuda.',
        'type': 'emergency',
        'consultantId': user.uid,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await NotificationsService.showEmergencyAlert(
        title: 'Emergencia detectada',
        body: '$name necesita ayuda.',
      );

      if (!mounted) return;

      final colors = context.appColors;
      final dialogBg = colors.elevatedCard;
      final onBg = colors.textPrimary;
      final onBgMuted = colors.textSecondary;

      final emergencyBorder =
          context.isDark ? const Color(0xFFD4767B) : const Color(0xFFFF9FA1);

      final emergencyFill =
          context.isDark ? const Color(0xFF4B2A30) : const Color(0xFFFFE0E2);

      final emergencyIcon =
          context.isDark ? const Color(0xFFFFA6AC) : const Color(0xFFFF7E86);

      showDialog(
        context: context,
        builder: (_) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: emergencyBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: context.isDark
                        ? Colors.black.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: emergencyFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: emergencyIcon,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Alerta enviada',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: onBg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu cuidador ha sido notificado con tu ubicación en tiempo real.\n'
                    'Mantén la calma, la ayuda está en camino.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      color: onBgMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            context.isDark ? colors.secondaryButton : kPurple,
                        foregroundColor: context.isDark
                            ? colors.secondaryButtonText
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Entendido',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
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
    } catch (e) {
      debugPrint('Error al enviar emergencia: $e');

      if (!mounted) return;

      final colors = context.appColors;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: colors.elevatedCard,
          title: Text(
            'Error',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: Text(
            'Ocurrió un error al enviar la alerta:\n$e',
            style: TextStyle(color: colors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cerrar',
                style: TextStyle(color: colors.primaryButton),
              ),
            ),
          ],
        ),
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/settings');
                            },
                            icon: Icon(
                              Icons.settings,
                              color: colors.textPrimary,
                              size: 28,
                            ),
                          ),
                          StreamBuilder<int>(
                            stream: NotificationsService
                                .watchUnreadAppNotificationCount(),
                            builder: (context, snapshot) {
                              final loading =
                                  snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData;

                              final count = snapshot.data ?? 0;

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
                    const UserAvatar(radius: 60),
                    const SizedBox(height: 12),
                    StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.userChanges(),
                      builder: (context, authSnap) {
                        final user =
                            authSnap.data ?? FirebaseAuth.instance.currentUser;

                        if (user == null) return const SizedBox();

                        final uid = user.uid;

                        return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, docSnap) {
                            String name = 'Usuario';

                            if (docSnap.hasData &&
                                docSnap.data!.data() != null) {
                              final data = docSnap.data!.data()!;

                              final first =
                                  (data['firstName'] as String?)?.trim() ?? '';

                              final last =
                                  (data['lastName'] as String?)?.trim() ?? '';

                              final fsName = [first, last]
                                  .where((item) => item.isNotEmpty)
                                  .join(' ');

                              if (fsName.isNotEmpty) {
                                name = fsName;
                              }
                            }

                            return Text(
                              'Bienvenido $name',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona una opción',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    _PillButton(
                      color: context.isDark ? colors.primaryButton : kBlue,
                      icon: Icons.menu_book_outlined,
                      text: 'Consejos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TipsPage(),
                          ),
                        );
                      },
                    ),
                    _PillButton(
                      color: context.isDark ? colors.primaryButton : kBlue,
                      icon: Icons.auto_stories_outlined,
                      text: 'Frases',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MotivationalPhrasesPage(),
                          ),
                        );
                      },
                    ),
                    _PillButton(
                      color: context.isDark ? colors.primaryButton : kBlue,
                      icon: Icons.event_note_outlined,
                      text: 'Recuerdos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalendarPage(),
                          ),
                        );
                      },
                    ),
                    _PillButton(
                      color: context.isDark ? colors.primaryButton : kBlue,
                      icon: Icons.alarm_rounded,
                      text: 'Recordatorios',
                      onTap: () {
                        Navigator.pushNamed(context, '/reminders');
                      },
                    ),
                    _PillButton(
                      color: context.isDark ? colors.primaryButton : kBlue,
                      icon: Icons.videogame_asset_outlined,
                      text: 'Juegos',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const games.GamesPage(),
                          ),
                        );
                      },
                    ),
                    _PillButton(
                      color: context.isDark ? colors.primaryButton : kBlue,
                      icon: Icons.chat_bubble_outline,
                      text: 'Asistente',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssistantPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _hasCaregiver ? 1 : 0.5,
                      child: AbsorbPointer(
                        absorbing: !_hasCaregiver,
                        child: _PillButton(
                          color: context.isDark
                              ? colors.emergency
                              : const Color(0xFFFF9AA0),
                          icon: Icons.warning_amber_rounded,
                          text: _hasCaregiver
                              ? 'Emergencia'
                              : 'Emergencia (sin cuidador)',
                          onTap: _sendEmergencyAlert,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
    final colors = context.appColors;

    final showBadge = count > 0;
    final display = count > 99 ? '99+' : count.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: loading ? null : onTap,
          icon: Icon(
            Icons.notifications_none_rounded,
            color: colors.textPrimary,
            size: 28,
          ),
        ),
        if (loading)
          Positioned(
            right: 10,
            top: 10,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primaryButton,
              ),
            ),
          ),
        if (!loading && showBadge)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFFC35B5B) : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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
    final colors = context.appColors;
    final buttonTextColor = context.isDark ? Colors.white : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: buttonTextColor,
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: buttonTextColor),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: buttonTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}