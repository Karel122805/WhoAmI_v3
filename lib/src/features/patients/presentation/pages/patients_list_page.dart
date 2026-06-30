import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/patients/data/patients_service.dart';
import 'package:whoami_app/src/features/patients/presentation/pages/patient_profile_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_patient_page.dart';
import 'package:whoami_app/src/features/reports/presentation/patient_progress_report_page.dart';

class PatientsListPage extends StatefulWidget {
  const PatientsListPage({super.key});
  static const route = '/patients/list';

  @override
  State<PatientsListPage> createState() => _PatientsListPageState();
}

class _PatientsListPageState extends State<PatientsListPage> {
  final _searchCtrl = TextEditingController();
  late final PatientsService _svc;

  String get caregiverId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _svc = PatientsService(FirebaseFirestore.instance);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtBirthday(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      final yy = d.year.toString();
      return '$dd/$mm/$yy';
    }

    if (value is String && value.isNotEmpty) return value;

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final q = _searchCtrl.text.trim().toLowerCase();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1),
      ),
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Lista de pacientes',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: colors.pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back,
              color: colors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(color: colors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Buscar',
                              hintStyle: TextStyle(color: colors.textSecondary),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: colors.textSecondary,
                                      ),
                                      onPressed: () => _searchCtrl.clear(),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.secondaryButton,
                            foregroundColor: colors.secondaryButtonText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              RegisterPatientPage.route,
                            );

                            if (result == true && mounted) {
                              await showDialog(
                                context: context,
                                builder: (ctx) => const _SuccessDialog(
                                  title: 'Hecho',
                                  message: 'Paciente agregado correctamente.',
                                ),
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.add, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<
                          List<DocumentSnapshot<Map<String, dynamic>>>>(
                        stream: _svc.streamPatientsOfCaregiver(caregiverId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: colors.primaryButton,
                              ),
                            );
                          }

                          if (snap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Error: ${snap.error}',
                                  style: TextStyle(color: colors.textPrimary),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          var docs = (snap.data ?? [])
                              .where(
                                (d) =>
                                    (d.data()?['role'] ?? '') == 'Consultante',
                              )
                              .toList();

                          docs.sort((a, b) {
                            String n(DocumentSnapshot<Map<String, dynamic>> x) {
                              final m = x.data() ?? {};
                              return (m['displayName'] ??
                                      '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}')
                                  .toString()
                                  .toLowerCase()
                                  .trim();
                            }

                            return n(a).compareTo(n(b));
                          });

                          if (q.isNotEmpty) {
                            docs = docs.where((d) {
                              final data = d.data() ?? {};
                              final name = ((data['displayName'] ??
                                          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                                      .toString()
                                      .toLowerCase())
                                  .trim();

                              return name.contains(q);
                            }).toList();
                          }

                          if (docs.isEmpty) {
                            return Center(
                              child: Text(
                                'Sin pacientes',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final data = docs[i].data() ?? {};
                              final patientId = docs[i].id;

                              final name = (data['displayName'] ??
                                      '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                                  .toString()
                                  .trim();

                              final birthday = _fmtBirthday(
                                data['birthday'] ?? data['birthDate'],
                              );

                              return _PatientRow(
                                patientId: patientId,
                                name: name.isEmpty ? 'Usuario' : name,
                                subtitle: birthday,
                                onViewProfile: () {
                                  Navigator.pushNamed(
                                    context,
                                    PatientProfilePage.route,
                                    arguments: {
                                      'patientId': patientId,
                                    },
                                  );
                                },
                                onViewReport: () {
                                  Navigator.pushNamed(
                                    context,
                                    PatientProgressReportPage.route,
                                    arguments: {
                                      'patientId': patientId,
                                    },
                                  );
                                },
                                onRemove: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => _ConfirmRemoveDialog(
                                      name: name.isEmpty ? 'Usuario' : name,
                                    ),
                                  );

                                  if (ok != true) return;

                                  try {
                                    await _svc.removePatientFromCaregiver(
                                      caregiverId: caregiverId,
                                      patientUserId: patientId,
                                    );

                                    if (mounted) {
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => const _SuccessDialog(
                                          title: 'Hecho',
                                          message: 'Paciente desvinculado.',
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => _SuccessDialog(
                                          title: 'Error',
                                          message: e.toString(),
                                        ),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          );
                        },
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

class _ConfirmRemoveDialog extends StatelessWidget {
  const _ConfirmRemoveDialog({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Desvincular paciente',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        '¿Quitar a "$name" de tu lista?\nPodrás vincularlo de nuevo después.',
        style: TextStyle(color: colors.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: TextStyle(
              color: colors.secondaryButton,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular'),
          ),
        ),
      ],
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(color: colors.textPrimary),
      ),
      actions: [
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ),
      ],
    );
  }
}

class _PatientRow extends StatefulWidget {
  const _PatientRow({
    required this.patientId,
    required this.name,
    required this.subtitle,
    required this.onViewProfile,
    required this.onViewReport,
    required this.onRemove,
  });

  final String patientId;
  final String name;
  final String subtitle;
  final VoidCallback onViewProfile;
  final VoidCallback onViewReport;
  final Future<void> Function() onRemove;

  @override
  State<_PatientRow> createState() => _PatientRowState();
}

class _PatientRowState extends State<_PatientRow> {
  bool _busy = false;

  Future<void> _handleRemove() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await widget.onRemove();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: context.isDark
            ? []
            : [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.inputFill,
                child: Icon(
                  Icons.person_outline,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle.isEmpty
                          ? 'Sin fecha de nacimiento'
                          : widget.subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.onViewReport,
            icon: const Icon(Icons.auto_graph_rounded),
            label: const Text('Ver reporte de avances'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onViewProfile,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver perfil'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: colors.primaryButton,
                    foregroundColor: colors.primaryButtonText,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _handleRemove,
                  icon: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.emergencyText,
                          ),
                        )
                      : const Icon(Icons.link_off),
                  label: Text(_busy ? 'Quitando...' : 'Desvincular'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: colors.emergency,
                    foregroundColor: colors.emergencyText,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}