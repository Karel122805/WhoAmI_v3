// lib/src/features/patients/data/patients_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PatientsService {
  PatientsService(this._db);

  final FirebaseFirestore _db;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamUnassignedConsultants({String q = ''}) {
    final col = _db
        .collection('users')
        .where('role', isEqualTo: 'Consultante')
        .limit(100);

    return col.snapshots().map((snap) {
      var docs = snap.docs.where((d) {
        final data = d.data();
        final caregiverId = data['caregiverId'];

        return caregiverId == null ||
            caregiverId.toString().trim().isEmpty;
      }).toList();

      if (q.trim().isNotEmpty) {
        final lower = q.trim().toLowerCase();

        docs = docs.where((d) {
          final data = d.data();

          final displayName = (
            data['displayName'] ??
                '${data['firstName'] ?? ''} '
                    '${data['lastName'] ?? ''}'
          )
              .toString()
              .toLowerCase()
              .trim();

          return displayName.contains(lower);
        }).toList();
      }

      return docs;
    });
  }

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>>
      streamPatientsOfCaregiver(String caregiverId) {
    final idx = _db
        .collection('caregivers')
        .doc(caregiverId)
        .collection('patients');

    return idx.snapshots().asyncMap((snap) async {
      if (snap.docs.isEmpty) {
        return <DocumentSnapshot<Map<String, dynamic>>>[];
      }

      final futures = snap.docs.map(
        (patientDocument) => _db
            .collection('users')
            .doc(patientDocument.id)
            .get(),
      );

      return Future.wait(futures);
    });
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamPendingRequestsForPatient(String patientId) {
    return _db
        .collection('caregiver_patient_requests')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      streamPendingRequestsByCaregiver(String caregiverId) {
    return _db
        .collection('caregiver_patient_requests')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs);
  }

  Future<void> requestPatientAccess({
    required String caregiverId,
    required String patientUserId,
  }) async {
    final patientRef = _db
        .collection('users')
        .doc(patientUserId);

    final caregiverRef = _db
        .collection('users')
        .doc(caregiverId);

    final requestId = '${caregiverId}_$patientUserId';

    final requestRef = _db
        .collection('caregiver_patient_requests')
        .doc(requestId);

    await _db.runTransaction((tx) async {
      final patientSnap = await tx.get(patientRef);
      final caregiverSnap = await tx.get(caregiverRef);
      final requestSnap = await tx.get(requestRef);

      if (!patientSnap.exists) {
        throw Exception('El paciente no existe.');
      }

      if (!caregiverSnap.exists) {
        throw Exception('El cuidador no existe.');
      }

      final patientData =
          patientSnap.data() as Map<String, dynamic>;

      final caregiverData =
          caregiverSnap.data() as Map<String, dynamic>;

      if ((patientData['role'] ?? '') != 'Consultante') {
        throw Exception(
          'Solo puedes solicitar acceso a usuarios consultantes.',
        );
      }

      if ((caregiverData['role'] ?? '') != 'Cuidador') {
        throw Exception(
          'Solo un cuidador puede solicitar acceso.',
        );
      }

      final currentCaregiver =
          patientData['caregiverId']?.toString().trim() ?? '';

      if (currentCaregiver.isNotEmpty &&
          currentCaregiver != caregiverId) {
        throw Exception(
          'Este paciente ya está vinculado a otro cuidador.',
        );
      }

      if (currentCaregiver == caregiverId) {
        final idxRef = _db
            .collection('caregivers')
            .doc(caregiverId)
            .collection('patients')
            .doc(patientUserId);

        tx.set(
          idxRef,
          {
            'patientUserId': patientUserId,
            'caregiverId': caregiverId,
            'acceptedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return;
      }

      if (requestSnap.exists) {
        final requestData =
            requestSnap.data() as Map<String, dynamic>;

        final status =
            (requestData['status'] ?? '').toString();

        if (status == 'pending') {
          throw Exception(
            'Ya existe una solicitud pendiente para este paciente.',
          );
        }
      }

      final caregiverName = (
        caregiverData['displayName'] ??
            '${caregiverData['firstName'] ?? ''} '
                '${caregiverData['lastName'] ?? ''}'
      )
          .toString()
          .trim();

      final patientName = (
        patientData['displayName'] ??
            '${patientData['firstName'] ?? ''} '
                '${patientData['lastName'] ?? ''}'
      )
          .toString()
          .trim();

      final requestData = <String, dynamic>{
        'caregiverId': caregiverId,
        'patientId': patientUserId,
        'caregiverName':
            caregiverName.isEmpty ? 'Cuidador' : caregiverName,
        'patientName':
            patientName.isEmpty ? 'Paciente' : patientName,
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (requestSnap.exists) {
        requestData['acceptedAt'] = FieldValue.delete();
        requestData['rejectedAt'] = FieldValue.delete();
      } else {
        requestData['createdAt'] =
            FieldValue.serverTimestamp();
      }

      tx.set(
        requestRef,
        requestData,
        SetOptions(merge: true),
      );

      final notificationRef =
          _db.collection('notifications').doc();

      tx.set(notificationRef, {
        'userId': patientUserId,
        'type': 'patient_access_request',
        'title': 'Solicitud de vinculación',
        'message':
            '${caregiverName.isEmpty ? 'Un cuidador' : caregiverName} '
            'quiere vincularse contigo para consultar tu información.',
        'requestId': requestId,
        'caregiverId': caregiverId,
        'patientId': patientUserId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
    Future<void> acceptPatientRequest({
    required String requestId,
    required String patientUserId,
  }) async {
    final requestRef = _db
        .collection('caregiver_patient_requests')
        .doc(requestId);

    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);

      if (!requestSnap.exists) {
        throw Exception('La solicitud no existe.');
      }

      final requestData =
          requestSnap.data() as Map<String, dynamic>;

      if ((requestData['patientId'] ?? '').toString() !=
          patientUserId) {
        throw Exception(
          'No tienes permiso para aceptar esta solicitud.',
        );
      }

      final status =
          (requestData['status'] ?? '').toString();

      if (status == 'accepted') {
        return;
      }

      if (status != 'pending') {
        throw Exception(
          'Esta solicitud ya fue rechazada.',
        );
      }

      final caregiverId =
          (requestData['caregiverId'] ?? '')
              .toString()
              .trim();

      if (caregiverId.isEmpty) {
        throw Exception(
          'La solicitud no contiene un cuidador válido.',
        );
      }

      final patientRef = _db
          .collection('users')
          .doc(patientUserId);

      final caregiverRef = _db
          .collection('users')
          .doc(caregiverId);

      final patientSnap = await tx.get(patientRef);
      final caregiverSnap = await tx.get(caregiverRef);

      if (!patientSnap.exists) {
        throw Exception('El paciente no existe.');
      }

      if (!caregiverSnap.exists) {
        throw Exception('El cuidador no existe.');
      }

      final patientData =
          patientSnap.data() as Map<String, dynamic>;

      final caregiverData =
          caregiverSnap.data() as Map<String, dynamic>;

      if ((patientData['role'] ?? '') != 'Consultante') {
        throw Exception(
          'El usuario de la solicitud no es consultante.',
        );
      }

      if ((caregiverData['role'] ?? '') != 'Cuidador') {
        throw Exception(
          'El usuario de la solicitud no es cuidador.',
        );
      }

      final currentCaregiver =
          patientData['caregiverId']?.toString().trim() ?? '';

      if (currentCaregiver.isNotEmpty &&
          currentCaregiver != caregiverId) {
        throw Exception(
          'Este paciente ya está vinculado a otro cuidador.',
        );
      }

      final idxRef = _db
          .collection('caregivers')
          .doc(caregiverId)
          .collection('patients')
          .doc(patientUserId);

      tx.update(patientRef, {
        'caregiverId': caregiverId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      /*
       * IMPORTANTE:
       * Se usa merge para que funcione tanto cuando el documento
       * todavía no existe como cuando quedó guardado por una
       * vinculación anterior.
       */
      tx.set(
        idxRef,
        {
          'patientUserId': patientUserId,
          'caregiverId': caregiverId,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        requestRef,
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'rejectedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final caregiverNotificationRef =
          _db.collection('notifications').doc();

      tx.set(caregiverNotificationRef, {
        'userId': caregiverId,
        'type': 'patient_request_accepted',
        'title': 'Solicitud aceptada',
        'message':
            'El paciente aceptó tu solicitud de vinculación.',
        'requestId': requestId,
        'caregiverId': caregiverId,
        'patientId': patientUserId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectPatientRequest({
    required String requestId,
    required String patientUserId,
  }) async {
    final requestRef = _db
        .collection('caregiver_patient_requests')
        .doc(requestId);

    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);

      if (!requestSnap.exists) {
        throw Exception('La solicitud no existe.');
      }

      final requestData =
          requestSnap.data() as Map<String, dynamic>;

      if ((requestData['patientId'] ?? '').toString() !=
          patientUserId) {
        throw Exception(
          'No tienes permiso para rechazar esta solicitud.',
        );
      }

      final status =
          (requestData['status'] ?? '').toString();

      if (status == 'rejected') {
        return;
      }

      if (status != 'pending') {
        throw Exception(
          'Esta solicitud ya fue aceptada.',
        );
      }

      final caregiverId =
          (requestData['caregiverId'] ?? '')
              .toString()
              .trim();

      if (caregiverId.isEmpty) {
        throw Exception(
          'La solicitud no contiene un cuidador válido.',
        );
      }

      tx.set(
        requestRef,
        {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final caregiverNotificationRef =
          _db.collection('notifications').doc();

      tx.set(caregiverNotificationRef, {
        'userId': caregiverId,
        'type': 'patient_request_rejected',
        'title': 'Solicitud rechazada',
        'message':
            'El paciente rechazó tu solicitud de vinculación.',
        'requestId': requestId,
        'caregiverId': caregiverId,
        'patientId': patientUserId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
    Future<void> addPatientToCaregiver({
    required String caregiverId,
    required String patientUserId,
  }) async {
    await requestPatientAccess(
      caregiverId: caregiverId,
      patientUserId: patientUserId,
    );
  }

  Future<void> removePatientFromCaregiver({
    required String caregiverId,
    required String patientUserId,
  }) async {
    final userRef = _db
        .collection('users')
        .doc(patientUserId);

    final idxRef = _db
        .collection('caregivers')
        .doc(caregiverId)
        .collection('patients')
        .doc(patientUserId);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);

      if (!userSnap.exists) {
        return;
      }

      final data =
          userSnap.data() as Map<String, dynamic>;

      if (data['caregiverId'] == caregiverId) {
        tx.update(userRef, {
          'caregiverId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      tx.delete(idxRef);

      final notificationRef =
          _db.collection('notifications').doc();

      tx.set(notificationRef, {
        'userId': patientUserId,
        'type': 'patient_unlinked',
        'title': 'Vinculación finalizada',
        'message':
            'Tu cuidador dejó de estar vinculado a tu perfil.',
        'caregiverId': caregiverId,
        'patientId': patientUserId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}