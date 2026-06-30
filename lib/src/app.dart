// lib/src/app.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:whoami_app/src/core/accessibility/accessibility_controller.dart';
import 'package:whoami_app/src/core/accessibility/accessibility_service.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

import 'package:whoami_app/src/features/assistant/presentation/pages/assistant_page.dart';

import 'package:whoami_app/src/features/auth/presentation/pages/auth_gate.dart';
import 'package:whoami_app/src/features/auth/presentation/pages/choice_start.dart';
import 'package:whoami_app/src/features/auth/presentation/pages/login_page.dart';

import 'package:whoami_app/src/features/emergency/presentation/pages/panic_button_page.dart';

import 'package:whoami_app/src/features/games/presentation/pages/game_page.dart';
import 'package:whoami_app/src/features/games/presentation/pages/memorama_page.dart';

import 'package:whoami_app/src/features/home/presentation/pages/home_caregiver.dart';
import 'package:whoami_app/src/features/home/presentation/pages/home_consultant.dart';

import 'package:whoami_app/src/features/memories/data/memories_scheduler.dart';

import 'package:whoami_app/src/features/notifications/data/notifications_service.dart';
import 'package:whoami_app/src/features/notifications/presentation/pages/notifications_page.dart';

import 'package:whoami_app/src/features/patients/presentation/pages/patients_list_page.dart';
import 'package:whoami_app/src/features/patients/presentation/pages/patient_profile_page.dart';

import 'package:whoami_app/src/features/preventive_info/presentation/preventive_info_screen.dart';

import 'package:whoami_app/src/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:whoami_app/src/features/profile/presentation/pages/settings_page.dart';

import 'package:whoami_app/src/features/recommendations/presentation/recommendations_screen.dart';

import 'package:whoami_app/src/features/register/presentation/pages/register_name_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_password_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_patient_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_role_page.dart';

import 'package:whoami_app/src/features/reminders/presentation/pages/reminder_alarm_page.dart';
import 'package:whoami_app/src/features/reminders/presentation/pages/reminders_page.dart';
import 'package:whoami_app/src/features/reminders/presentation/providers/reminder_provider.dart';

import 'package:whoami_app/src/features/support_contacts/presentation/support_contacts_screen.dart';

import 'package:whoami_app/src/features/reports/presentation/patient_progress_report_page.dart';
import 'package:whoami_app/src/features/reports/presentation/activity_summary_report_page.dart';

enum _BreakAction {
  continueUsing,
  takeBreak,
}

class WhoAmIApp extends StatefulWidget {
  const WhoAmIApp({
    super.key,
  });

  @override
  State<WhoAmIApp> createState() {
    return _WhoAmIAppState();
  }
}

