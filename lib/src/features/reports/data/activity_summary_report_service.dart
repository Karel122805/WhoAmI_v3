import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whoami_app/src/features/reports/data/activity_summary_period.dart';
import 'package:whoami_app/src/features/reports/data/activity_summary_report.dart';
import 'package:whoami_app/src/features/reports/data/patient_progress_report.dart';

class ActivitySummaryReportService {
  ActivitySummaryReportService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<ActivitySummaryReport> getReport({
    required String patientId,
    required ActivitySummaryPeriod period,
  }) async {
    final startDate = period.startDate;
    final endDate = period.endDate;

    final userDoc = await _firestore.collection('users').doc(patientId).get();
    final userData = userDoc.data() ?? {};

    final patientName = _readName(userData);
    final patientEmail = (userData['email'] ?? '').toString();

    final memoramaUnlockedLevel =
        _readInt(userData['memoramaUnlockedLevel'], fallback: 1);

    final brainSaysHighScore =
        _readInt(userData['brainSaysHighScore'], fallback: 0);

    final brainSaysHighLevel =
        _readInt(userData['brainSaysHighLevel'], fallback: 0);

    final lastActivityAt = dateFromFirestore(userData['updatedAt']);

    final memoriesAdded = await _countMemoriesAdded(
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
    );

    final remindersData = await _countReminders(
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
    );

    final emergenciesData = await _countEmergencies(
      patientId: patientId,
      startDate: startDate,
      endDate: endDate,
    );

    return ActivitySummaryReport(
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      period: period,
      startDate: startDate,
      endDate: endDate,
      memoramaUnlockedLevel: memoramaUnlockedLevel,
      brainSaysHighScore: brainSaysHighScore,
      brainSaysHighLevel: brainSaysHighLevel,
      memoriesAdded: memoriesAdded,
      remindersTotal: remindersData.total,
      remindersCompleted: remindersData.completed,
      remindersPending: remindersData.pending,
      emergenciesCount: emergenciesData.count,
      lastEmergencyAt: emergenciesData.lastEmergencyAt,
      lastActivityAt: lastActivityAt,
    );
  }

  String _readName(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString().trim();
    final fullName = (data['fullName'] ?? '').toString().trim();
    final displayName = (data['displayName'] ?? '').toString().trim();
    final firstName = (data['firstName'] ?? '').toString().trim();
    final lastName = (data['lastName'] ?? '').toString().trim();

    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (displayName.isNotEmpty) return displayName;

    final completeName = '$firstName $lastName'.trim();
    if (completeName.isNotEmpty) return completeName;

    return 'Paciente';
  }

  int _readInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return fallback;
  }

  bool _isInRange(DateTime? date, DateTime startDate, DateTime endDate) {
    if (date == null) return false;
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }

  DateTime? _readBestDate(Map<String, dynamic> data) {
    return dateFromFirestore(data['createdAt']) ??
        dateFromFirestore(data['date']) ??
        dateFromFirestore(data['displayDate']) ??
        dateFromFirestore(data['reminderAt']) ??
        dateFromFirestore(data['scheduledAt']) ??
        dateFromFirestore(data['completedAt']) ??
        dateFromFirestore(data['updatedAt']) ??
        dateFromFirestore(data['timestamp']);
  }

  Future<int> _countMemoriesAdded({
    required String patientId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection('memories')
        .doc(patientId)
        .collection('user_memories')
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = _readBestDate(data);

      if (_isInRange(date, startDate, endDate)) {
        count++;
      }
    }

    return count;
  }

  Future<_ReminderReportData> _countReminders({
    required String patientId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: patientId)
        .get();

    int total = 0;
    int completed = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final reminderDate = _readBestDate(data);
      final completedAt = dateFromFirestore(data['completedAt']);
      final updatedAt = dateFromFirestore(data['updatedAt']);

      final isCompleted = data['completed'] == true;

      final belongsToPeriod =
          _isInRange(reminderDate, startDate, endDate) ||
              _isInRange(completedAt, startDate, endDate) ||
              _isInRange(updatedAt, startDate, endDate);

      if (!belongsToPeriod) continue;

      total++;

      if (isCompleted) {
        completed++;
      }
    }

    final pending = (total - completed).clamp(0, total);

    return _ReminderReportData(
      total: total,
      completed: completed,
      pending: pending,
    );
  }

  Future<_EmergencyReportData> _countEmergencies({
    required String patientId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final byConsultant = await _firestore
        .collection('emergencies')
        .where('consultantId', isEqualTo: patientId)
        .get();

    final byPatient = await _firestore
        .collection('emergencies')
        .where('patientId', isEqualTo: patientId)
        .get();

    final byUser = await _firestore
        .collection('emergencies')
        .where('userId', isEqualTo: patientId)
        .get();

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique = {};

    for (final doc in byConsultant.docs) {
      unique[doc.id] = doc;
    }

    for (final doc in byPatient.docs) {
      unique[doc.id] = doc;
    }

    for (final doc in byUser.docs) {
      unique[doc.id] = doc;
    }

    int count = 0;
    DateTime? lastEmergency;

    for (final doc in unique.values) {
      final data = doc.data();

      final date = dateFromFirestore(data['triggeredAt']) ??
          dateFromFirestore(data['timestamp']) ??
          dateFromFirestore(data['createdAt']) ??
          dateFromFirestore(data['updatedAt']);

      if (!_isInRange(date, startDate, endDate)) continue;

      count++;

      if (date != null) {
        if (lastEmergency == null || date.isAfter(lastEmergency)) {
          lastEmergency = date;
        }
      }
    }

    return _EmergencyReportData(
      count: count,
      lastEmergencyAt: lastEmergency,
    );
  }
}

class _ReminderReportData {
  const _ReminderReportData({
    required this.total,
    required this.completed,
    required this.pending,
  });

  final int total;
  final int completed;
  final int pending;
}

class _EmergencyReportData {
  const _EmergencyReportData({
    required this.count,
    required this.lastEmergencyAt,
  });

  final int count;
  final DateTime? lastEmergencyAt;
}