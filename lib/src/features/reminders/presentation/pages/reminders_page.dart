import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_feedback_dialog.dart';

import '../../domain/entities/reminder.dart';
import '../providers/reminder_provider.dart';
import 'reminder_form_page.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      context.read<ReminderProvider>().watchReminders(user.uid);
    }
  }

  Future<void> _openForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReminderFormPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: const Text('Recordatorios'),
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = provider.pendingReminders;
          final expired = provider.expiredReminders;
          final completed = provider.completedReminders;

          return RefreshIndicator(
            onRefresh: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                context.read<ReminderProvider>().watchReminders(user.uid);
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _HeaderCard(
                  pendingCount: pending.length,
                  expiredCount: expired.length,
                ),

                const SizedBox(height: 20),

                _SectionTitle(
                  title: 'Próximos',
                  count: pending.length,
                ),

                const SizedBox(height: 12),

                if (pending.isEmpty)
                  const _EmptyCard(text: 'No tienes recordatorios próximos.')
                else
                  ...pending.map(
                    (reminder) => _ReminderCard(reminder: reminder),
                  ),

                const SizedBox(height: 24),

                _SectionTitle(
                  title: 'Vencidos',
                  count: expired.length,
                ),

                const SizedBox(height: 12),

                if (expired.isEmpty)
                  const _EmptyCard(text: 'No tienes recordatorios vencidos.')
                else
                  ...expired.map(
                    (reminder) => _ReminderCard(reminder: reminder),
                  ),

                const SizedBox(height: 24),

                _SectionTitle(
                  title: 'Completados',
                  count: completed.length,
                ),

                const SizedBox(height: 12),

                if (completed.isEmpty)
                  const _EmptyCard(
                    text: 'Aún no has completado recordatorios.',
                  )
                else
                  ...completed.map(
                    (reminder) => _ReminderCard(reminder: reminder),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primaryButton,
        foregroundColor: colors.primaryButtonText,
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo'),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.pendingCount,
    required this.expiredCount,
  });

  final int pendingCount;
  final int expiredCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.elevatedCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.categoryPurple,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.alarm_rounded,
              color: colors.textPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pendingCount alarmas próximas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  expiredCount == 0
                      ? 'Todo está en orden.'
                      : '$expiredCount alarmas vencidas.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.count,
  });

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.chipBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
  });

  final Reminder reminder;

  Future<void> _complete(BuildContext context) async {
    final ok = await context.read<ReminderProvider>().complete(reminder.id);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AppFeedbackDialog(
        type: ok ? FeedbackDialogType.success : FeedbackDialogType.error,
        title: ok ? 'Completado' : 'Error',
        message: ok
            ? 'La alarma fue marcada como completada.'
            : 'No se pudo completar la alarma.',
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AppFeedbackDialog(
            type: FeedbackDialogType.warning,
            title: 'Eliminar alarma',
            message: '¿Seguro que deseas eliminar esta alarma?',
            buttonText: 'Eliminar',
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
        ) ??
        false;

    if (!confirm) return;

    final ok = await context.read<ReminderProvider>().delete(reminder.id);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AppFeedbackDialog(
        type: ok ? FeedbackDialogType.success : FeedbackDialogType.error,
        title: ok ? 'Eliminada' : 'Error',
        message:
            ok ? 'La alarma fue eliminada.' : 'No se pudo eliminar la alarma.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final date = reminder.dateTime;

    final isExpired =
        !reminder.completed && reminder.dateTime.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: reminder.completed
              ? colors.categoryGreen
              : isExpired
                  ? colors.emergency
                  : colors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                reminder.completed
                    ? Icons.check_circle_rounded
                    : isExpired
                        ? Icons.warning_rounded
                        : Icons.alarm_rounded,
                color: reminder.completed
                    ? colors.categoryGreen
                    : isExpired
                        ? colors.emergency
                        : colors.primaryButton,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (reminder.description != null &&
                        reminder.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reminder.description!.trim(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '${date.day}/${date.month}/${date.year}  '
                      '${date.hour.toString().padLeft(2, '0')}:'
                      '${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              if (!reminder.completed)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _complete(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Completar'),
                  ),
                ),

              if (!reminder.completed) const SizedBox(width: 10),

              IconButton(
                onPressed: () => _delete(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.emergency,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}