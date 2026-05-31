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
import 'package:whoami_app/src/features/support_contacts/presentation/support_contacts_screen.dart';
import 'package:whoami_app/src/features/emergency/presentation/pages/panic_button_page.dart';

class WhoAmIApp extends StatefulWidget {
  const WhoAmIApp({super.key});

  @override
  State<WhoAmIApp> createState() => _WhoAmIAppState();
}

class _WhoAmIAppState extends State<WhoAmIApp> with WidgetsBindingObserver {
  late final AccessibilityController a11y;
  StreamSubscription<User?>? _authSub;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // ============================================================
  // HU-15 - Control de uso prolongado progresivo
  //
  // PRUEBA:
  // Avisará cada 20 segundos:
  // 20s, 40s, 60s, 80s...
  //
  // PRODUCCIÓN:
  // Cuando ya quede probado, cambia:
  // Duration(seconds: 20)
  // por:
  // Duration(minutes: 30)
  //
  // Así avisará:
  // 30 min, 1 hora, 1 hora 30 min, 2 horas...
  // ============================================================
  static const Duration _progressiveReminderStep = Duration(minutes: 30);
  static const Duration _checkInterval = Duration(seconds: 5);

  Timer? _usageTimer;
  DateTime? _usageStartedAt;
  Duration _nextReminderAt = _progressiveReminderStep;
  bool _breakDialogVisible = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    a11y = AccessibilityController(AccessibilityService());

    unawaited(_loadAccessibility());

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_loadAccessibility());

      if (user == null) {
        _stopUsageControl();
      } else {
        _startUsageControl();
      }
    });

    if (FirebaseAuth.instance.currentUser != null) {
      _startUsageControl();
    }
  }

  Future<void> _loadAccessibility() async {
    try {
      await a11y.init();
    } catch (_) {
      // Evita que la app se caiga si hay error leyendo preferencias.
    }
  }

  void _startUsageControl() {
    _usageStartedAt = DateTime.now();
    _nextReminderAt = _progressiveReminderStep;

    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(_checkInterval, (_) {
      _checkProlongedUse();
    });
  }

  void _stopUsageControl() {
    _usageTimer?.cancel();
    _usageTimer = null;
    _usageStartedAt = null;
    _nextReminderAt = _progressiveReminderStep;
    _breakDialogVisible = false;
  }

  void _resetUsageControl() {
    _usageStartedAt = DateTime.now();
    _nextReminderAt = _progressiveReminderStep;
  }

  void _checkProlongedUse() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;
    if (_usageStartedAt == null) return;
    if (_breakDialogVisible) return;

    final elapsed = DateTime.now().difference(_usageStartedAt!);

    if (elapsed >= _nextReminderAt) {
      final currentElapsed = elapsed;
      _nextReminderAt += _progressiveReminderStep;
      unawaited(_showBreakSuggestionDialog(currentElapsed));
    }
  }

  Future<void> _showBreakSuggestionDialog(Duration elapsed) async {
    final context = _navigatorKey.currentContext;

    if (context == null) return;

    _breakDialogVisible = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.self_improvement_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Descanso recomendado'),
              ),
            ],
          ),
          content: Text(
            'Has estado usando la aplicación durante ${_formatUsageTime(elapsed)}.\n\n'
            'Te recomendamos tomar un pequeño descanso, estirarte o tomar agua.\n\n'
            'Puedes continuar cuando te sientas listo.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Seguir usando'),
            ),
            FilledButton.icon(
              onPressed: () {
                _resetUsageControl();
                Navigator.of(dialogContext).pop();
              },
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Tomar descanso'),
            ),
          ],
        );
      },
    );

    _breakDialogVisible = false;
  }

  String _formatUsageTime(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final totalMinutes = duration.inMinutes;

    if (totalMinutes <= 0) {
      return totalSeconds == 1 ? '1 segundo' : '$totalSeconds segundos';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return minutes == 1 ? '1 minuto' : '$minutes minutos';
    }

    if (minutes == 0) {
      return hours == 1 ? '1 hora' : '$hours horas';
    }

    final hourText = hours == 1 ? '1 hora' : '$hours horas';
    final minuteText = minutes == 1 ? '1 minuto' : '$minutes minutos';

    return '$hourText y $minuteText';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _resetUsageControl();
    }

    if (state == AppLifecycleState.resumed &&
        FirebaseAuth.instance.currentUser != null) {
      _resetUsageControl();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageTimer?.cancel();
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
          navigatorKey: _navigatorKey,
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
            SupportContactsScreen.route: (_) => const SupportContactsScreen(),
            PanicButtonPage.route: (_) => const PanicButtonPage(),
          },
        );
      },
    );
  }
}