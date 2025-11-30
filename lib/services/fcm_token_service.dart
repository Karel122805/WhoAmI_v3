import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// =============================================================
/// SERVICIO CENTRALIZADO DE TOKEN FCM (Who Am I)
/// =============================================================
/// - Guarda el token del usuario autenticado en Firestore.
/// - Actualiza automáticamente si el token cambia.
/// - Elimina el token cuando el usuario cierra sesión o borra la cuenta.
/// - Compatible con Android 13–15 y iOS.
/// =============================================================
class FCMTokenService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;

  /// =============================================================
  /// Inicializa y guarda el token del usuario actual
  /// =============================================================
  static Future<void> saveCurrentUserToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No hay usuario autenticado para registrar FCM.');
        return;
      }

      // 🔹 Solicita permisos de notificación (solo una vez)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('🚫 Permisos FCM denegados por el usuario.');
        return;
      }

      // 🔹 Obtiene token actual
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('⚠️ No se pudo obtener el token FCM.');
        return;
      }

      // 🔹 Guarda o actualiza el token en Firestore
      await _db.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Token FCM guardado correctamente: $token');

      // 🔹 Escucha cambios de token y actualiza automáticamente
      _messaging.onTokenRefresh.listen((newToken) async {
        try {
          await _db.collection('users').doc(user.uid).set({
            'fcmToken': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('🔁 Token FCM actualizado automáticamente.');
        } catch (e) {
          debugPrint('⚠️ Error al actualizar token FCM: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ Error al guardar token FCM: $e');
    }
  }

  /// =============================================================
  /// Limpia el token del usuario actual en Firestore
  /// =============================================================
  static Future<void> clearToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });

      debugPrint('🧹 Token FCM eliminado correctamente.');
    } catch (e) {
      debugPrint('⚠️ Error al eliminar token FCM: $e');
    }
  }

  /// =============================================================
  /// Obtiene el token FCM actual (sin guardarlo)
  /// =============================================================
  static Future<String?> getCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('📲 Token actual: $token');
      return token;
    } catch (e) {
      debugPrint('⚠️ Error al obtener token FCM: $e');
      return null;
    }
  }

  /// =============================================================
  /// Envía una notificación directa (modo prueba)
  /// =============================================================
  static Future<void> sendTestNotification(String targetUid) async {
    try {
      final userDoc = await _db.collection('users').doc(targetUid).get();
      final targetToken = userDoc.data()?['fcmToken'];

      if (targetToken == null) {
        debugPrint('⚠️ Usuario destino sin token FCM.');
        return;
      }

      // 🚀 Solo imprime el token (el envío real se hace desde Cloud Functions)
      debugPrint('🎯 Token de destino: $targetToken');
    } catch (e) {
      debugPrint('⚠️ Error al buscar token destino: $e');
    }
  }
}
