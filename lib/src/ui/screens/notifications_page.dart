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

    // 🧹 Marca la emergencia como resuelta y borra sus notificaciones
  Future<void> _resolveEmergency(String docId) async {
    try {
      // 1) Marcar en Firestore como inactiva
      await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(docId)
          .update({'active': false});

      // 2) Cancelar notificaciones locales relacionadas a emergencias
      final pending = await NotificationsService.pendingNotificationRequests();
      for (final n in pending) {
        if (n.payload == 'emergency') {
          await NotificationsService.cancel(n.id);
        }
      }

      // 3) Recargar la pantalla
      await _loadAll();
    } catch (e) {
      debugPrint('⚠️ Error al resolver emergencia: $e');
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
      _showOkDialog(context,
          title: 'Atención',
          message: 'Debes seleccionar al menos una notificación para eliminar.');
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
      _showOkDialog(context,
          title: 'Eliminadas',
          message: count == 1
              ? 'La notificación fue eliminada correctamente.'
              : '$count notificaciones fueron eliminadas correctamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _pending.length + _emergencies.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Notificaciones',
                style: TextStyle(
                  color: Colors.black,
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
                    color: kPurple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(
                      color: Colors.black,
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
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            tooltip: 'Actualizar',
            onPressed: _loadAll,
          ),
          if (_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded,
                  color: Color(0xFF7C4DFF)),
              tooltip: 'Seleccionar todas',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              tooltip: 'Eliminar seleccionadas',
              onPressed: _confirmDeleteSelected,
            ),
          ],
          IconButton(
            icon: Icon(
              _selectMode ? Icons.close_rounded : Icons.check_box_rounded,
              color: Colors.black,
            ),
            tooltip: _selectMode
                ? 'Salir de selección'
                : 'Seleccionar notificaciones',
            onPressed: _toggleSelectMode,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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

  /// 🟥 Emergencia recibida por el cuidador
  Widget _buildEmergencyCard(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = data['consultantName'] ?? 'Consultante';
    final lat = data['lat'];
    final lng = data['lng'];
    final time = (data['timestamp'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.6), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 6),
              Text(
                'Emergencia detectada',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Paciente: $name',
              style: const TextStyle(color: kInk, fontSize: 15)),
          if (time != null)
            Text('Hora: ${time.hour}:${time.minute.toString().padLeft(2, "0")}',
                style: const TextStyle(color: kGrey1, fontSize: 13)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.map_rounded, color: Colors.black),
              label: const Text('Ver emergencia',
                  style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFFFFEAEA),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Ubicación de $name',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
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
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.directions, color: Colors.black),
                        label: const Text('Abrir en Google Maps',
                            style: TextStyle(color: Colors.black)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  /// 🧠 Tarjeta de notificación local
  Widget _buildMemoryCard(PendingNotificationRequest n) {
    final selected = _selectedIds.contains(n.id);
    final title =
        (n.title?.isNotEmpty ?? false) ? n.title! : 'Recordatorio de recuerdo';
    final body =
        (n.body?.isNotEmpty ?? false) ? n.body! : 'Sin descripción';

    return GestureDetector(
      onTap: _selectMode ? () => _toggleSelect(n.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? kPurple.withOpacity(0.9)
                : kPurple.withOpacity(0.4),
            width: selected ? 2.5 : 1.2,
          ),
          color: selected ? kPurple.withOpacity(0.1) : Colors.white,
        ),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_selectMode)
                  Checkbox(
                      value: selected,
                      activeColor: kPurple,
                      onChanged: (_) => _toggleSelect(n.id)),
                const Icon(Icons.notifications_active_rounded, color: kPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kInk,
                          fontSize: 17)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: kGrey1, fontSize: 14)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.photo_rounded, color: Colors.black),
                label: const Text('Ver recuerdo',
                    style: TextStyle(color: Colors.black)),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF9ED3FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
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
// ╭──────────────────────────────╮
// │ Tren caricatura estilo dibujo │
// ╰──────────────────────────────╯
class _TrainGraphicCartoon extends StatelessWidget {
  final Animation<double> spin;
  const _TrainGraphicCartoon({required this.spin});

  Widget _wheel(double l, double b) => AnimatedBuilder(
        animation: spin,
        builder: (_, __) {
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
                    color: Colors.red,
                    border: Border.all(color: Colors.black, width: 2),
                    shape: BoxShape.circle),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    const base = 30.0;
    return SizedBox(
      width: 420,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Vagón 1 (morado)
          Positioned(
            left: 160,
            bottom: base,
            child: Container(
              width: 90,
              height: 55,
              decoration: BoxDecoration(
                  color: kPurple,
                  border: Border.all(color: Colors.black, width: 3),
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
          _wheel(175, base - 20),
          _wheel(220, base - 20),

          // Vagón 2 (azul)
          Positioned(
            left: 270,
            bottom: base,
            child: Container(
              width: 90,
              height: 55,
              decoration: BoxDecoration(
                  color: kBlue,
                  border: Border.all(color: Colors.black, width: 3),
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
          _wheel(285, base - 20),
          _wheel(330, base - 20),

          // Locomotora (roja)
          Positioned(
            left: 50,
            bottom: base,
            child: Container(
              width: 100,
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C),
                border: Border.all(color: Colors.black, width: 3),
              ),
            ),
          ),
          // Cabina (azul fuerte)
          Positioned(
            left: 90,
            bottom: base + 30,
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                border: Border.all(color: Colors.black, width: 3),
              ),
            ),
          ),
          // Chimenea amarilla
          Positioned(
            left: 60,
            bottom: base + 60,
            child: Container(
              width: 20,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.yellow.shade600,
                border: Border.all(color: Colors.black, width: 3),
              ),
            ),
          ),
          // Techo verde
          Positioned(
            left: 85,
            bottom: base + 68,
            child: Container(
              width: 70,
              height: 10,
              color: Colors.green.shade400,
            ),
          ),
          // Ventana amarilla
          Positioned(
            left: 110,
            bottom: base + 40,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.yellow.shade400,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
          _wheel(65, base - 20),
          _wheel(110, base - 20),
        ],
      ),
    );
  }
}

/// ╭──────────────────────────────────────────────────────────────╮
/// │ D I Á L O G O   D E   R E C U E R D O   C O N   T R É N     │
/// ╰──────────────────────────────────────────────────────────────╯
Future<void> _showTrainMemoryDialog(
    BuildContext context, PendingNotificationRequest n) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final payload = n.payload ?? '';
  final parts = payload.split('/');
  final memoryId = parts.isNotEmpty ? parts.last : null;

  if (userId == null || memoryId == null) {
    await _showOkDialog(context,
        title: 'Error', message: 'No se pudo identificar el recuerdo.');
    return;
  }

  final doc = await FirebaseFirestore.instance
      .collection('memories')
      .doc(userId)
      .collection('user_memories')
      .doc(memoryId)
      .get();

  if (!doc.exists) {
    await _showOkDialog(context,
        title: 'No encontrado', message: 'Este recuerdo ya no existe.');
    return;
  }

  final data = doc.data()!;
  final text = data['text'] ?? 'Sin descripción';
  final date = (data['date'] as String?) ?? '';
  final imageUrl = data['imageUrl'] as String?;

  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    pageBuilder: (_, __, ___) => const SizedBox(),
    transitionDuration: const Duration(milliseconds: 600),
    transitionBuilder: (_, anim, __, ___) {
      return FadeTransition(
        opacity: anim,
        child: TrainMemoryDialog(imageUrl: imageUrl, text: text, date: date),
      );
    },
  );
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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _smoke = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat();
    _leave = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _trainIn = Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));
    _trainOut = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.3, 0))
        .animate(CurvedAnimation(parent: _leave, curve: Curves.easeInOutCubic));
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
    final w = MediaQuery.of(context).size.width;
    final dialogW = w * 0.92;

    return Center(
      child: Material(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: Container(
            width: dialogW.clamp(320, 560),
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'El recuerdo ha llegado',
                      style: TextStyle(
                          color: kInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _MemoryCardWhiteBorder(
                        imageUrl: widget.imageUrl,
                        text: widget.text,
                        date: widget.date),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned.fill(
                              child: CustomPaint(painter: _TrackPainter())),
                          Positioned(
                              right: 145,
                              bottom: 112,
                              child: _SmokeLoop(
                                  controller: _smoke,
                                  size: 22,
                                  phase: 0.00)),
                          Positioned(
                              right: 160,
                              bottom: 118,
                              child: _SmokeLoop(
                                  controller: _smoke,
                                  size: 26,
                                  phase: 0.33)),
                          Positioned(
                              right: 175,
                              bottom: 124,
                              child: _SmokeLoop(
                                  controller: _smoke,
                                  size: 20,
                                  phase: 0.66)),
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
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.black),
                        label: const Text('Cerrar',
                            style: TextStyle(color: Colors.black)),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9CA0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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

// ╭──────────────────────────────╮
// │ Pistas, humo y diálogos      │
// ╰──────────────────────────────╯

class _TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rail = Paint()
      ..color = const Color(0xFFB9B9C9)
      ..strokeWidth = 4;
    final sleeper = Paint()
      ..color = const Color(0xFF9E9EB2)
      ..strokeWidth = 6;
    final yU = size.height - 28, yL = size.height - 20;
    canvas.drawLine(Offset(12, yU), Offset(size.width - 12, yU), rail);
    canvas.drawLine(Offset(12, yL), Offset(size.width - 12, yL), rail);
    for (double x = 20; x < size.width - 10; x += 18) {
      canvas.drawLine(Offset(x, yU - 4), Offset(x, yL + 4), sleeper);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SmokeLoop extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final double phase;
  const _SmokeLoop(
      {required this.controller, required this.size, required this.phase});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
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
              child: Transform.scale(scale: s, child: _SmokePuff(size: size)),
            ),
          );
        },
      );
}

