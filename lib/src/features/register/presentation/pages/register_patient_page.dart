// lib/src/ui/screens/register_patient_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:whoami_app/src/features/patients/data/patients_service.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

class RegisterPatientPage extends StatefulWidget {
  const RegisterPatientPage({super.key});
  static const route = '/patients/register';

  @override
  State<RegisterPatientPage> createState() => _RegisterPatientPageState();
}

class _RegisterPatientPageState extends State<RegisterPatientPage> {
  final _searchCtrl = TextEditingController();
  late final PatientsService _svc;

  String? get caregiverId => FirebaseAuth.instance.currentUser?.uid;
  String? _selectedPatientId;
  bool _saving = false;

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

  Future<void> _savePatient() async {
  if (_selectedPatientId == null || caregiverId == null || _saving) {
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colors = ctx.appColors;

      return AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Enviar solicitud',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Se enviará una solicitud al consultante para solicitar su autorización.\n\n'
          'Si el consultante acepta, aparecerá automáticamente en tu lista de pacientes y podrás consultar la información que haya decidido compartir.',
          style: TextStyle(
            color: colors.textPrimary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Enviar solicitud',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirm != true) {
    return;
  }

  setState(() => _saving = true);

  try {
    await _svc.addPatientToCaregiver(
      caregiverId: caregiverId!,
      patientUserId: _selectedPatientId!,
    );

    if (!mounted) return;

    await _showResultDialog(
      context,
      'Solicitud enviada',
      'La solicitud fue enviada correctamente.\n\n'
      'Cuando el consultante la acepte, aparecerá automáticamente en tu lista de pacientes.',
      closePageOnAccept: true,
    );
  } catch (e) {
    if (!mounted) return;

    await _showResultDialog(
      context,
      'Error',
      e.toString(),
    );
  } finally {
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (caregiverId == null) {
      return Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: AppBar(
          backgroundColor: colors.pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () => Navigator.maybePop(context),
          ),
          centerTitle: true,
          title: Text(
            'Regístrate',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Inicia sesión para continuar',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final q = _searchCtrl.text.trim();

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: Text(
          'Registrar nuevo paciente',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 18),

                  TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar consultante',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: colors.textSecondary),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : Icon(Icons.search, color: colors.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      stream: _svc.streamUnassignedConsultants(q: q),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snap.error}',
                              style: TextStyle(color: colors.textPrimary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        if (snap.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: colors.primaryButton,
                            ),
                          );
                        }

                        final docs = (snap.data ?? [])
                            .where((doc) => (doc.data()['role'] ?? '') == 'Consultante')
                            .toList();

                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              'Sin resultados',
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
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final data = docs[i].data();
                            final uid = docs[i].id;

                            final name = (data['displayName'] ??
                                    '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
                                .toString()
                                .trim();

                            final birthday = _fmtBirthday(data['birthday']);

                            return _PatientResultTile(
                              name: name.isEmpty ? 'Usuario' : name,
                              subtitle: birthday,
                              selected: uid == _selectedPatientId,
                              onAdd: () {
                                setState(() {
                                  _selectedPatientId = uid;
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              (_selectedPatientId == null || _saving) ? null : _savePatient,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primaryButton,
                            foregroundColor: colors.primaryButtonText,
                            disabledBackgroundColor:
                                colors.primaryButton.withValues(alpha: 0.45),
                            disabledForegroundColor:
                                colors.primaryButtonText.withValues(alpha: 0.75),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primaryButtonText,
                                  ),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(
                            _saving ? 'Guardando…' : 'Guardar',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.emergency,
                            foregroundColor: colors.emergencyText,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showResultDialog(
    BuildContext context,
    String title,
    String message, {
    bool closePageOnAccept = false,
  }) async {
    final colors = context.appColors;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                if (closePageOnAccept) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Aceptar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientResultTile extends StatelessWidget {
  const _PatientResultTile({
    required this.name,
    required this.subtitle,
    required this.onAdd,
    required this.selected,
  });

  final String name;
  final String subtitle;
  final VoidCallback onAdd;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryButton.withValues(alpha: 0.18)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.primaryButton : colors.border,
            width: selected ? 2 : 1,
          ),
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.check_circle,
              color: selected ? colors.primaryButton : colors.border,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}





