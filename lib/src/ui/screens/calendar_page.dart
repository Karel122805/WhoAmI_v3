import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme.dart';
import 'package:whoami_app/services/notifications_service.dart'; // MemoryCadence + cadenceFromString

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

  // Guardamos también el id del doc para poder editar/eliminar
  String? _selectedMemoryDocId;
  Map<String, dynamic>? _selectedMemory;

  final Set<String> _memoryDayIds = <String>{};
  final TextEditingController _searchCtrl = TextEditingController();

  MemoryCadence _cadence = MemoryCadence.monthly;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool _isFutureDay(DateTime day) =>
      _onlyDate(day).isAfter(_onlyDate(DateTime.now()));

  @override
  void initState() {
    super.initState();

    // Intl (es)
    // ignore: discarded_futures
    initializeDateFormatting('es_ES');

    final today = _onlyDate(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;

    _loadMemory(today);
    _loadMonthMemories(today);
  }

  String _formatDateEs(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'es_ES').format(d);

  void _showDialog(String title, String message, {bool success = true}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? kGreenPastel : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: kInk,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: kInk, fontSize: 15, height: 1.3),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Aceptar',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDialog(String title, String message) async {
    const Color softRed = Color(0xFFFF8A8A);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: kInk,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: kInk, fontSize: 15, height: 1.3),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        actions: [
          Column(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: softRed,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kBlue,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(48),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Confirmar',
                  style: TextStyle(color: kInk, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ===============================
  // CARGAR RECUERDOS
  // ===============================
  Future<void> _loadMemory(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateId = _dateId(date);

    final qs = await FirebaseFirestore.instance
        .collection('memories')
        .doc(user.uid)
        .collection('user_memories')
        .where('displayDate', isEqualTo: dateId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (!mounted) return;

    setState(() {
      if (qs.docs.isEmpty) {
        _selectedMemory = null;
        _selectedMemoryDocId = null;
      } else {
        _selectedMemory = qs.docs.first.data();
        _selectedMemoryDocId = qs.docs.first.id;
      }
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

  // ===============================
  // MODAL CREAR / EDITAR
  // ===============================
  void _openMemoryDialog(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final textCtrl = TextEditingController(text: _selectedMemory?['text'] ?? '');
    File? selectedImage;
    bool isSaving = false;

    // Si existe recuerdo, intenta cargar cadence/time actuales
    try {
      final rem = _selectedMemory?['reminder'];
      if (rem is Map) {
        final cadenceRaw = (rem['cadence'] as String?) ?? _cadence.name;
        _cadence = cadenceFromString(cadenceRaw);

        final timeStr = (rem['time'] as String?) ?? '';
        if (timeStr.contains(':')) {
          final parts = timeStr.split(':');
          final hh = int.tryParse(parts[0]) ?? _selectedTime.hour;
          final mm = int.tryParse(parts[1]) ?? _selectedTime.minute;
          _selectedTime = TimeOfDay(hour: hh, minute: mm);
        }
      }
    } catch (_) {}

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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 60,
                  decoration: BoxDecoration(
                    color: kFieldBorder,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Recuerdo del ${date.day}/${date.month}/${date.year}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Escribe algo sobre este día...',
                  ),
                ),
                const SizedBox(height: 12),

                // Hora
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: kInk,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: _selectedTime,
                    );
                    if (picked != null) {
                      setModalState(() => _selectedTime = picked);
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text('Hora del recordatorio: ${_selectedTime.format(context)}'),
                ),

                const SizedBox(height: 12),

                // Frecuencia
                DropdownButtonFormField<String>(
                  initialValue: _cadence.name,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia del recordatorio',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'hourly1', child: Text('Cada 1 hora')),
                    DropdownMenuItem(value: 'hourly2', child: Text('Cada 2 horas')),
                    DropdownMenuItem(value: 'hourly6', child: Text('Cada 6 horas')),
                    DropdownMenuItem(value: 'daily1', child: Text('Cada 1 día')),
                    DropdownMenuItem(value: 'daily2', child: Text('Cada 2 días')),
                    DropdownMenuItem(value: 'weekly', child: Text('Cada semana')),
                    DropdownMenuItem(value: 'biweekly', child: Text('Cada 2 semanas')),
                    DropdownMenuItem(value: 'monthly', child: Text('Cada mes')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Cada 3 meses')),
                    DropdownMenuItem(value: 'semiannual', child: Text('Cada 6 meses')),
                    DropdownMenuItem(value: 'annual', child: Text('Cada año')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => _cadence = cadenceFromString(val));
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Imagen
                if (selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      selectedImage!,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (_selectedMemory?['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _selectedMemory!['imageUrl'],
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPurple,
                        foregroundColor: kInk,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(140, 44),
                      ),
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (picked != null) {
                          setModalState(() => selectedImage = File(picked.path));
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Galería'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenPastel,
                        foregroundColor: kInk,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(140, 44),
                      ),
                      onPressed: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                        );
                        if (picked != null) {
                          setModalState(() => selectedImage = File(picked.path));
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Cámara'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Guardar
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8BCBFF),
                    foregroundColor: kInk,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (_isFutureDay(date)) {
                            _showDialog(
                              'Fecha no permitida',
                              'No puedes guardar recuerdos en fechas futuras.',
                              success: false,
                            );
                            return;
                          }

                          if (selectedImage == null &&
                              (_selectedMemory?['imageUrl'] == null)) {
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
                            final displayDateId = _dateId(date);

                            final bool isNew = _selectedMemoryDocId == null;
                            final docRef = isNew
                                ? FirebaseFirestore.instance
                                    .collection('memories')
                                    .doc(userId)
                                    .collection('user_memories')
                                    .doc()
                                : FirebaseFirestore.instance
                                    .collection('memories')
                                    .doc(userId)
                                    .collection('user_memories')
                                    .doc(_selectedMemoryDocId);

                            final String docId = docRef.id;

                            String? imageUrl = _selectedMemory?['imageUrl'];

                            // Subida de imagen (si seleccionaron nueva)
                            if (selectedImage != null) {
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child('user_memories')
                                  .child(userId)
                                  .child('$docId.jpg');

                              await ref.putFile(selectedImage!);
                              imageUrl = await ref.getDownloadURL();
                            }

                            // ✅ nextAt: HOY a la hora elegida; si ya pasó, MAÑANA a esa hora
                            final now = DateTime.now();
                            DateTime nextAt = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              _selectedTime.hour,
                              _selectedTime.minute,
                            );
                            if (nextAt.isBefore(now)) {
                              nextAt = nextAt.add(const Duration(days: 1));
                            }
                            if (nextAt.isBefore(now)) {
                              nextAt = now.add(const Duration(minutes: 1));
                            }

                            final timeStr =
                                "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

                            final cleanText = textCtrl.text.trim();
                            final safeTitle =
                                cleanText.isEmpty ? 'Tu recuerdo' : cleanText;

                            final data = <String, dynamic>{
                              'text': cleanText,
                              'imageUrl': imageUrl,
                              'displayDate': displayDateId,
                              'reminder': {
                                'enabled': true,
                                'cadence': _cadence.name,
                                'time': timeStr,
                                'timezone': 'America/Mexico_City',
                                'nextAt': Timestamp.fromDate(nextAt),
                              },
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            if (isNew) {
                              data['createdAt'] = FieldValue.serverTimestamp();
                            }

                            await docRef.set(data, SetOptions(merge: true));

                            // ✅ Programar notificaciones con el nuevo esquema (usa nextAt)
                            await NotificationsService.scheduleForMemory(
                              memoryId: '$userId/$docId',
                              title: safeTitle,
                              anchorDate: nextAt,
                              cadence: _cadence,
                            );

                            // Actualizar selección local
                            if (mounted) {
                              setState(() {
                                _selectedMemoryDocId = docId;
                              });
                            }

                            if (mounted) Navigator.pop(ctx);

                            _showDialog(
                              'Recuerdo guardado',
                              'Tu recuerdo se ha guardado correctamente.',
                              success: true,
                            );

                            await _loadMemory(date);
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
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'Guardando...' : 'Guardar'),
                ),

                const SizedBox(height: 8),

                // Eliminar
                if (_selectedMemory != null && _selectedMemoryDocId != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8A8A),
                      shape: const StadiumBorder(),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      final confirm = await _confirmDialog(
                        'Eliminar recuerdo',
                        '¿Deseas eliminar el recuerdo?',
                      );
                      if (!confirm) return;

                      final userId = user.uid;
                      final docId = _selectedMemoryDocId!;

                      // ✅ Cancelar notificaciones (antes de borrar el doc)
                      await NotificationsService.cancelForMemory('$userId/$docId');

                      await FirebaseFirestore.instance
                          .collection('memories')
                          .doc(userId)
                          .collection('user_memories')
                          .doc(docId)
                          .delete();

                      // Borrar imagen si existe
                      if (_selectedMemory?['imageUrl'] != null) {
                        final ref = FirebaseStorage.instance
                            .ref()
                            .child('user_memories')
                            .child(userId)
                            .child('$docId.jpg');
                        await ref.delete().catchError((_) {});
                      }

                      if (mounted) Navigator.pop(ctx);

                      _showDialog(
                        'Recuerdo eliminado',
                        'El recuerdo fue eliminado.',
                        success: true,
                      );

                      if (mounted) {
                        setState(() {
                          _selectedMemory = null;
                          _selectedMemoryDocId = null;
                        });
                      }

                      await _loadMonthMemories(_focusedDay);
                      await _loadMemory(date);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Eliminar recuerdo'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===============================
  // UI PRINCIPAL
  // ===============================
  @override
  Widget build(BuildContext context) {
    final selectedDate = _selectedDay ?? _onlyDate(DateTime.now());

    final bool hasMemory = _selectedMemory != null &&
        (((_selectedMemory!['text'] ?? '').toString().isNotEmpty) ||
            _selectedMemory!['imageUrl'] != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuerdos'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: kInk,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ir a fecha (D/M/A)',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: (_searchCtrl.text.isNotEmpty)
                      ? IconButton(
                          onPressed: () => setState(() => _searchCtrl.clear()),
                          icon: const Icon(Icons.clear),
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
                color: Colors.white,
                border: Border.all(color: kBlue, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TableCalendar(
                locale: 'es_ES',
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                  ),
                ),
                calendarStyle: const CalendarStyle(
                  defaultTextStyle: TextStyle(color: kInk),
                  weekendTextStyle: TextStyle(color: kInk),
                  outsideTextStyle: TextStyle(color: kGrey1),
                  todayDecoration: BoxDecoration(color: kBlue, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: kPurple, shape: BoxShape.circle),
                  markersAlignment: Alignment.bottomCenter,
                  markersMaxCount: 1,
                ),
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
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kBlue,
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
                      'No puedes seleccionar fechas futuras para guardar recuerdos.',
                      success: false,
                    );
                    return;
                  }

                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });

                  await _loadMemory(selected);
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
                  backgroundColor: hasMemory ? kBlue : kPurple,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                icon: Icon(hasMemory ? Icons.edit : Icons.upload, color: kInk),
                label: Text(
                  hasMemory ? 'Modificar recuerdo' : 'Subir recuerdo',
                  style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  if (_selectedDay == null) return;
                  final selected = _selectedDay!;

                  final wants = await _confirmDialog(
                    hasMemory ? 'Modificar recuerdo' : 'Subir recuerdo',
                    hasMemory
                        ? 'Ya existe un recuerdo en esta fecha. ¿Deseas modificarlo?'
                        : '¿Deseas subir un recuerdo para el ${selected.day}/${selected.month}/${selected.year}?',
                  );

                  if (!wants) return;
                  _openMemoryDialog(selected);
                },
              ),
            ),
            if (_selectedMemory != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildMemoryCard(selectedDate),
              ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // TARJETA
  // ===============================
  Widget _buildMemoryCard(DateTime date) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kFieldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kBlue.withOpacity(0.35), kPurple.withOpacity(0.35)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark, color: kInk),
                const SizedBox(width: 8),
                Text(
                  _formatDateEs(date),
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((_selectedMemory!['text'] ?? '').toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kFieldFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kFieldBorder),
                    ),
                    child: Text(
                      (_selectedMemory!['text'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: kInk,
                        height: 1.35,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_selectedMemory?['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _selectedMemory!['imageUrl'],
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // BUSCAR POR FECHA D/M/A
  // ===============================
  void _onDateInputChanged(String value) {
    if (value.length == 2 && !value.contains('/')) {
      _searchCtrl.text = '$value/';
      _searchCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
      return;
    } else if (value.length == 5 && value.split('/').length == 2) {
      _searchCtrl.text = '$value/';
      _searchCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
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
      if (_isFutureDay(newDate)) return;

      setState(() {
        _selectedDay = newDate;
        _focusedDay = newDate;
      });

      _loadMemory(newDate);
      _loadMonthMemories(newDate);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
