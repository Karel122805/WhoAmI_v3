import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMTokenService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Colección recomendada:
  // users/{uid}/fcm_tokens/{token}
  static CollectionReference<Map<String, dynamic>> _tokensCol(String uid) {
    return _db.collection('users').doc(uid).collection('fcm_tokens');
  }

  // Pide permiso (iOS y Android 13+), toma token y lo guarda.
  static Future<void> initAndSaveToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1) Permisos (Android 13+ / iOS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2) Obtener token
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    // 3) Guardar token por dispositivo
    await _tokensCol(user.uid).doc(token).set({
      'token': token,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4) Si el token rota, actualiza Firestore
    _messaging.onTokenRefresh.listen((newToken) async {
      final u = _auth.currentUser;
      if (u == null) return;

      // guarda el nuevo
      await _tokensCol(u.uid).doc(newToken).set({
        'token': newToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // intenta borrar el viejo (el que ya no sirve)
      await _tokensCol(u.uid).doc(token).delete().catchError((_) {});
    });
  }

  // Quita ESTE dispositivo de la cuenta (para logout)
  // No borra “FirebaseMessaging” del sistema; solo desasocia el token de esa cuenta.
  static Future<void> unregisterCurrentDeviceToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _tokensCol(user.uid).doc(token).delete().catchError((_) {});
  }

  // Si todavía quieres conservar un método con tu nombre anterior,
  // lo dejamos como alias para no romper código viejo.
  static Future<void> clearToken() async {
    await unregisterCurrentDeviceToken();
  }
}






