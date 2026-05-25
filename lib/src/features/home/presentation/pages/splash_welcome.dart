import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/widgets/brand_logo.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/auth/presentation/pages/choice_start.dart';

import 'package:whoami_app/src/core/services/permission_service.dart';

class SplashWelcome extends StatefulWidget {
  const SplashWelcome({super.key});
  static const route = '/';

  @override
  State<SplashWelcome> createState() => _SplashWelcomeState();
}

class _SplashWelcomeState extends State<SplashWelcome> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await PermissionService.requestCameraAndGallery();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandLogo(size: 190),
                    const SizedBox(height: 20),
                    Text(
                      'BIENVENIDO A',
                      style: welcomeKicker(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'WhoAmI?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 296,
                      height: 56,
                      child: FilledButton(
                        style: pillBlue(context),
                        onPressed: () =>
                            Navigator.pushNamed(context, ChoiceStart.route),
                        child: Text(
                          'Comenzar',
                          style: TextStyle(
                            color: colors.primaryButtonText,
                          ),
                        ),
                      ),
                    ),
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





