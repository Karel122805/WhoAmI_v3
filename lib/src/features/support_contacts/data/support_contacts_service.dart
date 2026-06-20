import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/support_contact_model.dart';

class SupportContactsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _contactsRef(String uid) {
    return _db.collection('users').doc(uid).collection('supportContacts');
  }

  static Stream<List<SupportContactModel>> watchUserContacts() {
    final uid = currentUid;

    if (uid == null) {
      return Stream.value([]);
    }

    return _contactsRef(uid)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SupportContactModel.fromMap(
                  id: doc.id,
                  data: doc.data(),
                ),
              )
              .toList(),
        );
  }

  static Future<void> addContact({
    required String name,
    required String phone,
  }) async {
    final uid = currentUid;

    if (uid == null) {
      throw Exception('No hay usuario autenticado.');
    }

    await _contactsRef(uid).add({
      'name': name.trim(),
      'phone': phone.trim(),
      'isDefault': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateContact({
    required String id,
    required String name,
    required String phone,
  }) async {
    final uid = currentUid;

    if (uid == null) {
      throw Exception('No hay usuario autenticado.');
    }

    await _contactsRef(uid).doc(id).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteContact(String id) async {
    final uid = currentUid;

    if (uid == null) {
      throw Exception('No hay usuario autenticado.');
    }

    await _contactsRef(uid).doc(id).delete();
  }
}