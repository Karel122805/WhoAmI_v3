import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whoami_app/src/features/reports/data/patient_progress_report.dart';

class PatientProgressReportService {
  PatientProgressReportService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<PatientProgressReport> getReport({
    required String patientId,
  }) async {
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

    final memoriesCount = await _countMemories(patientId);
    final remindersCount = await _countReminders(patientId);
    final completedRemindersCount = await _countCompletedReminders(patientId);
    final pendingRemindersCount =
        (remindersCount - completedRemindersCount).clamp(0, remindersCount);

    final emergenciesData = await _countEmergencies(patientId);

    return PatientProgressReport(
      patientId: patientId,
      patientName: patientName,
      patientEmail: patientEmail,
      memoramaUnlockedLevel: memoramaUnlockedLevel,
      brainSaysHighScore: brainSaysHighScore,
      brainSaysHighLevel: brainSaysHighLevel,
      memoriesCount: memoriesCount,
      remindersCount: remindersCount,
      completedRemindersCount: completedRemindersCount,
      pendingRemindersCount: pendingRemindersCount,
      emergenciesCount: emergenciesData.count,
      lastEmergencyAt: emergenciesData.lastEmergencyAt,
      lastActivityAt: lastActivityAt,
    );
  }

  String _readName(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString().trim();
    final fullName = (data['fullName'] ?? '').toString().trim();
    final displayName = (data['displayName'] ?? '').toString().trim();

    if (name.isNotEmpty) return name;
    if (fullName.isNotEmpty) return fullName;
    if (displayName.isNotEmpty) return displayName;

    return 'Paciente';
  }

  int _readInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return fallback;
  }

  Future<int> _countMemories(String patientId) async {
    final snapshot = await _firestore
        .collection('memories')
        .doc(patientId)
        .collection('user_memories')
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<int> _countReminders(String patientId) async {
    final snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: patientId)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<int> _countCompletedReminders(String patientId) async {
    final snapshot = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: patientId)
        .where('completed', isEqualTo: true)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<_EmergencyReportData> _countEmergencies(String patientId) async {
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

    DateTime? lastEmergency;

    for (final doc in unique.values) {
      final data = doc.data();

      final date = dateFromFirestore(data['triggeredAt']) ??
          dateFromFirestore(data['timestamp']) ??
          dateFromFirestore(data['createdAt']) ??
          dateFromFirestore(data['updatedAt']);

      if (date == null) continue;

      if (lastEmergency == null || date.isAfter(lastEmergency)) {
        lastEmergency = date;
      }
    }

    return _EmergencyReportData(
      count: unique.length,
      lastEmergencyAt: lastEmergency,
    );
  }
}

class _EmergencyReportData {
  const _EmergencyReportData({
    required this.count,
    required this.lastEmergencyAt,
  });

  final int count;
  final DateTime? lastEmergencyAt;
}