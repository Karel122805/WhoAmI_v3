import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'services/notifications_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 Ejecuta la inicialización en paralelo para no bloquear la app
  try {
    await Future.wait([
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      NotificationsService.init(),
      _requestNotificationPermission(),
      _requestLocationPermission(),
    ]);
  } catch (e, st) {
    debugPrint('❌ Error al inicializar: $e');
    debugPrint(st.toString());
  }

  runApp(const WhoAmIApp());
}

/// =============================================================
/// 🔔 Solicitar permiso de notificaciones (Android 13–15)
/// =============================================================
Future<void> _requestNotificationPermission() async {
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 🔥 También solicita permisos push (Firebase Cloud Messaging)
    await FirebaseMessaging.instance.requestPermission();
  } catch (e) {
    debugPrint('⚠️ Error solicitando permisos de notificaciones: $e');
  }
}

/// =============================================================
/// 📍 Solicitar permiso de ubicación (Android 12–15)
/// =============================================================
Future<void> _requestLocationPermission() async {
  try {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('🚫 Permiso de ubicación denegado permanentemente.');
    }
  } catch (e) {
    debugPrint('⚠️ Error solicitando permiso de ubicación: $e');
  }
}

/// =============================================================
/// 💫 Pantalla temporal de carga (opcional)
/// =============================================================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 80),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Colors.deepPurple,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
