import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🚀 Solo inicializamos Firebase y el servicio de notificaciones
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationsService.init();

  } catch (e, st) {
    debugPrint('❌ Error al inicializar: $e');
    debugPrint(st.toString());
  }

  // 💜 Evita que el sistema agrande el texto
  final window = WidgetsBinding.instance.window;
  final mediaQuery = MediaQueryData.fromWindow(window).copyWith(
    textScaleFactor: 1.0,
  );

  runApp(
    MediaQuery(
      data: mediaQuery,
      child: const WhoAmIApp(),
    ),
  );
}
