// lib/src/ui/screens/notifications_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'emergency_map_page.dart';
import '../../../services/notifications_service.dart';
import '../theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  static const route = '/notifications';

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<PendingNotificationRequest> _pending = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _emergencies = [];
  final Set<int> _selectedIds = {};
  bool _loading = false;
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _resolveEmergency(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(docId)
          .update({'active': false});

      final pending = await NotificationsService.pendingNotificationRequests();
      for (final n in pending) {
        if (n.payload == 'emergency') {
          await NotificationsService.cancel(n.id);
        }
      }

      await _loadAll();
    } catch (e) {
      debugPrint('⚠️ Error al resolver emergencia: $e');
      if (!mounted) return;
      await _showOkDialog(
        context,
        title: 'Error',
        message: 'No se pudo marcar la emergencia como resuelta.',
      );
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _selectedIds.clear();
      _selectMode = false;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final list = await NotificationsService.pendingNotificationRequests();
      list.sort((a, b) => a.id.compareTo(b.id));

      List<QueryDocumentSnapshot<Map<String, dynamic>>> emergenciesDocs = [];
      if (uid != null) {
        final q = await FirebaseFirestore.instance
            .collection('emergencies')
            .where('caregiverId', isEqualTo: uid)
            .where('active', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .get();
        emergenciesDocs = q.docs;
      }

      if (!mounted) return;
      setState(() {
        _pending = list;
        _emergencies = emergenciesDocs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error cargando notificaciones: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _pending.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_pending.map((n) => n.id));
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) {
      await _showOkDialog(
        context,
        title: 'Atención',
        message: 'Debes seleccionar al menos una notificación para eliminar.',
      );
      return;
    }

    final count = _selectedIds.length;
    final confirm = await _showDeleteDialog(
      context,
      message: count == 1
          ? '¿Deseas eliminar esta notificación?'
          : '¿Deseas eliminar las $count notificaciones seleccionadas?',
    );

    if (confirm == true) {
      for (final id in _selectedIds) {
        await NotificationsService.cancel(id);
      }
      await _loadAll();
      if (!mounted) return;
      await _showOkDialog(
        context,
        title: 'Eliminadas',
        message: count == 1
            ? 'La notificación fue eliminada correctamente.'
            : '$count notificaciones fueron eliminadas correctamente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final total = _pending.length + _emergencies.length;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Notificaciones',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.secondaryButton.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    '$total',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary),
            tooltip: 'Actualizar',
            onPressed: _loadAll,
          ),
          if (_selectMode) ...[
            IconButton(
              icon: Icon(
                Icons.select_all_rounded,
                color: colors.secondaryButton,
              ),
              tooltip: 'Seleccionar todas',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_rounded,
                color: colors.emergency,
              ),
              tooltip: 'Eliminar seleccionadas',
              onPressed: _confirmDeleteSelected,
            ),
          ],
          IconButton(
            icon: Icon(
              _selectMode ? Icons.close_rounded : Icons.check_box_rounded,
              color: colors.textPrimary,
            ),
            tooltip: _selectMode
                ? 'Salir de selección'
                : 'Seleccionar notificaciones',
            onPressed: _toggleSelectMode,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.primaryButtonText,
        backgroundColor: colors.primaryButton,
        onRefresh: _loadAll,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: colors.primaryButton,
                ),
              )
            : total == 0
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._emergencies.map(_buildEmergencyCard),
                      ..._pending.map(_buildMemoryCard),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmergencyCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final colors = context.appColors;
    final data = doc.data();
    final name = data['consultantName'] ?? 'Consultante';
    final lat = data['lat'];
    final lng = data['lng'];
    final time = (data['timestamp'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.emergency.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.emergency.withValues(alpha: 0.75),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colors.emergencyText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Emergencia detectada',
                  style: TextStyle(
                    color: colors.emergencyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Paciente: $name',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (time != null)
            Text(
              'Hora: ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.map_rounded, color: colors.primaryButtonText),
                  label: Text(
                    'Ver emergencia',
                    style: TextStyle(color: colors.primaryButtonText),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: colors.primaryButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) {
                        final dialogColors = context.appColors;
                        return AlertDialog(
                          backgroundColor: dialogColors.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: dialogColors.primaryButton,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Ubicación de $name',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: dialogColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: SizedBox(
                            width: 340,
                            height: 320,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: EmergencyMapPage(
                                consultantId: data['consultantId'] ?? '',
                                lat: lat,
                                lng: lng,
                                isDialog: true,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton.icon(
                              onPressed: () async {
                                final url =
                                    'https://www.google.com/maps?q=$lat,$lng';
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: Icon(
                                Icons.directions,
                                color: dialogColors.primaryButton,
                              ),
                              label: Text(
                                'Abrir en Google Maps',
                                style: TextStyle(
                                  color: dialogColors.primaryButton,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cerrar',
                                style: TextStyle(
                                  color: dialogColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: colors.textPrimary,
                  ),
                  label: Text(
                    'Resolver',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _resolveEmergency(doc.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(PendingNotificationRequest n) {
    final colors = context.appColors;
    final selected = _selectedIds.contains(n.id);
    final title =
        (n.title?.isNotEmpty ?? false) ? n.title! : 'Recordatorio de recuerdo';
    final body = (n.body?.isNotEmpty ?? false) ? n.body! : 'Sin descripción';

    return GestureDetector(
      onTap: _selectMode ? () => _toggleSelect(n.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.secondaryButton : colors.border,
            width: selected ? 2.2 : 1.2,
          ),
          color: selected
              ? colors.secondaryButton.withValues(alpha: 0.14)
              : colors.cardBackground,
          boxShadow: context.isDark
              ? []
              : [
                  BoxShadow(
                    color: colors.border.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_selectMode)
                  Checkbox(
                    value: selected,
                    activeColor: colors.secondaryButton,
                    checkColor: colors.secondaryButtonText,
                    side: BorderSide(color: colors.border),
                    onChanged: (_) => _toggleSelect(n.id),
                  ),
                Icon(
                  Icons.notifications_active_rounded,
                  color: colors.secondaryButton,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.photo_rounded, color: colors.primaryButtonText),
                label: Text(
                  'Ver recuerdo',
                  style: TextStyle(color: colors.primaryButtonText),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => _showTrainMemoryDialog(context, n),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainGraphicCartoon extends StatelessWidget {
  final Animation<double> spin;
  const _TrainGraphicCartoon({required this.spin});

  Widget _wheel(BuildContext context, double l, double b) => AnimatedBuilder(
        animation: spin,
        builder: (_, __) {
          final colors = context.appColors;
          final a = spin.value * math.pi * 4;
          return Positioned(
            left: l,
            bottom: b,
            child: Transform.rotate(
              angle: a,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.emergency,
                  border: Border.all(color: colors.textPrimary, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    const base = 30.0;

    return SizedBox(
      width: 420,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 160,
            bottom: base,
            child: Container(
              width: 90,
              height: 55,
              decoration: BoxDecoration(
                color: colors.categoryPurple,
                border: Border.all(color: colors.textPrimary, width: 3),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          _wheel(context, 175, base - 20),
          _wheel(context, 220, base - 20),
          Positioned(
            left: 270,
            bottom: base,
            child: Container(
              width: 90,
              height: 55,
              decoration: BoxDecoration(
                color: colors.categoryBlue,
                border: Border.all(color: colors.textPrimary, width: 3),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          _wheel(context, 285, base - 20),
          _wheel(context, 330, base - 20),
          Positioned(
            left: 50,
            bottom: base,
            child: Container(
              width: 100,
              height: 65,
              decoration: BoxDecoration(
                color: colors.categoryPink,
                border: Border.all(color: colors.textPrimary, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 90,
            bottom: base + 30,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: colors.categoryBlue,
                border: Border.all(color: colors.textPrimary, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 60,
            bottom: base + 60,
            child: Container(
              width: 20,
              height: 25,
              decoration: BoxDecoration(
                color: colors.categoryYellow,
                border: Border.all(color: colors.textPrimary, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 85,
            bottom: base + 68,
            child: Container(
              width: 70,
              height: 10,
              color: colors.categoryGreen,
            ),
          ),
          Positioned(
            left: 110,
            bottom: base + 40,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: colors.categoryYellow,
                border: Border.all(color: colors.textPrimary, width: 2),
              ),
            ),
          ),
          _wheel(context, 65, base - 20),
          _wheel(context, 110, base - 20),
        ],
      ),
    );
  }
}

Future<void> _showTrainMemoryDialog(
  BuildContext context,
  PendingNotificationRequest n,
) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final payload = n.payload ?? '';
  final parts = payload.split('/');
  final memoryId = parts.isNotEmpty ? parts.last : null;

  if (userId == null || memoryId == null) {
    await _showOkDialog(
      context,
      title: 'Error',
      message: 'No se pudo identificar el recuerdo.',
    );
    return;
  }

  final doc = await FirebaseFirestore.instance
      .collection('memories')
      .doc(userId)
      .collection('user_memories')
      .doc(memoryId)
      .get();

  if (!doc.exists) {
    await _showOkDialog(
      context,
      title: 'No encontrado',
      message: 'Este recuerdo ya no existe.',
    );
    return;
  }

  final data = doc.data()!;
  final text = data['text']?.toString() ?? 'Sin descripción';
  final imageUrl = data['imageUrl'] as String?;
  final formattedDate = _formatMemoryDate(data['date']);

  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    pageBuilder: (_, __, ___) => const SizedBox(),
    transitionDuration: const Duration(milliseconds: 600),
    transitionBuilder: (_, anim, __, ___) {
      return FadeTransition(
        opacity: anim,
        child: TrainMemoryDialog(
          imageUrl: imageUrl,
          text: text,
          date: formattedDate,
        ),
      );
    },
  );
}

String _formatMemoryDate(dynamic rawDate) {
  if (rawDate == null) return 'Sin fecha';

  DateTime? parsed;

  if (rawDate is Timestamp) {
    parsed = rawDate.toDate();
  } else if (rawDate is DateTime) {
    parsed = rawDate;
  } else if (rawDate is String) {
    final value = rawDate.trim();
    if (value.isEmpty) return 'Sin fecha';

    parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }
  }

  if (parsed == null) return 'Sin fecha';

  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final year = parsed.year.toString();

  return '$day/$month/$year';
}

class TrainMemoryDialog extends StatefulWidget {
  final String? imageUrl;
  final String text;
  final String date;

  const TrainMemoryDialog({
    super.key,
    required this.imageUrl,
    required this.text,
    required this.date,
  });

  @override
  State<TrainMemoryDialog> createState() => _TrainMemoryDialogState();
}

class _TrainMemoryDialogState extends State<TrainMemoryDialog>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _smoke;
  late final AnimationController _leave;
  late final Animation<Offset> _trainIn;
  late final Animation<Offset> _trainOut;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _smoke = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    _leave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _trainIn = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

    _trainOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.3, 0),
    ).animate(CurvedAnimation(parent: _leave, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _intro.dispose();
    _smoke.dispose();
    _leave.dispose();
    super.dispose();
  }

  Future<void> _closeDialog() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _leave.forward();
    _smoke.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final w = MediaQuery.of(context).size.width;
    final dialogW = w * 0.92;

    return Center(
      child: Material(
        color: colors.textPrimary.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            width: dialogW.clamp(320, 560),
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                color: colors.elevatedCard,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'El recuerdo ha llegado',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MemoryCardWhiteBorder(
                      imageUrl: widget.imageUrl,
                      text: widget.text,
                      date: widget.date,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TrackPainter(colors),
                            ),
                          ),
                          Positioned(
                            right: 145,
                            bottom: 112,
                            child: _SmokeLoop(
                              controller: _smoke,
                              size: 22,
                              phase: 0.00,
                            ),
                          ),
                          Positioned(
                            right: 160,
                            bottom: 118,
                            child: _SmokeLoop(
                              controller: _smoke,
                              size: 26,
                              phase: 0.33,
                            ),
                          ),
                          Positioned(
                            right: 175,
                            bottom: 124,
                            child: _SmokeLoop(
                              controller: _smoke,
                              size: 20,
                              phase: 0.66,
                            ),
                          ),
                          SlideTransition(
                            position: _trainOut,
                            child: SlideTransition(
                              position: _trainIn,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: _TrainGraphicCartoon(spin: _smoke),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.secondaryButtonText,
                        ),
                        label: Text(
                          'Cerrar',
                          style: TextStyle(color: colors.secondaryButtonText),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: colors.secondaryButton,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _closeDialog,
                      ),
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

class _TrackPainter extends CustomPainter {
  final AppColors colors;
  const _TrackPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final rail = Paint()
      ..color = colors.border
      ..strokeWidth = 4;

    final sleeper = Paint()
      ..color = colors.textSecondary.withValues(alpha: 0.65)
      ..strokeWidth = 6;

    final yU = size.height - 28;
    final yL = size.height - 20;

    canvas.drawLine(Offset(12, yU), Offset(size.width - 12, yU), rail);
    canvas.drawLine(Offset(12, yL), Offset(size.width - 12, yL), rail);

    for (double x = 20; x < size.width - 10; x += 18) {
      canvas.drawLine(Offset(x, yU - 4), Offset(x, yL + 4), sleeper);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

class _SmokeLoop extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final double phase;

  const _SmokeLoop({
    required this.controller,
    required this.size,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        double t = (controller.value + phase) % 1.0;
        final dy = -32 * t;
        final s = 0.7 + 0.7 * t;
        final o = (t < 0.15) ? (t / 0.15) : (1.0 - t);

        return Opacity(
          opacity: o.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: s,
              child: _SmokePuff(size: size),
            ),
          ),
        );
      },
    );
  }
}

class _SmokePuff extends StatelessWidget {
  final double size;
  const _SmokePuff({required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

class _MemoryCardWhiteBorder extends StatelessWidget {
  final String? imageUrl;
  final String text;
  final String date;

  const _MemoryCardWhiteBorder({
    required this.imageUrl,
    required this.text,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Card(
      color: colors.cardBackground,
      elevation: context.isDark ? 0 : 4,
      shadowColor: colors.primaryButton.withValues(alpha: 0.20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.primaryButton, width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No se pudo cargar la imagen',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryButton.withValues(alpha: 0.10),
                border: Border.all(
                  color: colors.primaryButton.withValues(alpha: 0.30),
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '¿Lo recuerdad?',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _showDeleteDialog(
  BuildContext context, {
  required String message,
}) async {
  final colors = context.appColors;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.secondaryButton,
            size: 26,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Confirmar eliminación',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 15,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: TextStyle(
              color: colors.secondaryButton,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            backgroundColor: colors.secondaryButton,
            foregroundColor: colors.secondaryButtonText,
            minimumSize: const Size(160, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Eliminar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

Future<void> _showOkDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final colors = context.appColors;

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(color: colors.textPrimary),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: colors.secondaryButton,
            foregroundColor: colors.secondaryButtonText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No hay notificaciones pendientes.\n\nPrograma un recuerdo o revisa emergencias activas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 16,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}