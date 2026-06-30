// lib/src/ui/screens/choice_start.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:whoami_app/src/core/widgets/brand_logo.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:whoami_app/src/features/register/presentation/pages/register_name_page.dart';
import 'package:whoami_app/src/core/services/permission_service.dart';
import 'package:whoami_app/src/core/tutorial/tutorial_keys.dart';
import 'package:whoami_app/src/core/tutorial/tutorial_manager.dart';

class ChoiceStart extends StatefulWidget {
  const ChoiceStart({super.key});

  static const route = '/auth/choice';

  @override
  State<ChoiceStart> createState() => _ChoiceStartState();
}

class _ChoiceStartState extends State<ChoiceStart> {
  bool acceptedTerms = false;
  bool acceptedPrivacy = false;

  static const String _privacyUrl =
      'https://whoami-app-1234.web.app/privacidad.html';
  static const String _termsUrl =
      'https://whoami-app-1234.web.app/terminos.html';

  @override
  void initState() {
    super.initState();
    PermissionService.askAllPermissionsOnce();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TutorialManager.maybeShow(
        context,
        TutorialKey.choiceStart,
      );
    });
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      final colors = context.appColors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.elevatedCard,
          content: Text(
            'No se pudo abrir el enlace: $url',
            style: TextStyle(color: colors.textPrimary),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool allowButtons = acceptedTerms && acceptedPrivacy;
    final colors = context.appColors;

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: AppBar(
          backgroundColor: colors.pageBackground,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Comencemos',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          iconTheme: IconThemeData(color: colors.textPrimary),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const BrandLogo(size: 160),
                    const SizedBox(height: 40),

                    // BOTÓN INICIAR SESIÓN
                    SizedBox(
                      width: 296,
                      height: 56,
                      child: FilledButton.icon(
                        style: pillLav(context),
                        icon: Icon(
                          Icons.login_rounded,
                          color: colors.secondaryButtonText,
                        ),
                        label: Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.secondaryButtonText,
                          ),
                        ),
                        onPressed: allowButtons
                            ? () => Navigator.pushNamed(
                                  context,
                                  LoginPage.route,
                                )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // BOTÓN REGISTRARSE
                    SizedBox(
                      width: 296,
                      height: 56,
                      child: FilledButton.icon(
                        style: pillBlue(context),
                        icon: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: colors.primaryButtonText,
                        ),
                        label: Text(
                          'Regístrate',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.primaryButtonText,
                          ),
                        ),
                        onPressed: allowButtons
                            ? () => Navigator.pushNamed(
                                  context,
                                  RegisterNamePage.route,
                                )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // CHECKBOXES + LINKS
                    Column(
                      children: [
                        // Términos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: acceptedTerms,
                              onChanged: (v) {
                                setState(() => acceptedTerms = v ?? false);
                              },
                              visualDensity: VisualDensity.compact,
                              activeColor: colors.primaryButton,
                              checkColor: colors.primaryButtonText,
                              side: BorderSide(color: colors.border),
                            ),
                            InkWell(
                              onTap: () => _openExternalUrl(_termsUrl),
                              child: Text(
                                "Términos y Condiciones",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  color: colors.primaryButton,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Política
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: acceptedPrivacy,
                              onChanged: (v) {
                                setState(() => acceptedPrivacy = v ?? false);
                              },
                              visualDensity: VisualDensity.compact,
                              activeColor: colors.primaryButton,
                              checkColor: colors.primaryButtonText,
                              side: BorderSide(color: colors.border),
                            ),
                            InkWell(
                              onTap: () => _openExternalUrl(_privacyUrl),
                              child: Text(
                                "Política de Privacidad",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  color: colors.primaryButton,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (!allowButtons)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Debes aceptar Términos y Política para continuar.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}





