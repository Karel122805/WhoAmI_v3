// lib/src/app.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:whoami_app/src/core/accessibility/accessibility_controller.dart';
import 'package:whoami_app/src/core/accessibility/accessibility_service.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

import 'package:whoami_app/src/features/auth/presentation/pages/auth_gate.dart';
import 'package:whoami_app/src/features/auth/presentation/pages/choice_start.dart';
import 'package:whoami_app/src/features/auth/presentation/pages/login_page.dart';

import 'package:whoami_app/src/features/register/presentation/pages/register_name_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_password_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_role_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_patient_page.dart';

import 'package:whoami_app/src/features/home/presentation/pages/home_caregiver.dart';
import 'package:whoami_app/src/features/home/presentation/pages/home_consultant.dart';

import 'package:whoami_app/src/features/profile/presentation/pages/settings_page.dart';
import 'package:whoami_app/src/features/profile/presentation/pages/edit_profile_page.dart';

import 'package:whoami_app/src/features/patients/presentation/pages/patients_list_page.dart';

import 'package:whoami_app/src/features/games/presentation/pages/game_page.dart';
import 'package:whoami_app/src/features/games/presentation/pages/memorama_page.dart';

import 'package:whoami_app/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:whoami_app/src/features/assistant/presentation/pages/assistant_page.dart';

import 'package:whoami_app/src/features/recommendations/presentation/recommendations_screen.dart';

class WhoAmIApp extends StatefulWidget {
  const WhoAmIApp({super.key});

  @override
  State<WhoAmIApp> createState() => _WhoAmIAppState();
}

class _WhoAmIAppState extends State<WhoAmIApp> {
  late final AccessibilityController a11y;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();

    a11y = AccessibilityController(AccessibilityService());

    unawaited(_loadAccessibility());

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(_loadAccessibility());
    });
  }

  Future<void> _loadAccessibility() async {
    try {
      await a11y.init();
    } catch (_) {
      // Evita que la app se caiga si hay error leyendo preferencias.
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    a11y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a11y,
      builder: (context, _) {
        final s = a11y.settings;

        const seed = kBlue;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'WhoAmI?',
          theme: buildAppTheme(
            seedColor: seed,
            darkMode: false,
            simplified: s.simplified,
          ),
          darkTheme: buildAppTheme(
            seedColor: seed,
            darkMode: true,
            simplified: s.simplified,
          ),
          themeMode: s.darkMode ? ThemeMode.dark : ThemeMode.light,
          supportedLocales: const [
            Locale('es'),
            Locale('es', 'MX'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: const Locale('es', 'MX'),
          builder: (context, child) {
            final mq = MediaQuery.of(context);

            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(s.textScale),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          initialRoute: '/',
          routes: {
            '/': (_) => const AuthGate(),

            '/auth/choice': (_) => const ChoiceStart(),
            '/login': (_) => const LoginPage(),

            '/register/name': (_) => const RegisterNamePage(),
            '/register/password': (_) => const RegisterPasswordPage(),
            '/register/role': (_) => const RegisterRolePage(),

            '/home/caregiver': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
              return HomeCaregiverPage(
                displayName: args?['name'] as String?,
              );
            },

            '/home/consultant': (ctx) {
              final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
              return HomeConsultantPage(
                displayName: args?['name'] as String?,
              );
            },

            '/settings': (_) => SettingsPage(a11y: a11y),
            '/settings/edit-profile': (_) => const EditProfilePage(),

            PatientsListPage.route: (_) => const PatientsListPage(),
            RegisterPatientPage.route: (_) => const RegisterPatientPage(),

            GamesPage.route: (_) => const GamesPage(),
            MemoramaPage.route: (_) => const MemoramaPage(),

            NotificationsPage.route: (_) => const NotificationsPage(),
            AssistantPage.route: (_) => const AssistantPage(),

            '/recommendations': (_) => const RecommendationsScreen(),
          },
        );
      },
    );
  }
}