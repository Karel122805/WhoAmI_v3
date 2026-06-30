import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/reports/presentation/activity_summary_report_page.dart';
import 'package:whoami_app/src/features/reports/presentation/patient_progress_report_page.dart';

class PatientProfilePage extends StatelessWidget {
  const PatientProfilePage({
    super.key,
    required this.patientId,
  });

  static const route = '/patients/profile';

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Perfil del paciente',
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
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: colors.primaryButton,
                ),
              );
            }

            if (snapshot.hasError) {
              return const _MessageView(
                icon: Icons.error_outline,
                message: 'No se pudo cargar el perfil del paciente.',
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const _MessageView(
                icon: Icons.person_off_outlined,
                message: 'El paciente no existe o fue eliminado.',
              );
            }

            final data = snapshot.data!.data() ?? {};
            final medicalInfo = data['medicalInfo'] is Map
                ? Map<String, dynamic>.from(data['medicalInfo'])
                : <String, dynamic>{};

            final firstName = _safe(data['firstName']);
            final lastName = _safe(data['lastName']);
            final displayName = _safe(data['displayName']).isNotEmpty
                ? _safe(data['displayName'])
                : '$firstName $lastName'.trim();

            final photoUrl = _safe(data['photoURL']);
            final email = _safe(data['email']);
            final phone = _safe(data['phone']);
            final address = _safe(data['address']);
            final gender = _safe(data['gender']);

            final birthDate = _parseDate(
              data['birthDate'] ?? data['birthday'],
            );

            final age = _calculateAge(birthDate);

            final diagnosis = _safe(medicalInfo['diagnosis']);
            final stage = _safe(medicalInfo['stage']);
            final bloodType = _safe(medicalInfo['bloodType']);
            final allergies = _safe(medicalInfo['allergies']);
            final medications = _safe(medicalInfo['medications']);
            final doctorName = _safe(medicalInfo['doctorName']);
            final doctorPhone = _safe(medicalInfo['doctorPhone']);
            final notes = _safe(medicalInfo['notes']);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderCard(
                        name: displayName.isEmpty ? 'Paciente' : displayName,
                        photoUrl: photoUrl,
                        age: age,
                        email: email,
                      ),
                      const SizedBox(height: 14),
                      _PatientActionsCard(
                        patientId: patientId,
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Información personal',
                        icon: Icons.person_outline,
                        children: [
                          _InfoItem(
                            label: 'Nombre completo',
                            value: displayName,
                          ),
                          _InfoItem(
                            label: 'Edad',
                            value: age == null ? '' : '$age años',
                          ),
                          _InfoItem(
                            label: 'Fecha de nacimiento',
                            value: _formatDate(birthDate),
                          ),
                          _InfoItem(
                            label: 'Sexo',
                            value: gender,
                          ),
                          _InfoItem(
                            label: 'Correo',
                            value: email,
                          ),
                          _InfoItem(
                            label: 'Teléfono',
                            value: phone,
                          ),
                          _InfoItem(
                            label: 'Dirección',
                            value: address,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Información médica',
                        icon: Icons.medical_information_outlined,
                        children: [
                          _InfoItem(
                            label: 'Diagnóstico principal',
                            value: diagnosis,
                          ),
                          _InfoItem(
                            label: 'Etapa o estado',
                            value: stage,
                          ),
                          _InfoItem(
                            label: 'Tipo de sangre',
                            value: bloodType,
                          ),
                          _InfoItem(
                            label: 'Alergias',
                            value: allergies,
                          ),
                          _InfoItem(
                            label: 'Medicamentos actuales',
                            value: medications,
                          ),
                          _InfoItem(
                            label: 'Médico tratante',
                            value: doctorName,
                          ),
                          _InfoItem(
                            label: 'Teléfono del médico',
                            value: doctorPhone,
                          ),
                          _InfoItem(
                            label: 'Notas importantes',
                            value: notes,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _ReadOnlyNotice(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _safe(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        final parts = value.split('/');

        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);

          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    }

    return null;
  }

  static int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;

    final alreadyHadBirthday = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);

    if (!alreadyHadBirthday) {
      age--;
    }

    if (age < 0) return null;

    return age;
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.name,
    required this.photoUrl,
    required this.age,
    required this.email,
  });

  final String name;
  final String photoUrl;
  final int? age;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasPhoto = photoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: context.isDark
            ? []
            : [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: colors.inputFill,
            backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
            child: hasPhoto
                ? null
                : Icon(
                    Icons.person,
                    size: 46,
                    color: colors.textSecondary,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            age == null ? 'Edad no registrada' : '$age años',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientActionsCard extends StatelessWidget {
  const _PatientActionsCard({
    required this.patientId,
  });

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryButton.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.primaryButton.withValues(alpha: 0.45),
          width: 1.4,
        ),
        boxShadow: context.isDark
            ? []
            : [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryButton,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: colors.primaryButtonText,
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reportes y registros',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Consulta el avance general del paciente o revisa sus registros por periodo.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context,
                PatientProgressReportPage.route,
                arguments: {
                  'patientId': patientId,
                },
              );
            },
            icon: const Icon(Icons.auto_graph_rounded),
            label: const Text('Ver reporte de avances'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: context.isDark ? 0 : 2,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                ActivitySummaryReportPage.route,
                arguments: {
                  'patientId': patientId,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: context.isDark ? 0 : 4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  color: colors.secondaryButtonText,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registros por periodo'),
                      SizedBox(height: 3),
                      Text(
                        'Última semana · 15 días · Último mes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.secondaryButtonText,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primaryButton),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = value.trim().isEmpty ? 'Información no registrada' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                color: value.trim().isEmpty
                    ? colors.textSecondary
                    : colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryButton.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.secondaryButton.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            color: colors.textPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Este perfil es solo de consulta. La información solo puede ser editada desde la cuenta del paciente.',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 58,
              color: colors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}