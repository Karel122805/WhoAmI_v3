import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/reports/data/activity_summary_period.dart';
import 'package:whoami_app/src/features/reports/data/activity_summary_report.dart';
import 'package:whoami_app/src/features/reports/data/activity_summary_report_service.dart';
import 'package:whoami_app/src/features/reports/data/report_pdf_service.dart';

class ActivitySummaryReportPage extends StatefulWidget {
  const ActivitySummaryReportPage({
    super.key,
    required this.patientId,
  });

  static const route = '/activity-summary-report';

  final String patientId;

  @override
  State<ActivitySummaryReportPage> createState() =>
      _ActivitySummaryReportPageState();
}

class _ActivitySummaryReportPageState extends State<ActivitySummaryReportPage> {
  final ActivitySummaryReportService _service = ActivitySummaryReportService();

  final ReportPdfService _pdfService = ReportPdfService();

  ActivitySummaryPeriod _selectedPeriod = ActivitySummaryPeriod.week;
  late Future<ActivitySummaryReport> _futureReport;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    _futureReport = _service.getReport(
      patientId: widget.patientId,
      period: _selectedPeriod,
    );
  }

  Future<void> _refresh() async {
    setState(_loadReport);
    await _futureReport;
  }

  void _changePeriod(ActivitySummaryPeriod period) {
    if (_selectedPeriod == period) return;

    setState(() {
      _selectedPeriod = period;
      _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
  title: const Text('Resumen de actividad'),
  backgroundColor: colors.pageBackground,
  foregroundColor: colors.textPrimary,
  elevation: 0,
  actions: [
    FutureBuilder<ActivitySummaryReport>(
      future: _futureReport,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return IconButton(
          tooltip: 'Descargar PDF',
          icon: const Icon(Icons.picture_as_pdf_rounded),
          onPressed: () async {
            await _pdfService.generateAndOpenActivitySummaryPdf(
              report: snapshot.data!,
            );
          },
        );
      },
    ),
  ],
),
      body: FutureBuilder<ActivitySummaryReport>(
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
            debugPrint('ERROR RESUMEN ACTIVIDAD: ${snapshot.error}');
            debugPrint('STACK RESUMEN ACTIVIDAD: ${snapshot.stackTrace}');

            return _ErrorView(
              message: 'No se pudo cargar el resumen.\n${snapshot.error}',
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
                _PeriodSelector(
                  selectedPeriod: _selectedPeriod,
                  onChanged: _changePeriod,
                ),
                const SizedBox(height: 16),
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
                  title: 'Resumen automático',
                ),
                const SizedBox(height: 10),
                _AutomaticSummaryCard(report: report),
                const SizedBox(height: 16),
                _SectionTitle(
                  icon: Icons.favorite_rounded,
                  title: 'Recomendación',
                ),
                const SizedBox(height: 10),
                _MotivationalCard(report: report),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  final ActivitySummaryPeriod selectedPeriod;
  final ValueChanged<ActivitySummaryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: ActivitySummaryPeriod.values.map((period) {
          final selected = period == selectedPeriod;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? colors.primaryButton : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  period.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? colors.primaryButtonText
                        : colors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.report,
  });

  final ActivitySummaryReport report;

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
                  '${report.period.label}: ${report.periodRangeText}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

  final ActivitySummaryReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: [
        _MetricCard(
          icon: Icons.photo_album_rounded,
          label: 'Recuerdos nuevos',
          value: '${report.memoriesAdded}',
          color: colors.categoryGreen,
        ),
        _MetricCard(
          icon: Icons.notifications_active_rounded,
          label: 'Recordatorios',
          value: '${report.remindersTotal}',
          color: colors.categoryYellow,
        ),
        _MetricCard(
          icon: Icons.check_circle_rounded,
          label: 'Completados',
          value: '${report.remindersCompleted}',
          color: colors.categoryBlue,
        ),
        _MetricCard(
          icon: Icons.warning_amber_rounded,
          label: 'Emergencias',
          value: '${report.emergenciesCount}',
          color: colors.emergency,
        ),
      ],
    );
  }
}

class _GamesSection extends StatelessWidget {
  const _GamesSection({
    required this.report,
  });

  final ActivitySummaryReport report;

  @override
  Widget build(BuildContext context) {
    final memoramaProgress =
        (report.memoramaUnlockedLevel / 3).clamp(0.0, 1.0);

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
            value: memoramaProgress,
            percentText: '${(memoramaProgress * 100).round().clamp(0, 100)}%',
          ),
          const SizedBox(height: 18),
          _ProgressRow(
            icon: Icons.palette_rounded,
            title: 'Secuencia de colores',
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

  final ActivitySummaryReport report;

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
                  value: '${report.remindersTotal}',
                  icon: Icons.event_note_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  label: 'Completados',
                  value: '${report.remindersCompleted}',
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallStat(
                  label: 'Pendientes',
                  value: '${report.remindersPending}',
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
                '${report.remindersCompleted} de ${report.remindersTotal} recordatorios completados',
            value: report.reminderProgress,
            percentText:
                '${(report.reminderProgress * 100).round().clamp(0, 100)}%',
          ),
          const SizedBox(height: 18),
          _SmallStat(
            label: 'Recuerdos agregados en el periodo',
            value: '${report.memoriesAdded}',
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

  final ActivitySummaryReport report;

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

  final ActivitySummaryReport report;

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

class _MotivationalCard extends StatelessWidget {
  const _MotivationalCard({
    required this.report,
  });

  final ActivitySummaryReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return _ReportCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.favorite_rounded,
            color: colors.categoryPink,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              report.motivationalMessage,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          icon,
          color: color,
          size: 30,
        ),

        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
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
