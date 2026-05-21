import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  static const String _askedKey = "all_permissions_requested";
  static bool _askingNow = false;      // evita dobles ejecuciones simultáneas
  static bool _askedThisSession = false; // evita repetir en el mismo proceso

  /// SOLO UNA VEZ (persistente) y además SOLO UNA VEZ por sesión
  static Future<void> askAllPermissionsOnce() async {
    // En Web no se solicitan permisos nativos
    if (kIsWeb) return;

    // Si ya se pidió en esta sesión, no repetir
    if (_askedThisSession) return;

    // Evitar que se ejecute dos veces si el lifecycle dispara rápido
    if (_askingNow) return;
    _askingNow = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final alreadyAsked = prefs.getBool(_askedKey) ?? false;
      if (alreadyAsked) {
        _askedThisSession = true;
        return;
      }

      // Marcar inmediatamente para que, aunque la app se pause o se mate,
      // al volver no vuelva a disparar el flujo completo.
      await prefs.setBool(_askedKey, true);
      _askedThisSession = true;

      // Esperar a que Flutter tenga pantalla
      await Future.delayed(const Duration(milliseconds: 300));

      // 1) Notificaciones (solo pedir si aplica y si no está concedido)
      await _requestNotificationsIfNeeded();

      // 2) Cámara (solo si no está concedido)
      await _requestCameraIfNeeded();

      // 3) Fotos / Galería (solo si aplica y no está concedido)
      await _requestGalleryIfNeeded();

      // 4) Ubicación (solo si no está concedido)
      await _requestLocationIfNeeded();
    } finally {
      _askingNow = false;
    }
  }

  static Future<void> _requestNotificationsIfNeeded() async {
    try {
      if (Platform.isAndroid) {
        final plugin = FlutterLocalNotificationsPlugin();
        await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      // Firebase Messaging (Android/iOS). En web no llegamos aquí.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }

  static Future<void> _requestCameraIfNeeded() async {
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        await Permission.camera.request();
      }
    } catch (_) {}
  }

  static Future<void> _requestGalleryIfNeeded() async {
    // En Web no aplica, y aquí ya estamos en mobile.
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          await Permission.photos.request();
        }
      }
    } catch (_) {}
  }

  static Future<void> _requestLocationIfNeeded() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  /// Permisos individuales

  static Future<bool> requestCamera() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;

      final req = await Permission.camera.request();
      return req.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestGallery() async {
    if (kIsWeb) return true;

    try {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;

      final req = await Permission.photos.request();
      return req.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestCameraAndGallery() async {
    if (kIsWeb) return true;

    try {
      final cam = await Permission.camera.status;
      final pho = await Permission.photos.status;

      if (cam.isGranted && pho.isGranted) return true;

      final statuses = await [
        if (!cam.isGranted) Permission.camera,
        if (!pho.isGranted) Permission.photos,
      ].request();

      // Si no se pidió alguno porque ya estaba granted, no aparece en map.
      final allGranted = statuses.values.every((s) => s.isGranted);
      final camOk = cam.isGranted || (statuses[Permission.camera]?.isGranted ?? false);
      final phoOk = pho.isGranted || (statuses[Permission.photos]?.isGranted ?? false);

      return allGranted && camOk && phoOk;
    } catch (_) {
      return false;
    }
  }

  /// Opcional: si quieres permitir re-pedir permisos (por ejemplo desde un botón de ajustes)
  static Future<void> resetAskedFlagForTesting() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_askedKey);
    _askedThisSession = false;
  }
}
