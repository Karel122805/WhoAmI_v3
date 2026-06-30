import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/reports/data/patient_progress_report.dart';
import 'package:whoami_app/src/features/reports/data/patient_progress_report_service.dart';

class PatientProgressReportPage extends StatefulWidget {
  const PatientProgressReportPage({
    super.key,
    required this.patientId,
  });

  static const route = '/patient-progress-report';

  final String patientId;

  @override
  State<PatientProgressReportPage> createState() =>
      _PatientProgressReportPageState();
}

class _PatientProgressReportPageState extends State<PatientProgressReportPage> {
  final PatientProgressReportService _service = PatientProgressReportService();

  late Future<PatientProgressReport> _futureReport;

  @override
  void initState() {
    super.initState();
    _futureReport = _service.getReport(patientId: widget.patientId);
  }

  Future<void> _refresh() async {
    setState(() {
      _futureReport = _service.getReport(patientId: widget.patientId);
    });

    await _futureReport;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: const Text('Reporte de avances'),
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: FutureBuilder<PatientProgressReport>(
        future: _futureReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colors.primaryButton,
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: 'No se pudo cargar el reporte.',
              onRetry: _refresh,
            );
          }

          final report = snapshot.data;

          if (report == null) {
            return _ErrorView(
              message: 'No hay información disponible.',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: colors.primaryButton,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                _PatientHeader(report: report),
                const SizedBox(height: 16),
                _SummaryCard(report: report),
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.psychology_alt_rounded,
                  title: 'Juegos de memoria',
                ),
                const SizedBox(height: 10),
                _GamesSection(report: report),
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.calendar_month_rounded,
                  title: 'Recuerdos y recordatorios',
                ),
                const SizedBox(height: 10),
                _RemindersSection(report: report),
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.warning_amber_rounded,
                  title: 'Emergencias',
                ),
                const SizedBox(height: 10),
                _EmergenciesSection(report: report),
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.auto_graph_rounded,
                  title: 'Diagnóstico general',
                ),
                const SizedBox(height: 10),
                _AutomaticSummaryCard(report: report),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.report,
  });

  final PatientProgressReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: context.isDark
            ? []
            : [
                BoxShadow(
                  color: colors.textPrimary.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: colors.primaryButton.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: colors.primaryButtonText,
              size: 36,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.patientName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (report.patientEmail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.patientEmail,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Última actividad: ${_formatDate(report.lastActivityAt)}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.report,
  });

  final PatientProgressReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _MetricCard(
          icon: Icons.extension_rounded,
          label: 'Memorama',
          value: 'Nivel ${report.memoramaUnlockedLevel}/3',
          color: colors.categoryBlue,
        ),
        _MetricCard(
          icon: Icons.palette_rounded,
          label: 'Secuencia',
          value: '${report.brainSaysHighScore} pts',
          color: colors.categoryPurple,
        ),
        _MetricCard(
          icon: Icons.photo_album_rounded,
          label: 'Recuerdos',
          value: '${report.memoriesCount}',
          color: colors.categoryGreen,
        ),
        _MetricCard(
          icon: Icons.notifications_active_rounded,
          label: 'Recordatorios',
          value: '${report.remindersCount}',
          color: colors.categoryYellow,
        ),
      ],
    );
  }
}

class _GamesSection extends StatelessWidget {
  const _GamesSection({
    required this.report,
  });

  final PatientProgressReport report;

  @override
  Widget build(BuildContext context) {
    final brainProgress = report.brainSaysHighScore <= 0
        ? 0.0
        : (report.brainSaysHighScore / 20).clamp(0.0, 1.0);

    return _ReportCard(
      child: Column(
        children: [
          _ProgressRow(
            icon: Icons.extension_rounded,
            title: 'Memorama',
            subtitle: 'Nivel alcanzado: ${report.memoramaUnlockedLevel} de 3',
            value: report.memoramaProgress,
            percentText:
                '${(report.memoramaProgress * 100).round().clamp(0, 100)}%',
          ),
          const SizedBox(height: 18),
          _ProgressRow(
            icon: Icons.palette_rounded,
            title: 'Secuencia',
            subtitle:
                'Récord: ${report.brainSaysHighScore} puntos · Nivel ${report.brainSaysHighLevel}',
            value: brainProgress,
            percentText: '${(brainProgress * 100).round().clamp(0, 100)}%',
          ),
        ],
      ),
    );
  }
}

class _RemindersSection extends StatelessWidget {
  const _RemindersSection({
    required this.report,
  });

  final PatientProgressReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  label: 'Registrados',
                  value: '${report.remindersCount}',
                  icon: Icons.event_note_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  label: 'Completados',
                  value: '${report.completedRemindersCount}',
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  label: 'Pendientes',
                  value: '${report.pendingRemindersCount}',
                  icon: Icons.pending_actions_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressRow(
            icon: Icons.task_alt_rounded,
            title: 'Cumplimiento',
            subtitle:
                '${report.completedRemindersCount} de ${report.remindersCount} recordatorios completados',
            value: report.reminderProgress,
            percentText:
                '${(report.reminderProgress * 100).round().clamp(0, 100)}%',
          ),
          const SizedBox(height: 18),
          _SmallStat(
            label: 'Recuerdos registrados',
            value: '${report.memoriesCount}',
            icon: Icons.photo_album_rounded,
          ),
        ],
      ),
    );
  }
}

class _EmergenciesSection extends StatelessWidget {
  const _EmergenciesSection({
    required this.report,
  });

  final PatientProgressReport report;

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: Column(
        children: [
          _SmallStat(
            label: 'Emergencias registradas',
            value: '${report.emergenciesCount}',
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.schedule_rounded,
            label: 'Última emergencia',
            value: _formatDate(report.lastEmergencyAt),
          ),
        ],
      ),
    );
  }
}

class _AutomaticSummaryCard extends StatelessWidget {
  const _AutomaticSummaryCard({
    required this.report,
  });

  final PatientProgressReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _ReportCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.tips_and_updates_rounded,
            color: colors.primaryButton,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              report.automaticSummary,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: context.isDark
            ? []
            : [
                BoxShadow(
                  color: colors.textPrimary.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.percentText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final String percentText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.primaryButton.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: colors.primaryButtonText,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    percentText,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: colors.border.withOpacity(0.45),
                  color: colors.primaryButton,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.isDark ? colors.inputFill : colors.chipBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: colors.primaryButton,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.isDark ? colors.inputFill : colors.chipBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colors.primaryButton,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        Icon(
          icon,
          color: colors.primaryButton,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colors.emergency,
              size: 54,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Sin registro';

  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) return 'Ahora';
  if (difference.inMinutes < 60) {
    return 'Hace ${difference.inMinutes} min';
  }
  if (difference.inHours < 24) {
    return 'Hace ${difference.inHours} h';
  }
  if (difference.inDays == 1) return 'Ayer';
  if (difference.inDays < 7) {
    return 'Hace ${difference.inDays} días';
  }

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();

  return '$day/$month/$year';
}