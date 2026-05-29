import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/core/widgets/user_avatar.dart';
import 'package:whoami_app/src/features/tips/presentation/pages/quick_guides_page.dart';
import 'package:whoami_app/src/features/patients/presentation/pages/patients_list_page.dart';
import 'package:whoami_app/src/features/memories/presentation/pages/calendar_page.dart';
import 'package:whoami_app/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:whoami_app/src/features/emergency/presentation/pages/emergency_map_page.dart';
import 'package:whoami_app/src/features/assistant/presentation/pages/assistant_page.dart';
import 'package:whoami_app/src/features/support_contacts/presentation/support_contacts_screen.dart';

import 'package:whoami_app/src/features/memories/data/memories_scheduler.dart';
import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';

class HomeCaregiverPage extends StatefulWidget {
  const HomeCaregiverPage({super.key, this.displayName});
  static const route = '/home/caregiver';
  final String? displayName;

  @override
  State<HomeCaregiverPage> createState() => _HomeCaregiverPageState();
}

class _HomeCaregiverPageState extends State<HomeCaregiverPage> {
  int _notifCount = 0;
  bool _loadingNotif = true;
  String? _lastAlertId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeHome();
      _listenForEmergencyAlerts();
    });
  }

  Future<void> _initializeHome() async {
    try {
      await NotificationsService.ensureInitialized();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await MemoriesScheduler.scheduleAllForUser(uid);
      }
      await _loadNotifCount();
    } catch (e) {
      debugPrint('Error en inicialización del HomeCaregiver: $e');
    }
  }

  Future<void> _resolveEmergency(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(docId)
          .update({'active': false});

      final pending = await NotificationsService.pendingNotificationRequests();
      for (final item in pending) {
        if (item.payload == 'emergency') {
          await NotificationsService.cancel(item.id);
        }
      }

      await _loadNotifCount();
    } catch (e) {
      debugPrint('Error resolviendo emergencia: $e');
    }
  }

  void _listenForEmergencyAlerts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final emergenciesRef = FirebaseFirestore.instance
        .collection('emergencies')
        .where('caregiverId', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .orderBy('timestamp', descending: true);

    emergenciesRef.snapshots(includeMetadataChanges: true).listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      for (final doc in snapshot.docs) {
        final alertId = doc.id;

        if (_lastAlertId == alertId) continue;
        _lastAlertId = alertId;

        final data = doc.data();
        final consultantId = data['consultantId'] ?? '';
        final consultantName = data['consultantName'] ?? 'Consultante';
        final lat = data['lat'];
        final lng = data['lng'];
        final title = data['title'] ?? 'Emergencia detectada';
        final body = data['body'] ?? '$consultantName necesita ayuda.';

        if (lat == null || lng == null) continue;

        debugPrint('Emergencia recibida en tiempo real para cuidador $uid');

        if (!kIsWeb) {
          NotificationsService.showInstant(title: title, body: body);
          Vibration.vibrate(duration: 1500, amplitude: 255);
        }

        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final colors = context.appColors;

          final dialogBgTop = context.isDark
              ? const Color(0xFF3B2024)
              : const Color(0xFFFFDDDD);
          final dialogBgBottom = context.isDark
              ? const Color(0xFF24161A)
              : const Color(0xFFFFF1F1);
          final shadowColor = context.isDark
              ? Colors.black.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.20);
          final dangerAccent =
              context.isDark ? const Color(0xFFFF8E8E) : Colors.red;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [dialogBgTop, dialogBgBottom],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: context.isDark
                        ? const Color(0xFF6B2B33)
                        : const Color(0xFFFFC2C2),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: dangerAccent.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning_rounded,
                            color: dangerAccent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Emergencia de $consultantName',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 240,
                        child: EmergencyMapPage(
                          consultantId: consultantId,
                          lat: lat,
                          lng: lng,
                          isDialog: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Abrir en Google Maps',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.isDark
                              ? const Color(0xFFC35B5B)
                              : Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () async {
                          final url = 'https://www.google.com/maps?q=$lat,$lng';
                          final uri = Uri.parse(url);

                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }

                          if (context.mounted) Navigator.pop(context);
                          await _resolveEmergency(alertId);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _resolveEmergency(alertId);
                      },
                      child: Text(
                        'Cerrar',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }
    }, onError: (error) {
      debugPrint('Error escuchando emergencias: $error');
    });
  }

  Future<void> _loadNotifCount() async {
    try {
      final pending =
          await NotificationsService.plugin.pendingNotificationRequests();
      if (!mounted) return;
      setState(() {
        _notifCount = pending.length;
        _loadingNotif = false;
      });
    } catch (e) {
      debugPrint('Error al cargar notificaciones pendientes: $e');
      if (!mounted) return;
      setState(() => _loadingNotif = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, NotificationsPage.route);
    await _loadNotifCount();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                              String name = 'Cuidador';

                              if (docSnap.hasData &&
                                  docSnap.data!.data() != null) {
                                final data = docSnap.data!.data()!;
                                final first =
                                    (data['firstName'] as String?)?.trim() ?? '';
                                final last =
                                    (data['lastName'] as String?)?.trim() ?? '';
                                final fsName = [first, last]
                                    .where((e) => e.isNotEmpty)
                                    .join(' ');
                                if (fsName.isNotEmpty) name = fsName;
                              }

                              if (name == 'Cuidador') {
                                final dn = (user.displayName ?? '').trim();
                                if (dn.isNotEmpty) name = dn;
                              }

                              if (name == 'Cuidador') {
                                final mail = user.email ?? '';
                                if (mail.contains('@')) {
                                  name = mail.split('@').first;
                                }
                              }

                              name = name.isNotEmpty
                                  ? name
                                  : (widget.displayName ?? 'Cuidador');

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
                        style: TextStyle(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PillButton(
                        color:
                            context.isDark ? colors.secondaryButton : kPurple,
                        icon: Icons.people_outline,
                        text: 'Pacientes',
                        onTap: () => Navigator.pushNamed(
                          context,
                          PatientsListPage.route,
                        ),
                      ),
                      _PillButton(
                        color:
                            context.isDark ? colors.secondaryButton : kPurple,
                        icon: Icons.menu_book_outlined,
                        text: 'Guías',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QuickGuidesPage(),
                          ),
                        ),
                      ),
                      _PillButton(
                        color:
                            context.isDark ? colors.secondaryButton : kPurple,
                        icon: Icons.recommend_outlined,
                        text: 'Recomendaciones',
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/recommendations',
                        ),
                      ),
                      _PillButton(
                        color:
                            context.isDark ? colors.secondaryButton : kPurple,
                        icon: Icons.contact_phone_outlined,
                        text: 'Contactos de apoyo',
                        onTap: () => Navigator.pushNamed(
                          context,
                          SupportContactsScreen.route,
                        ),
                      ),
                      _PillButton(
                        color:
                            context.isDark ? colors.secondaryButton : kPurple,
                        icon: Icons.event_note_outlined,
                        text: 'Recuerdos',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CalendarPage(),
                          ),
                        ),
                      ),
                      _PillButton(
                        color:
                            context.isDark ? colors.secondaryButton : kPurple,
                        icon: Icons.chat_bubble_outline,
                        text: 'Asistente',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AssistantPage(),
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
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: colors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  tooltip: 'Ajustes',
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: _NotificationBell(
                  count: _notifCount,
                  loading: _loadingNotif,
                  onTap: _openNotifications,
                ),
              ),
            ),
          ),
        ],
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
          tooltip: 'Notificaciones',
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFFC35B5B) : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 18),
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