import 'activity_summary_period.dart';

class ActivitySummaryReport {
  const ActivitySummaryReport({
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.memoramaUnlockedLevel,
    required this.brainSaysHighScore,
    required this.brainSaysHighLevel,
    required this.memoriesAdded,
    required this.remindersTotal,
    required this.remindersCompleted,
    required this.remindersPending,
    required this.emergenciesCount,
    required this.lastEmergencyAt,
    required this.lastActivityAt,
  });

  final String patientId;
  final String patientName;
  final String patientEmail;

  final ActivitySummaryPeriod period;
  final DateTime startDate;
  final DateTime endDate;

  final int memoramaUnlockedLevel;
  final int brainSaysHighScore;
  final int brainSaysHighLevel;

  final int memoriesAdded;

  final int remindersTotal;
  final int remindersCompleted;
  final int remindersPending;

  final int emergenciesCount;

  final DateTime? lastEmergencyAt;
  final DateTime? lastActivityAt;

  double get reminderProgress {
    if (remindersTotal == 0) return 0;
    return (remindersCompleted / remindersTotal).clamp(0.0, 1.0);
  }

  String get automaticSummary {
    final buffer = StringBuffer();

    buffer.write(
      'Durante el periodo de ${period.label.toLowerCase()}, $patientName ',
    );

    if (memoriesAdded > 0) {
      buffer.write('agregó $memoriesAdded recuerdos, ');
    } else {
      buffer.write('no agregó nuevos recuerdos, ');
    }

    if (remindersTotal > 0) {
      buffer.write(
        'completó $remindersCompleted de $remindersTotal recordatorios ',
      );
      buffer.write(
        'con un cumplimiento del ${(reminderProgress * 100).round()}%. ',
      );
    } else {
      buffer.write('no tuvo recordatorios registrados. ');
    }

    buffer.write(
      'En juegos de memoria tiene nivel $memoramaUnlockedLevel en Memorama',
    );

    if (brainSaysHighScore > 0) {
      buffer.write(
        ' y un récord de $brainSaysHighScore puntos en Secuencia de Colores. ',
      );
    } else {
      buffer.write('. ');
    }

    if (emergenciesCount == 0) {
      buffer.write('No se registraron emergencias en este periodo.');
    } else {
      buffer.write(
        'Se registraron $emergenciesCount emergencias en este periodo.',
      );
    }

    return buffer.toString();
  }

  String get motivationalMessage {
    if (emergenciesCount > 0) {
      return 'Se recomienda revisar las emergencias registradas y mantener seguimiento cercano.';
    }

    if (remindersTotal > 0 && reminderProgress >= 0.8) {
      return 'Excelente seguimiento. El paciente mantuvo una buena constancia durante este periodo.';
    }

    if (remindersTotal > 0 && reminderProgress >= 0.5) {
      return 'Buen avance. Puede mejorar un poco más la constancia con sus recordatorios.';
    }

    if (memoriesAdded > 0 || brainSaysHighScore > 0) {
      return 'Buen trabajo. La actividad registrada ayuda a mantener una rutina positiva.';
    }

    return 'Hubo poca actividad en este periodo. Se recomienda motivar al paciente a usar la aplicación con calma.';
  }

  String get periodRangeText {
    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}