class _WhoAmIAppState extends State<WhoAmIApp>
    with WidgetsBindingObserver {
  late final AccessibilityController a11y;

  StreamSubscription<User?>? _authSubscription;

  // ============================================================
  // USO PROLONGADO
  //
  // Primer aviso: 30 minutos.
  // Los siguientes avisos aparecen cada 30 minutos.
  // ============================================================

  static const Duration _reminderInterval =
      Duration(
    minutes: 30,
  );

  static const Duration _checkInterval =
      Duration(
    seconds: 30,
  );

  Timer? _usageTimer;

  DateTime? _usageStartedAt;

  Duration _nextReminderAt =
      _reminderInterval;

  bool _breakDialogVisible =
      false;

  bool _appIsActive =
      true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    a11y = AccessibilityController(
      AccessibilityService(),
    );

    unawaited(
      _loadAccessibility(),
    );

    // Firebase envía inmediatamente el usuario actual al crear
    // esta suscripción. También vuelve a ejecutarse al iniciar
    // o cerrar sesión.
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(
      _handleAuthStateChanged,
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'Error escuchando el estado de autenticación: $error',
        );

        debugPrint(
          stackTrace.toString(),
        );
      },
    );
  }

  // ============================================================
  // CAMBIO DE ESTADO DE AUTENTICACIÓN
  // ============================================================

  void _handleAuthStateChanged(
    User? user,
  ) {
    unawaited(
      _loadAccessibility(),
    );

    if (user == null) {
      _stopUsageControl();
      return;
    }

    if (_appIsActive) {
      _startUsageControl();
    }

    // Recupera y registra las notificaciones semanales cuando
    // ya existe un usuario autenticado.
    unawaited(
      _recoverMemoryNotifications(
        user.uid,
      ),
    );
  }

  // ============================================================
  // RECUPERAR NOTIFICACIONES DE RECUERDOS
  // ============================================================

  Future<void> _recoverMemoryNotifications(
    String uid,
  ) async {
    try {
      await MemoriesScheduler.scheduleAllForUser(
        uid,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Error recuperando recordatorios de recuerdos: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // CARGAR ACCESIBILIDAD
  // ============================================================

  Future<void> _loadAccessibility() async {
    try {
      await a11y.init();
    } catch (error, stackTrace) {
      debugPrint(
        'Error cargando configuración de accesibilidad: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  // ============================================================
  // INICIAR USO PROLONGADO
  // ============================================================

  void _startUsageControl() {
    if (!mounted) {
      return;
    }

    _usageTimer?.cancel();

    _usageStartedAt =
        DateTime.now();

    _nextReminderAt =
        _reminderInterval;

    _breakDialogVisible =
        false;

    _appIsActive =
        true;

    _usageTimer = Timer.periodic(
      _checkInterval,
      (_) {
        _checkProlongedUse();
      },
    );

    debugPrint(
      'Uso Prolongado iniciado. Primer aviso en 30 minutos.',
    );
  }

  // ============================================================
  // DETENER USO PROLONGADO
  // ============================================================

  void _stopUsageControl() {
    _usageTimer?.cancel();

    _usageTimer =
        null;

    _usageStartedAt =
        null;

    _nextReminderAt =
        _reminderInterval;

    _breakDialogVisible =
        false;

    debugPrint(
      'Uso Prolongado detenido.',
    );
  }

  // ============================================================
  // COMPROBAR TIEMPO DE USO
  // ============================================================

  void _checkProlongedUse() {
    if (!mounted ||
        !_appIsActive ||
        _breakDialogVisible) {
      return;
    }

    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return;
    }

    final startedAt =
        _usageStartedAt;

    if (startedAt == null) {
      _usageStartedAt =
          DateTime.now();

      return;
    }

    final elapsed =
        DateTime.now().difference(
      startedAt,
    );

    debugPrint(
      'Uso Prolongado: ${elapsed.inMinutes} minutos de uso.',
    );

    if (elapsed <
        _nextReminderAt) {
      return;
    }

    unawaited(
      _showBreakSuggestionDialog(
        elapsed,
      ),
    );
  }

  // ============================================================
  // MOSTRAR DIÁLOGO DE DESCANSO
  // ============================================================

  Future<void> _showBreakSuggestionDialog(
    Duration elapsed,
  ) async {
    if (!mounted ||
        _breakDialogVisible) {
      return;
    }

    final navigator =
        NotificationsService
            .navigatorKey
            .currentState;

    if (navigator == null) {
      debugPrint(
        'Uso Prolongado: el navegador todavía no está disponible.',
      );

      return;
    }

    final dialogContext =
        navigator.overlay?.context;

    if (dialogContext == null) {
      debugPrint(
        'Uso Prolongado: el contexto todavía no está disponible.',
      );

      return;
    }

    _breakDialogVisible =
        true;

    try {
      final action =
          await showDialog<_BreakAction>(
        context: dialogContext,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (
          context,
        ) {
          final theme =
              Theme.of(context);

          final colorScheme =
              theme.colorScheme;

          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              titlePadding:
                  const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                12,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                24,
                8,
                24,
                12,
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              title: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration:
                        BoxDecoration(
                      color: colorScheme
                          .primaryContainer,
                      shape:
                          BoxShape.circle,
                    ),
                    child: Icon(
                      Icons
                          .self_improvement_rounded,
                      color: colorScheme
                          .onPrimaryContainer,
                      size: 30,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  const Expanded(
                    child: Text(
                      'Descanso recomendado',
                    ),
                  ),
                ],
              ),
              content: Text(
                'Has estado usando la aplicación durante '
                '${_formatUsageTime(elapsed)}.\n\n'
                'Te recomendamos tomar un pequeño descanso, '
                'estirarte o tomar agua.\n\n'
                'Si eliges seguir usando la aplicación, '
                'volveremos a recordártelo dentro de 30 minutos.',
                style:
                    theme.textTheme.bodyLarge,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                      rootNavigator:
                          true,
                    ).pop(
                      _BreakAction
                          .continueUsing,
                    );
                  },
                  child: const Text(
                    'Seguir usando',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                      rootNavigator:
                          true,
                    ).pop(
                      _BreakAction
                          .takeBreak,
                    );
                  },
                  icon: const Icon(
                    Icons
                        .self_improvement_rounded,
                  ),
                  label: const Text(
                    'Tomar descanso',
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (action ==
          _BreakAction.takeBreak) {
        debugPrint(
          'Uso Prolongado: el usuario eligió tomar un descanso.',
        );

        _stopUsageControl();

        await Future<void>.delayed(
          const Duration(
            milliseconds: 300,
          ),
        );

        await SystemNavigator.pop();

        return;
      }

      if (action ==
          _BreakAction.continueUsing) {
        _nextReminderAt +=
            _reminderInterval;

        debugPrint(
          'Uso Prolongado: el usuario continuará usando la aplicación. '
          'Próximo aviso al llegar a '
          '${_nextReminderAt.inMinutes} minutos.',
        );

        return;
      }

      // Respaldo en caso de que el diálogo se cerrara sin
      // seleccionar una opción.
      _nextReminderAt +=
          _reminderInterval;
    } catch (error, stackTrace) {
      debugPrint(
        'Error mostrando aviso de Uso Prolongado: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );
    } finally {
      _breakDialogVisible =
          false;
    }
  }

  // ============================================================
  // FORMATEAR TIEMPO DE USO
  // ============================================================

  String _formatUsageTime(
    Duration duration,
  ) {
    final totalMinutes =
        duration.inMinutes;

    if (totalMinutes <= 0) {
      final totalSeconds =
          duration.inSeconds;

      if (totalSeconds == 1) {
        return '1 segundo';
      }

      return '$totalSeconds segundos';
    }

    final hours =
        totalMinutes ~/ 60;

    final minutes =
        totalMinutes % 60;

    if (hours == 0) {
      if (minutes == 1) {
        return '1 minuto';
      }

      return '$minutes minutos';
    }

    if (minutes == 0) {
      if (hours == 1) {
        return '1 hora';
      }

      return '$hours horas';
    }

    final hoursText =
        hours == 1
            ? '1 hora'
            : '$hours horas';

    final minutesText =
        minutes == 1
            ? '1 minuto'
            : '$minutes minutos';

    return '$hoursText y $minutesText';
  }

  // ============================================================
  // CICLO DE VIDA DE LA APLICACIÓN
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(
      state,
    );

    if (state ==
        AppLifecycleState.resumed) {
      _appIsActive =
          true;

      final currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        if (_usageTimer == null) {
          _startUsageControl();
        }

        // Respaldo para recuperar alarmas faltantes cuando
        // la aplicación vuelve a primer plano.
        unawaited(
          _recoverMemoryNotifications(
            currentUser.uid,
          ),
        );
      }

      return;
    }

    if (state ==
            AppLifecycleState.paused ||
        state ==
            AppLifecycleState.inactive ||
        state ==
            AppLifecycleState.detached ||
        state ==
            AppLifecycleState.hidden) {
      _appIsActive =
          false;

      _stopUsageControl();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    _usageTimer?.cancel();

    _authSubscription?.cancel();

    a11y.dispose();

    super.dispose();
  }

  // ============================================================
  // APLICACIÓN
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ReminderProvider>(
          create: (_) {
            return ReminderProvider();
          },
        ),
      ],
      child: AnimatedBuilder(
        animation:
            a11y,
        builder: (
          context,
          child,
        ) {
          final settings =
              a11y.settings;

          const seed =
              kBlue;

          return MaterialApp(
            // Debe ser la misma llave utilizada por
            // NotificationsService.
            navigatorKey:
                NotificationsService
                    .navigatorKey,
            debugShowCheckedModeBanner:
                false,
            title:
                'WhoAmI?',
            theme:
                buildAppTheme(
              seedColor:
                  seed,
              darkMode:
                  false,
              simplified:
                  settings.simplified,
            ),
            darkTheme:
                buildAppTheme(
              seedColor:
                  seed,
              darkMode:
                  true,
              simplified:
                  settings.simplified,
            ),
            themeMode:
                settings.darkMode
                    ? ThemeMode.dark
                    : ThemeMode.light,
            supportedLocales:
                const [
              Locale(
                'es',
              ),
              Locale(
                'es',
                'MX',
              ),
              Locale(
                'en',
              ),
            ],
            localizationsDelegates:
                const [
              GlobalMaterialLocalizations
                  .delegate,
              GlobalWidgetsLocalizations
                  .delegate,
              GlobalCupertinoLocalizations
                  .delegate,
            ],
            locale:
                const Locale(
              'es',
              'MX',
            ),
            builder: (
              context,
              child,
            ) {
              final mediaQuery =
                  MediaQuery.of(
                context,
              );

              return MediaQuery(
                data:
                    mediaQuery.copyWith(
                  textScaler:
                      TextScaler.linear(
                    settings.textScale,
                  ),
                ),
                child:
                    GestureDetector(
                  behavior:
                      HitTestBehavior
                          .translucent,
                  onTap: () {
                    FocusManager
                        .instance
                        .primaryFocus
                        ?.unfocus();
                  },
                  child:
                      child ??
                          const SizedBox
                              .shrink(),
                ),
              );
            },
            initialRoute:
                '/',
            routes: {
              '/': (
                context,
              ) {
                return const AuthGate();
              },
              '/auth/choice': (
                context,
              ) {
                return const ChoiceStart();
              },
              '/login': (
                context,
              ) {
                return const LoginPage();
              },
              '/register/name': (
                context,
              ) {
                return const RegisterNamePage();
              },
              '/register/password': (
                context,
              ) {
                return const RegisterPasswordPage();
              },
              '/register/role': (
                context,
              ) {
                return const RegisterRolePage();
              },
              '/home/caregiver': (
                routeContext,
              ) {
                final arguments =
                    ModalRoute.of(
                  routeContext,
                )?.settings.arguments
                        as Map?;

                return HomeCaregiverPage(
                  displayName:
                      arguments?['name']
                          as String?,
                );
              },
              '/home/consultant': (
                routeContext,
              ) {
                final arguments =
                    ModalRoute.of(
                  routeContext,
                )?.settings.arguments
                        as Map?;

                return HomeConsultantPage(
                  displayName:
                      arguments?['name']
                          as String?,
                );
              },
              '/settings': (
                context,
              ) {
                return SettingsPage(
                  a11y:
                      a11y,
                );
              },
              '/settings/edit-profile': (
                context,
              ) {
                return const EditProfilePage();
              },
              PatientsListPage.route: (
                context,
              ) {
                return const PatientsListPage();
              },
              RegisterPatientPage.route: (
                context,
              ) {
                return const RegisterPatientPage();
              },
              PatientProfilePage.route: (
                routeContext,
              ) {
                final arguments =
                    ModalRoute.of(
                  routeContext,
                )?.settings.arguments as Map?;

                return PatientProfilePage(
                  patientId: arguments?['patientId'] as String? ?? '',
                );
              },
              PatientProgressReportPage.route: (
                routeContext,
              ) {
                final arguments =
                    ModalRoute.of(
                  routeContext,
                )?.settings.arguments as Map?;

                return PatientProgressReportPage(
                  patientId: arguments?['patientId'] as String? ?? '',
                );
              },
              ActivitySummaryReportPage.route: (
                routeContext,
              ) {
                final arguments =
                    ModalRoute.of(
                  routeContext,
                )?.settings.arguments as Map?;

                return ActivitySummaryReportPage(
                  patientId: arguments?['patientId'] as String? ?? '',
                );
              },
              GamesPage.route: (
                context,
              ) {
                return const GamesPage();
              },
              MemoramaPage.route: (
                context,
              ) {
                return const MemoramaPage();
              },
              NotificationsPage.route: (
                context,
              ) {
                return const NotificationsPage();
              },
              AssistantPage.route: (
                context,
              ) {
                return const AssistantPage();
              },
              '/reminders': (
                context,
              ) {
                return const RemindersPage();
              },
              ReminderAlarmPage.route: (
                routeContext,
              ) {
                final arguments =
                    ModalRoute.of(
                  routeContext,
                )?.settings.arguments
                        as Map?;

                return ReminderAlarmPage(
                  title:
                      arguments?['title']
                              as String? ??
                          'Recordatorio',
                  description:
                      arguments?[
                              'description']
                          as String?,
                );
              },
              '/recommendations': (
                context,
              ) {
                return const RecommendationsScreen();
              },
              PreventiveInfoScreen.route: (
                context,
              ) {
                return const PreventiveInfoScreen();
              },
              SupportContactsScreen.route: (
                context,
              ) {
                return const SupportContactsScreen();
              },
              PanicButtonPage.route: (
                context,
              ) {
                return const PanicButtonPage();
              },
            },
          );
        },
      ),
    );
  }
}