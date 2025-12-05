// lib/services/permission_service.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  /// ============================================================================================
  /// 🔥 SOLO UNA VEZ: Se piden todos los permisos la primera vez que se abre la app
  /// ============================================================================================
  static Future<void> askAllPermissionsOnce() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyAsked = prefs.getBool("all_permissions_requested") ?? false;
    if (alreadyAsked) return;

    // Esperamos a que Flutter ya tenga pantalla
    await Future.delayed(const Duration(milliseconds: 300));

    // 📌 1. Notificaciones
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}

    // 📌 2. Cámara
    await Permission.camera.request();

    // 📌 3. Fotos / Galería
    await Permission.photos.request();

    // 📌 4. Ubicación (si la necesitas)
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}

    // Guardar que ya no se volverán a pedir
    prefs.setBool("all_permissions_requested", true);
  }

  /// ============================================================================================
  /// Permisos individuales (si los quieres usar dentro de funciones específicas)
  /// ============================================================================================

  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestGallery() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraAndGallery() async {
    final statuses = await [
      Permission.camera,
      Permission.photos,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }
}