class _SmokePuff extends StatelessWidget {
  final double size;
  const _SmokePuff({required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
          ],
        ),
      );
}

class _MemoryCardWhiteBorder extends StatelessWidget {
  final String? imageUrl;
  final String text;
  final String date;
  const _MemoryCardWhiteBorder(
      {required this.imageUrl, required this.text, required this.date});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 6,
      shadowColor: kBlue.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBlue, width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl!,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: kInk,
                    fontSize: 16,
                    height: 1.3,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kBlue.withOpacity(0.10),
                border: Border.all(color: kBlue.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Fecha: ${date.split("T").first}',
                  style: const TextStyle(color: kInk, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🟣 Diálogo tipo “Tienes cambios sin guardar” para eliminar
Future<bool> _showDeleteDialog(BuildContext context,
    {required String message}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFFF3E9FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: kPurple, size: 26),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tienes cambios sin guardar',
              style: TextStyle(
                color: Colors.black,
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
        style: const TextStyle(color: Colors.black87, fontSize: 15),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar cambios',
              style:
                  TextStyle(color: kPurple, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            backgroundColor: kPurple,
            foregroundColor: Colors.black,
            minimumSize: const Size(160, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Eliminar y salir',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _showOkDialog(BuildContext c,
    {required String title, required String message}) async {
  await showDialog<void>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
      content: Text(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: kPurple,
            foregroundColor: kInk,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(c),
          child: const Text('Aceptar'),
        )
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay notificaciones pendientes.\n\nPrograma un recuerdo o revisa emergencias activas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kGrey1, fontSize: 16, height: 1.35),
          ),
        ),
      );
}
