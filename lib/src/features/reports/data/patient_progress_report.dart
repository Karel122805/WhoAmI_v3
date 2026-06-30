import 'package:cloud_firestore/cloud_firestore.dart';

class PatientProgressReport {
  const PatientProgressReport({
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.memoramaUnlockedLevel,
    required this.brainSaysHighScore,
    required this.brainSaysHighLevel,
    required this.memoriesCount,
    required this.remindersCount,
    required this.completedRemindersCount,
    required this.pendingRemindersCount,
    required this.emergenciesCount,
    required this.lastEmergencyAt,
    required this.lastActivityAt,
  });

  final String patientId;
  final String patientName;
  final String patientEmail;

  final int memoramaUnlockedLevel;
  final int brainSaysHighScore;
  final int brainSaysHighLevel;

  final int memoriesCount;
  final int remindersCount;
  final int completedRemindersCount;
  final int pendingRemindersCount;

  final int emergenciesCount;

  final DateTime? lastEmergencyAt;
  final DateTime? lastActivityAt;

  double get memoramaProgress {
    return (memoramaUnlockedLevel / 3).clamp(0.0, 1.0);
  }

  double get reminderProgress {
    if (remindersCount == 0) return 0;
    return (completedRemindersCount / remindersCount).clamp(0.0, 1.0);
  }

  String get automaticSummary {
    final buffer = StringBuffer();

    buffer.write('$patientName ha alcanzado el nivel ');
    buffer.write('$memoramaUnlockedLevel en Memorama');

    if (brainSaysHighScore > 0) {
      buffer.write(' y tiene un récord de $brainSaysHighScore puntos en Secuencia');
    }

    buffer.write('. ');

    if (remindersCount > 0) {
      buffer.write(
        'Ha completado $completedRemindersCount de $remindersCount recordatorios. ',
      );
    } else {
      buffer.write('Aún no tiene recordatorios registrados. ');
    }

    if (emergenciesCount == 0) {
      buffer.write('No se han registrado emergencias.');
    } else {
      buffer.write('Se han registrado $emergenciesCount emergencias.');
    }

    return buffer.toString();
  }

  factory PatientProgressReport.empty({
    required String patientId,
    required String patientName,
    required String patientEmail,
  }) {
    return PatientProgressReport(
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      memoramaUnlockedLevel: 1,
      brainSaysHighScore: 0,
      brainSaysHighLevel: 0,
      memoriesCount: 0,
      remindersCount: 0,
      completedRemindersCount: 0,
      pendingRemindersCount: 0,
      emergenciesCount: 0,
      lastEmergencyAt: null,
      lastActivityAt: null,
    );
  }
}

DateTime? dateFromFirestore(dynamic value) {
  if (value == null) return null;

  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}