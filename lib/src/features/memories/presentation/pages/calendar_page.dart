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

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static final DateTime _firstDay = DateTime(2020, 1, 1);
  static final DateTime _lastDay = DateTime(2100, 12, 31);

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Set<String> _memoryDayIds = <String>{};
  final TextEditingController _searchCtrl = TextEditingController();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _selectedMemories = [];

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool _isFutureDay(DateTime day) =>
      _onlyDate(day).isAfter(_onlyDate(DateTime.now()));

  bool _isToday(DateTime day) =>
      isSameDay(_onlyDate(day), _onlyDate(DateTime.now()));

  DateTime? _getCreatedAt(Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      return rawCreatedAt.toDate();
    }
    return null;
  }

  bool _canEditMemory(Map<String, dynamic> data) {
    final createdAt = _getCreatedAt(data);
    if (createdAt == null) return false;

    final now = DateTime.now();
    final difference = now.difference(createdAt);

    return !difference.isNegative && difference <= const Duration(hours: 24);
  }

  String _editTimeRemaining(Map<String, dynamic> data) {
    final createdAt = _getCreatedAt(data);
    if (createdAt == null) return 'Tiempo de edición no disponible';

    final limit = createdAt.add(const Duration(hours: 24));
    final remaining = limit.difference(DateTime.now());

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return 'El tiempo para editar ya venció';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    if (hours > 0) {
      return 'Puedes editarlo por $hours h ${minutes} min más';
    }
    return 'Puedes editarlo por $minutes min más';
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES');

    final today = _onlyDate(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;

    _loadMemories(today);
    _loadMonthMemories(today);
  }

  String _formatDateEs(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'es_ES').format(d);

  String _formatTimeEs(DateTime d) => DateFormat('hh:mm a', 'es_ES').format(d);

  void _showDialog(String title, String message, {bool success = true}) {
    final colors = context.appColors;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? colors.categoryGreen : colors.emergency,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
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
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            height: 1.3,
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Aceptar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog(String title, String message) async {
    final colors = context.appColors;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 15,
            height: 1.3,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        actions: [
          Column(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.emergency,
                  foregroundColor: colors.emergencyText,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  foregroundColor: colors.primaryButtonText,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _showDateInfoDialog(DateTime selected) async {
    final bool isToday = _isToday(selected);
    final int count = _selectedMemories.length;

    if (isToday && count > 0) {
      _showDialog(
        'Recuerdos de hoy',
        'Ya tienes $count recuerdo${count == 1 ? '' : 's'} guardado${count == 1 ? '' : 's'} hoy. Puedes agregar más o revisar la galería.',
        success: true,
      );
      return;
    }

    if (isToday && count == 0) {
      _showDialog(
        'Recuerdos de hoy',
        'Aún no has guardado recuerdos hoy. Puedes subir uno ahora.',
        success: true,
      );
      return;
    }

    if (!isToday && count > 0) {
      _showDialog(
        'Galería de recuerdos',
        'Estás viendo recuerdos de una fecha anterior. Puedes abrirlos para verlos en grande.',
        success: true,
      );
      return;
    }

    _showDialog(
      'Sin recuerdos',
      'No hay recuerdos guardados para esta fecha.',
      success: false,
    );
  }

  Future<void> _loadMemories(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateId = _dateId(date);

    final qs = await FirebaseFirestore.instance
        .collection('memories')
        .doc(user.uid)
        .collection('user_memories')
        .where('displayDate', isEqualTo: dateId)
        .orderBy('createdAt', descending: false)
        .get();

    if (!mounted) return;

    setState(() {
      _selectedMemories = qs.docs;
    });
  }

  Future<void> _loadMonthMemories(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final qs = await FirebaseFirestore.instance
        .collection('memories')
        .doc(user.uid)
        .collection('user_memories')
        .get();

    if (!mounted) return;

    setState(() {
      _memoryDayIds
        ..clear()
        ..addAll(
          qs.docs
              .map((e) => (e.data()['displayDate'] ?? '') as String)
              .where((v) => v.isNotEmpty),
        );
    });
  }

  Future<void> _openAddMemoryDialog(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!_isToday(date)) {
      _showDialog(
        'Solo recuerdos de hoy',
        'Solo puedes agregar recuerdos en el día actual.',
        success: false,
      );
      return;
    }

    final colors = context.appColors;
    final textCtrl = TextEditingController();
    File? selectedImage;
    bool isSaving = false;

    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: colors.elevatedCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 60,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Nuevo recuerdo",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDateEs(date),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Escribe algo sobre este recuerdo...',
                  ),
                  style: TextStyle(color: colors.textPrimary),
                ),
                const SizedBox(height: 12),
                if (selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      selectedImage!,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          color: colors.textSecondary,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega una foto del recuerdo',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.secondaryButton,
                          foregroundColor: colors.secondaryButtonText,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 46),
                        ),
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (picked != null) {
                            setModalState(() => selectedImage = File(picked.path));
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Galería'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.categoryGreen,
                          foregroundColor: colors.textPrimary,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 46),
                        ),
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                          );
                          if (picked != null) {
                            setModalState(() => selectedImage = File(picked.path));
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Cámara'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primaryButton,
                    foregroundColor: colors.primaryButtonText,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedImage == null) {
                            _showDialog(
                              'Falta imagen',
                              'Debes subir una foto antes de guardar.',
                              success: false,
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);

                          try {
                            final userId = user.uid;
                            final now = DateTime.now();
                            final displayDateId = _dateId(now);

                            final docRef = FirebaseFirestore.instance
                                .collection('memories')
                                .doc(userId)
                                .collection('user_memories')
                                .doc();

                            final docId = docRef.id;

                            final ref = FirebaseStorage.instance
                                .ref()
                                .child('user_memories')
                                .child(userId)
                                .child('$docId.jpg');

                            await ref.putFile(selectedImage!);
                            final imageUrl = await ref.getDownloadURL();

                            final data = <String, dynamic>{
                              'text': textCtrl.text.trim(),
                              'imageUrl': imageUrl,
                              'displayDate': displayDateId,
                              'createdAt': Timestamp.fromDate(now),
                              'updatedAt': Timestamp.fromDate(now),
                            };

                            await docRef.set(data);

                            if (!mounted) return;
                            Navigator.pop(ctx);

                            _showDialog(
                              'Recuerdo guardado',
                              'El recuerdo se guardó correctamente.',
                              success: true,
                            );

                            await _loadMemories(_selectedDay ?? now);
                            await _loadMonthMemories(_focusedDay);
                          } catch (e) {
                            _showDialog(
                              'Error al guardar',
                              'Ocurrió un problema:\n\n$e',
                              success: false,
                            );
                          } finally {
                            if (mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Guardando...' : 'Guardar recuerdo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditMemoryDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> memoryDoc,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final data = memoryDoc.data();

    if (!_canEditMemory(data)) {
      _showDialog(
        'Edición no disponible',
        'Solo puedes editar este recuerdo dentro de las primeras 24 horas después de haberlo guardado.',
        success: false,
      );
      return;
    }

    final colors = context.appColors;
    final textCtrl = TextEditingController(text: (data['text'] ?? '').toString());

    final String currentImageUrl = (data['imageUrl'] ?? '').toString();
    File? newSelectedImage;
    bool isSaving = false;

    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: colors.elevatedCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 60,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Editar recuerdo",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _editTimeRemaining(data),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Edita la descripción de este recuerdo...',
                  ),
                  style: TextStyle(color: colors.textPrimary),
                ),
                const SizedBox(height: 12),
                if (newSelectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      newSelectedImage!,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (currentImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      currentImageUrl,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_back_outlined,
                          color: colors.textSecondary,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega una foto del recuerdo',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.secondaryButton,
                          foregroundColor: colors.secondaryButtonText,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 46),
                        ),
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                          );
                          if (picked != null) {
                            setModalState(() {
                              newSelectedImage = File(picked.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Cambiar foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.categoryGreen,
                          foregroundColor: colors.textPrimary,
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 46),
                        ),
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                          );
                          if (picked != null) {
                            setModalState(() {
                              newSelectedImage = File(picked.path);
                            });
                          }
                        },
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Cámara'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primaryButton,
                    foregroundColor: colors.primaryButtonText,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);

                          try {
                            String finalImageUrl = currentImageUrl;
                            final userId = user.uid;
                            final docId = memoryDoc.id;

                            if (newSelectedImage != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('user_memories')
                                  .child(userId)
                                  .child('$docId.jpg');

                              await ref.putFile(newSelectedImage!);
                              finalImageUrl = await ref.getDownloadURL();
                            }

                            await memoryDoc.reference.update({
                              'text': textCtrl.text.trim(),
                              'imageUrl': finalImageUrl,
                              'updatedAt': Timestamp.fromDate(DateTime.now()),
                            });

                            if (!mounted) return;
                            Navigator.pop(ctx);

                            _showDialog(
                              'Recuerdo actualizado',
                              'El recuerdo se editó correctamente.',
                              success: true,
                            );

                            await _loadMemories(_selectedDay ?? DateTime.now());
                            await _loadMonthMemories(_focusedDay);
                          } catch (e) {
                            _showDialog(
                              'Error al editar',
                              'Ocurrió un problema:\n\n$e',
                              success: false,
                            );
                          } finally {
                            if (mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(isSaving ? 'Guardando cambios...' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMemoryViewer(
    QueryDocumentSnapshot<Map<String, dynamic>> memoryDoc,
    int index,
  ) async {
    final colors = context.appColors;
    final data = memoryDoc.data();
    final createdAt = _getCreatedAt(data);
    final canEdit = _canEditMemory(data);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    ),
                    Expanded(
                      child: Text(
                        'Recuerdo ${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['imageUrl'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            data['imageUrl'],
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.elevatedCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recuerdo ${index + 1}',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedDay != null
                                  ? _formatDateEs(_selectedDay!)
                                  : '',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Guardado a las ${_formatTimeEs(createdAt)}',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                canEdit
                                    ? _editTimeRemaining(data)
                                    : 'Este recuerdo ya no se puede editar',
                                style: TextStyle(
                                  color: canEdit
                                      ? colors.categoryGreen
                                      : colors.emergency,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              (data['text'] ?? '').toString().trim().isEmpty
                                  ? 'Sin descripción'
                                  : (data['text'] ?? '').toString(),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: canEdit
                                          ? colors.secondaryButton
                                          : colors.border,
                                      foregroundColor: canEdit
                                          ? colors.secondaryButtonText
                                          : colors.textSecondary,
                                      shape: const StadiumBorder(),
                                      minimumSize: const Size.fromHeight(46),
                                    ),
                                    onPressed: canEdit
                                        ? () async {
                                            Navigator.pop(ctx);
                                            await _openEditMemoryDialog(memoryDoc);
                                          }
                                        : null,
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Editar'),
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Future<void> _deleteMemory(
    QueryDocumentSnapshot<Map<String, dynamic>> memoryDoc,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await _confirmDialog(
      'Eliminar recuerdo',
      '¿Deseas eliminar este recuerdo?',
    );
    if (!confirm) return;

    final data = memoryDoc.data();
    final docId = memoryDoc.id;
    final userId = user.uid;

    await FirebaseFirestore.instance
        .collection('memories')
        .doc(userId)
        .collection('user_memories')
        .doc(docId)
        .delete();

    if (data['imageUrl'] != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_memories')
          .child(userId)
          .child('$docId.jpg');
      await ref.delete().catchError((_) {});
    }

    await _loadMemories(_selectedDay ?? DateTime.now());
    await _loadMonthMemories(_focusedDay);

    _showDialog(
      'Recuerdo eliminado',
      'El recuerdo fue eliminado correctamente.',
      success: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selectedDate = _selectedDay ?? _onlyDate(DateTime.now());
    final bool isSelectedToday = _isToday(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuerdos'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ir a fecha (D/M/A)',
                  prefixIcon: Icon(
                    Icons.calendar_today_outlined,
                    color: colors.textSecondary,
                  ),
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          onPressed: () => setState(() => _searchCtrl.clear()),
                          icon: Icon(Icons.clear, color: colors.textSecondary),
                        )
                      : null,
                ),
                onChanged: _onDateInputChanged,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.calendarSurface,
                border: Border.all(color: colors.primaryButton, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TableCalendar(
                locale: 'es_ES',
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: colors.textSecondary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: colors.textSecondary,
                  ),
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: colors.textSecondary),
                  weekendStyle: TextStyle(color: colors.textSecondary),
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: colors.textPrimary),
                  weekendTextStyle: TextStyle(color: colors.textPrimary),
                  outsideTextStyle: TextStyle(color: colors.textSecondary),
                  todayDecoration: BoxDecoration(
                    color: colors.primaryButton,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: colors.primaryButtonText),
                  selectedDecoration: BoxDecoration(
                    color: colors.secondaryButton,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle:
                      TextStyle(color: colors.secondaryButtonText),
                  defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
                  weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
                  markersAlignment: Alignment.bottomCenter,
                  markersMaxCount: 1,
                  disabledTextStyle: TextStyle(color: colors.textSecondary),
                ),
                enabledDayPredicate: (day) => true,
                eventLoader: (day) =>
                    _memoryDayIds.contains(_dateId(day)) ? ['mem'] : const [],
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primaryButton,
                        ),
                      ),
                    );
                  },
                ),
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                onDaySelected: (selected, focused) async {
                  if (_isFutureDay(selected)) {
                    _showDialog(
                      'Fecha no permitida',
                      'No puedes seleccionar una fecha futura para agregar o ver recuerdos.',
                      success: false,
                    );
                    return;
                  }

                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });

                  await _loadMemories(selected);

                  if (!mounted) return;
                  await _showDateInfoDialog(selected);
                },
                onPageChanged: (focused) {
                  _focusedDay = focused;
                  _loadMonthMemories(_focusedDay);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isSelectedToday
                      ? colors.secondaryButton
                      : colors.border,
                  foregroundColor: isSelectedToday
                      ? colors.secondaryButtonText
                      : colors.textSecondary,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                icon: Icon(
                  isSelectedToday
                      ? Icons.add_a_photo_outlined
                      : Icons.lock_outline,
                ),
                label: Text(
                  isSelectedToday
                      ? 'Agregar recuerdo de hoy'
                      : 'Solo disponible hoy',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  if (!isSelectedToday) {
                    _showDialog(
                      'Edición no disponible',
                      'Solo puedes agregar recuerdos en el día actual.',
                      success: false,
                    );
                    return;
                  }

                  final wants = await _confirmDialog(
                    'Agregar recuerdo',
                    '¿Deseas agregar un nuevo recuerdo para hoy?',
                  );

                  if (!wants) return;
                  _openAddMemoryDialog(selectedDate);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedMemories.isEmpty
                      ? 'Galería de recuerdos'
                      : 'Galería de recuerdos (${_selectedMemories.length})',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            if (_selectedMemories.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.elevatedCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_album_outlined,
                        size: 34,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No hay recuerdos guardados para esta fecha.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 290,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMemories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final memoryDoc = _selectedMemories[index];
                    final memory = memoryDoc.data();
                    final canEdit = _canEditMemory(memory);

                    return GestureDetector(
                      onTap: () => _openMemoryViewer(memoryDoc, index),
                      child: Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: colors.elevatedCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.border),
                          boxShadow: [
                            BoxShadow(
                              color: context.isDark
                                  ? Colors.black.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: memory['imageUrl'] != null
                                  ? Image.network(
                                      memory['imageUrl'],
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: colors.inputFill,
                                      child: Icon(
                                        Icons.photo,
                                        size: 42,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                              child: Text(
                                'Recuerdo ${index + 1}',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                ((memory['text'] ?? '').toString().trim().isEmpty)
                                    ? 'Sin descripción'
                                    : (memory['text'] ?? '').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                              child: Text(
                                canEdit
                                    ? _editTimeRemaining(memory)
                                    : 'Ya no se puede editar',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: canEdit
                                      ? colors.categoryGreen
                                      : colors.emergency,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _openMemoryViewer(memoryDoc, index),
                                      icon: const Icon(Icons.open_in_full),
                                      label: const Text('Ver'),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: canEdit
                                        ? () => _openEditMemoryDialog(memoryDoc)
                                        : null,
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: canEdit
                                          ? colors.primaryButton
                                          : colors.textSecondary,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: isSelectedToday
                                        ? () => _deleteMemory(memoryDoc)
                                        : null,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: isSelectedToday
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

  void _onDateInputChanged(String value) {
    if (value.length == 2 && !value.contains('/')) {
      _searchCtrl.text = '$value/';
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchCtrl.text.length),
      );
      setState(() {});
      return;
    } else if (value.length == 5 && value.split('/').length == 2) {
      _searchCtrl.text = '$value/';
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchCtrl.text.length),
      );
      setState(() {});
      return;
    }

    final parts = value.split('/');
    if (parts.length == 3 && parts[2].length == 4) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d == null || m == null || y == null) return;
      if (m < 1 || m > 12 || d < 1 || d > 31) return;

      final newDate = DateTime(y, m, d);
      if (newDate.month != m || newDate.day != d || newDate.year != y) return;

      if (_isFutureDay(newDate)) {
        _showDialog(
          'Fecha no permitida',
          'No puedes seleccionar una fecha futura para agregar o ver recuerdos.',
          success: false,
        );
        return;
      }

      setState(() {
        _selectedDay = newDate;
        _focusedDay = newDate;
      });

      _loadMemories(newDate).then((_) {
        if (mounted) {
          _showDateInfoDialog(newDate);
        }
      });

      _loadMonthMemories(newDate);
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





