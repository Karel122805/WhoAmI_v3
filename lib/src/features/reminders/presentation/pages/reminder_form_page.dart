import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/core/widgets/app_feedback_dialog.dart';
import 'package:whoami_app/src/features/reminders/presentation/providers/reminder_provider.dart';

class ReminderFormPage extends StatefulWidget {
  const ReminderFormPage({super.key});

  @override
  State<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends State<ReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _alarmEnabled = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime? get _selectedDateTime {
    if (_selectedDate == null || _selectedTime == null) return null;

    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _showFeedback({
    required FeedbackDialogType type,
    required String title,
    required String message,
    VoidCallback? onPressed,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AppFeedbackDialog(
        type: type,
        title: title,
        message: message,
        onPressed: onPressed,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (date == null) return;

    setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (time == null) return;

    setState(() => _selectedTime = time);
  }

  Future<void> _saveReminder() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await _showFeedback(
        type: FeedbackDialogType.error,
        title: 'Sesión requerida',
        message: 'Debes iniciar sesión para crear recordatorios.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final dateTime = _selectedDateTime;

    if (dateTime == null) {
      await _showFeedback(
        type: FeedbackDialogType.warning,
        title: 'Falta información',
        message: 'Selecciona una fecha y una hora para el recordatorio.',
      );
      return;
    }

    if (!dateTime.isAfter(DateTime.now())) {
      await _showFeedback(
        type: FeedbackDialogType.warning,
        title: 'Fecha no válida',
        message: 'El recordatorio debe programarse para una fecha futura.',
      );
      return;
    }

    setState(() => _saving = true);

    final ok = await context.read<ReminderProvider>().create(
          userId: user.uid,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          dateTime: dateTime,
          voiceEnabled: false,
          notificationEnabled: _alarmEnabled,
        );

    if (!mounted) return;

    setState(() => _saving = false);

    if (ok) {
      await _showFeedback(
        type: FeedbackDialogType.success,
        title: 'Listo',
        message: _alarmEnabled
            ? 'Recordatorio guardado. La alarma sonará a la hora indicada.'
            : 'Recordatorio guardado sin alarma.',
        onPressed: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      );
    } else {
      await _showFeedback(
        type: FeedbackDialogType.error,
        title: 'Error',
        message: 'No se pudo guardar el recordatorio.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final dateText = _selectedDate == null
        ? 'Seleccionar fecha'
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';

    final timeText = _selectedTime == null
        ? 'Seleccionar hora'
        : _selectedTime!.format(context);

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: const Text('Nuevo recordatorio'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: colors.elevatedCard,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.alarm_add_rounded,
                            size: 54,
                            color: colors.primaryButton,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Crea un recordatorio',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Programa una alarma para recordar actividades importantes.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ej. Tomar medicamento',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (text.isEmpty) return 'Escribe un título.';

                        if (text.length < 3) {
                          return 'El título debe tener al menos 3 caracteres.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción opcional',
                        hintText: 'Ej. Después del desayuno',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: Text(dateText),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTime,
                            icon: const Icon(Icons.schedule_rounded),
                            label: Text(timeText),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    _SwitchCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Alarma activa',
                      subtitle:
                          'Sonará y vibrará usando la alarma del celular.',
                      value: _alarmEnabled,
                      onChanged: (value) {
                        setState(() => _alarmEnabled = value);
                      },
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveReminder,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving ? 'Guardando...' : 'Guardar recordatorio',
                        ),
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

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primaryButton),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}