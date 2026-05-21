import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'services/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationsService.init();
  } catch (e, st) {
    debugPrint('Error al inicializar: $e');
    debugPrint(st.toString());
  }

  runApp(const WhoAmIApp());
}
