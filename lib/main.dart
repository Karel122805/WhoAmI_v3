import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/features/memories/data/memories_scheduler.dart';
import 'src/features/notifications/data/notifications_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationsService.init();

  await NotificationsService.handleBackgroundFirebaseMessage(
    message,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await NotificationsService.init();

    await NotificationsService.saveFcmTokenForCurrentUser();

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      await MemoriesScheduler.scheduleAllForUser(
        currentUser.uid,
      );
    }
  } catch (error, stackTrace) {
    debugPrint(
      'Error durante la inicialización de la aplicación: $error',
    );

    debugPrint(
      stackTrace.toString(),
    );
  }

  runApp(
    const WhoAmIApp(),
  );
}