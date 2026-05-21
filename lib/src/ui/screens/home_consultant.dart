import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

// Estilos y componentes
import '../theme.dart';
import '../user_avatar.dart';

// Vistas
import 'tips_page.dart';
import 'calendar_page.dart';
import 'game_page.dart' as games;
import 'motivational_phrases_page.dart';
import 'notifications_page.dart';
import 'assistant_page.dart';

// Servicios
import 'package:whoami_app/services/memories_scheduler.dart';
import 'package:whoami_app/services/notifications_service.dart';

/// =============================================================
/// HomeConsultantPage (Consultante) — FINAL con emergencias agrupadas
/// =============================================================
class HomeConsultantPage extends StatefulWidget {
  const HomeConsultantPage({super.key, this.displayName});
  static const route = '/home/consultant';
  final String? displayName;

  @override
  State<HomeConsultantPage> createState() => _HomeConsultantPageState();
}

class _HomeConsultantPageState extends State<HomeConsultantPage> {
  int _notifCount = 0;
  bool _loadingNotif = true;
  bool _hasCaregiver = false;

  @override
  void initState() {
    super.initState();
    _initializeHome();
  }

  /// =============================================================
  /// Inicialización de servicios
  /// =============================================================
  Future<void> _initializeHome() async {
    await NotificationsService.ensureInitialized();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await MemoriesScheduler.scheduleAllForUser(uid);
      await _checkCaregiver(uid);
    }

    await _loadNotifCount();
  }

  /// ✅ Verifica si el usuario tiene un cuidador vinculado
  Future<void> _checkCaregiver(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null &&
          data['caregiverId'] != null &&
          data['caregiverId'] != '') {
        if (!mounted) return;
        setState(() => _hasCaregiver = true);
      } else {
        if (!mounted) return;
        setState(() => _hasCaregiver = false);
      }
    } catch (e) {
      debugPrint('Error comprobando cuidador: $e');
      if (!mounted) return;
      setState(() => _hasCaregiver = false);
    }
  }

  /// ✅ Obtiene cantidad de notificaciones pendientes (locales)
  Future<void> _loadNotifCount() async {
    try {
      final count = await NotificationsService.getPendingCount();
      if (!mounted) return;
      setState(() {
        _notifCount = count;
        _loadingNotif = false;
      });
    } catch (e) {
      debugPrint('Error al cargar notificaciones pendientes: $e');
      if (!mounted) return;
      setState(() => _loadingNotif = false);
    }
  }

  /// ✅ Abre la página de notificaciones
  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, NotificationsPage.route);
    await _loadNotifCount();
  }

  /// =============================================================
  /// 🚨 FUNCIÓN DE EMERGENCIA — sincronizada con cuidador
  /// =============================================================
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

      // 📍 Solicitar permisos y obtener ubicación
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
        desiredAccuracy: LocationAccuracy.high,
      );

      final name =
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim().isEmpty
              ? 'Tu consultante'
              : '${data['firstName']} ${data['lastName']}';

      // ✅ Guardar en la colección GLOBAL 'emergencies'
      final emergencyRef =
          FirebaseFirestore.instance.collection('emergencies').doc();

      await emergencyRef.set({
        'consultantId': user.uid,
        'caregiverId': caregiverId,
        'consultantName': name,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'title': '🚨 Emergencia detectada',
        'body': '$name necesita ayuda.',
        'timestamp': FieldValue.serverTimestamp(),
        'active': true,
      });

      // 🟣 Forzar actualización
      await emergencyRef.update({'triggeredAt': FieldValue.serverTimestamp()});

      // 💬 Notificación interna para el cuidador
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .collection('notifications')
          .add({
        'title': '🚨 Emergencia detectada',
        'body': '$name necesita ayuda.',
        'type': 'emergency',
        'consultantId': user.uid,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 🟢 Mostrar notificación local agrupada
      await NotificationsService.showEmergencyAlert(
        title: '🚨 Emergencia detectada',
        body: '$name necesita ayuda.',
      );

      // ✅ Confirmación visual adaptada al tema
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
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dialogBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: emergencyBorder, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: context.isDark
                        ? Colors.black.withOpacity(0.28)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
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
                    "Alerta enviada",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: onBg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Tu cuidador ha sido notificado con tu ubicación en tiempo real.\n"
                    "Mantén la calma, la ayuda está en camino.",
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
                        backgroundColor: context.isDark
                            ? colors.secondaryButton
                            : kPurple,
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
                        "Entendido",
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

  /// =============================================================
  /// UI
  /// =============================================================
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
                    // Barra superior
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/settings'),
                            icon: Icon(
                              Icons.settings,
                              color: colors.textPrimary,
                              size: 28,
                            ),
                          ),
                          _NotificationBell(
                            count: _notifCount,
                            loading: _loadingNotif,
                            onTap: _openNotifications,
                          ),
                        ],
                      ),
                    ),

                    const UserAvatar(radius: 60),
                    const SizedBox(height: 12),

                    // Nombre
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
                                  .where((e) => e.isNotEmpty)
                                  .join(' ');
                              if (fsName.isNotEmpty) name = fsName;
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

                    // Botones principales
                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.menu_book_outlined,
                      text: 'Consejos',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TipsPage()),
                      ),
                    ),
                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.auto_stories_outlined,
                      text: 'Frases',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MotivationalPhrasesPage(),
                        ),
                      ),
                    ),
                    _PillButton(
                      color: context.isDark
                          ? colors.primaryButton
                          : kBlue,
                      icon: Icons.event_note_outlined,
                      text: 'Recuerdos',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CalendarPage()),
                      ),
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
                            builder: (_) => const games.GamesPage(),
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssistantPage(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// 🚨 BOTÓN DE EMERGENCIA
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.isDark
                    ? const Color(0xFFC35B5B)
                    : Colors.red,
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
    final buttonTextColor = context.isDark
        ? Colors.white
        : colors.textPrimary;

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