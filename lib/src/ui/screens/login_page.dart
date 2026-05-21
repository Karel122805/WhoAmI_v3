// lib/src/ui/screens/login_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:whoami_app/services/fcm_token_service.dart';

import '../brand_logo.dart';
import '../theme.dart';
import 'home_caregiver.dart';
import 'home_consultant.dart';
import 'choice_start.dart';
import 'register_name_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const route = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscurePass = true;

  static const String _kLastResetTsKey = 'last_reset_email_at';
  static const Duration _resetCooldown = Duration(seconds: 60);
  DateTime? _lastResetEmailAt;

  Timer? _resetTimer;
  int _resetSecondsLeft = 0;

  Timer? _pulseTimer;
  bool _pulseUp = false;
  static const int _pulseThreshold = 10;

  final GlobalKey<_ShakeWidgetState> _passShakeKey =
      GlobalKey<_ShakeWidgetState>();

  bool _passwordError = false;
  String? _passwordErrorText;

  @override
  void initState() {
    super.initState();
    _prepareAuthForWeb();
    _loadCooldowns().then((_) => _startResetCountdownIfNeeded());
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _pulseTimer?.cancel();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _prepareAuthForWeb() async {
    if (!kIsWeb) return;
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {}
  }

  String _normalizeEmail(String v) => v.trim().toLowerCase();

  Future<void> _loadCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    final resMs = prefs.getInt(_kLastResetTsKey);
    if (resMs != null) {
      _lastResetEmailAt = DateTime.fromMillisecondsSinceEpoch(resMs);
    }
  }

  Future<void> _saveResetTs(DateTime when) async {
    _lastResetEmailAt = when;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastResetTsKey, when.millisecondsSinceEpoch);
  }

  void _startResetCountdownIfNeeded() {
    _resetTimer?.cancel();
    final now = DateTime.now();

    if (_lastResetEmailAt == null) {
      _resetSecondsLeft = 0;
      _stopPulse();
      if (mounted) setState(() {});
      return;
    }

    final elapsed = now.difference(_lastResetEmailAt!);
    final remaining = _resetCooldown - elapsed;
    _resetSecondsLeft = remaining.isNegative ? 0 : remaining.inSeconds;

    _updatePulseState();
    if (mounted) setState(() {});

    if (_resetSecondsLeft > 0) {
      _resetTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_resetSecondsLeft <= 1) {
          t.cancel();
          _resetSecondsLeft = 0;
          _stopPulse();
          setState(() {});
        } else {
          _resetSecondsLeft -= 1;
          _updatePulseState();
          setState(() {});
        }
      });
    }
  }

  void _updatePulseState() {
    if (_resetSecondsLeft > 0 && _resetSecondsLeft <= _pulseThreshold) {
      _startPulse();
    } else {
      _stopPulse();
    }
  }

  void _startPulse() {
    if (_pulseTimer != null) return;
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      _pulseUp = !_pulseUp;
      setState(() {});
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _pulseUp = false;
  }

  Map<String, String> _splitName(String? displayName) {
    final s = (displayName ?? '').trim();
    if (s.isEmpty) return {'firstName': '', 'lastName': ''};
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 1) return {'firstName': parts.first, 'lastName': ''};
    return {'firstName': parts.first, 'lastName': parts.sublist(1).join(' ')};
  }

  Future<void> _ensureUserProfile(User user) async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('users').doc(user.uid);
    final snap = await ref.get();
    final m = snap.data() ?? <String, dynamic>{};

    final googleName = _splitName(user.displayName);

    final existingFirst = ((m['firstName'] ?? '') as String).trim();
    final existingLast = ((m['lastName'] ?? '') as String).trim();

    final firstName =
        existingFirst.isNotEmpty ? existingFirst : (googleName['firstName'] ?? '');
    final lastName =
        existingLast.isNotEmpty ? existingLast : (googleName['lastName'] ?? '');

    String display = ((m['displayName'] ?? '') as String).trim();
    if (display.isEmpty) {
      final byName = '$firstName $lastName'.trim();
      display = byName.isNotEmpty
          ? byName
          : (user.displayName ?? user.email?.split('@').first ?? 'Usuario')
              .trim();
    }

    final payload = <String, dynamic>{
      'email': (user.email ?? '').toLowerCase(),
      'firstName': firstName,
      'lastName': lastName,
      'displayName': display,
      'displayNameLower': display.toLowerCase(),
      'photoURL': user.photoURL ?? (m['photoURL'] ?? ''),
      'authProvider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : (m['authProvider'] ?? ''),
      'role': (m['role'] ?? ''),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(payload, SetOptions(merge: true));
  }

  String? _emailRule(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Requerido';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s);
    return ok ? null : 'Ingresa un correo válido';
  }

  Future<void> _showDialogMsg(
    String title,
    String msg, {
    bool showVerifyButton = false,
    String? email,
  }) async {
    if (!mounted) return;

    final colors = context.appColors;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          msg,
          style: TextStyle(color: colors.textPrimary, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (showVerifyButton && email != null)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: colors.primaryButton,
                foregroundColor: colors.primaryButtonText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Enviar verificación',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && !user.emailVerified) {
                    await user.sendEmailVerification();
                    if (Navigator.canPop(context)) Navigator.pop(context);
                    await _showDialogMsg(
                      'Correo enviado',
                      'Se ha enviado un correo de verificación a $email.\n'
                      'Revisa tu bandeja de entrada.',
                    );
                  }
                } catch (_) {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  await _showDialogMsg(
                    'Error',
                    'No se pudo enviar el correo de verificación.',
                  );
                }
              },
            ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Aceptar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetDialog() async {
    if (!mounted) return;

    final colors = context.appColors;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Recuperar contraseña',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          '¿Deseas enviar un correo para restablecer tu contraseña?',
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancelar',
              style: TextStyle(color: colors.secondaryButton),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
            ),
            child: const Text('Enviar'),
            onPressed: () {
              Navigator.pop(context);
              _sendPasswordReset();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _normalizeEmail(_email.text);

    if (email.isEmpty) {
      await _showDialogMsg('Atención', 'Escribe tu correo para continuar.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      await _saveResetTs(DateTime.now());
      _startResetCountdownIfNeeded();

      await _showDialogMsg(
        'Revisa tu correo',
        'Si el correo está registrado, te enviamos un enlace para cambiar tu contraseña a:\n\n'
        '$email\n\nSi no lo ves, revisa también SPAM.',
      );
    } on FirebaseAuthException catch (e) {
      String msg =
          'No se pudo procesar la solicitud. Intenta nuevamente más tarde.';

      if (e.code == 'invalid-email') {
        msg = 'El correo ingresado no es válido.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Demasiados intentos. Intenta más tarde.';
      }

      await _showDialogMsg('Error', msg);
    } catch (_) {
      await _showDialogMsg(
        'Error',
        'Ocurrió un error al solicitar el cambio de contraseña.',
      );
    }
  }

  bool _isPasswordProvider(User u) =>
      u.providerData.any((p) => p.providerId == 'password');

  Future<void> _postLogin(User user) async {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    if (_isPasswordProvider(user)) {
      await user.reload();
      final refreshed = auth.currentUser;
      if (refreshed == null) {
        await _showDialogMsg('Error', 'La sesión no se pudo refrescar.');
        return;
      }
      if (!refreshed.emailVerified) {
        await _showDialogMsg(
          'Verifica tu correo',
          'Tu cuenta aún no ha sido verificada.',
          showVerifyButton: true,
          email: refreshed.email,
        );
        await auth.signOut();
        return;
      }
    }

    if (!kIsWeb) {
      try {
        await FCMTokenService.initAndSaveToken();
      } catch (_) {}
    }

    await _ensureUserProfile(user);

    final snap = await firestore.collection('users').doc(user.uid).get();
    final data = snap.data() ?? {};
    final role = (data['role'] as String?)?.trim() ?? '';

    final fullName =
        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    final name = fullName.isEmpty
        ? (user.displayName ?? user.email?.split('@').first ?? 'Usuario')
        : fullName;

    if (!mounted) return;

    if (role == 'Cuidador') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeCaregiverPage.route,
        (_) => false,
        arguments: {'name': name},
      );
    } else if (role == 'Consultante') {
      Navigator.pushNamedAndRemoveUntil(
        context,
        HomeConsultantPage.route,
        (_) => false,
        arguments: {'name': name},
      );
    } else {
      Navigator.pushNamed(
        context,
        RegisterNamePage.route,
        arguments: {
          'fromGoogle': true,
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'firstName': (data['firstName'] ?? '') as String,
          'lastName': (data['lastName'] ?? '') as String,
        },
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _passwordError = false;
      _passwordErrorText = null;
    });

    try {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        try {
          await auth.setPersistence(Persistence.LOCAL);
        } catch (_) {}

        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});

        final res = await auth.signInWithPopup(provider);
        final user = res.user;

        if (user == null) {
          await _showDialogMsg('Error', 'No se pudo iniciar sesión con Google.');
          return;
        }

        await _postLogin(user);
        return;
      }

      final googleSignIn = GoogleSignIn(scopes: ['email']);

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw PlatformException(
          code: 'missing-id-token',
          message:
              'Google no devolvió idToken. Revisa Play Services / cuenta / red.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final res = await auth.signInWithCredential(credential);
      final user = res.user;

      if (user == null) {
        await _showDialogMsg('Error', 'No se pudo iniciar sesión con Google.');
        return;
      }

      await _postLogin(user);
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'FirebaseAuthException Google code=${e.code} message=${e.message}');
      await _showDialogMsg(
        'Error Google (Firebase)',
        'code: ${e.code}\nmessage: ${e.message ?? ''}',
      );
    } on PlatformException catch (e) {
      debugPrint(
          'PlatformException Google code=${e.code} message=${e.message} details=${e.details}');
      await _showDialogMsg(
        'Error Google (Platform)',
        'code: ${e.code}\nmessage: ${e.message ?? ''}\ndetails: ${e.details ?? ''}',
      );
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      await _showDialogMsg('Error', 'Ocurrió un error con Google.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _passwordError = false;
      _passwordErrorText = null;
    });

    final email = _normalizeEmail(_email.text);
    final password = _pass.text.trim();

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      if (kIsWeb) {
        try {
          await auth.setPersistence(Persistence.LOCAL);
        } catch (_) {}
      }

      try {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;

        final colors = context.appColors;

        if (e.code == 'user-not-found') {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: colors.elevatedCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Correo no registrado',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              content: Text(
                'No existe ninguna cuenta asociada a este correo electrónico.\n\n'
                '¿Deseas registrarte con este correo?',
                style: TextStyle(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: colors.secondaryButton,
                    foregroundColor: colors.secondaryButtonText,
                  ),
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: colors.primaryButton,
                    foregroundColor: colors.primaryButtonText,
                  ),
                  child: const Text('Registrarme'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/register');
                  },
                ),
              ],
            ),
          );
          return;
        }

        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          setState(() {
            _passwordError = true;
            _passwordErrorText = 'Contraseña incorrecta.';
          });
          _pass.clear();
          _passShakeKey.currentState?.shake();
          return;
        }

        if (e.code == 'user-disabled') {
          await _showDialogMsg(
            'Cuenta deshabilitada',
            'Tu cuenta ha sido desactivada. Contacta al administrador.',
          );
          return;
        }

        if (e.code == 'invalid-email') {
          await _showDialogMsg(
            'Correo inválido',
            'El correo electrónico no es válido.',
          );
          return;
        }

        await _showDialogMsg(
          'Error',
          'No se pudo iniciar sesión. Código: ${e.code}',
        );
        return;
      }

      final user = auth.currentUser;
      if (user == null) {
        await _showDialogMsg('Error', 'No se pudo obtener la sesión del usuario.');
        return;
      }

      await user.reload();
      final refreshedUser = auth.currentUser;
      if (refreshedUser == null) {
        await _showDialogMsg('Error', 'La sesión no se pudo refrescar.');
        return;
      }

      if (!kIsWeb) {
        try {
          await FCMTokenService.initAndSaveToken();
        } catch (_) {}
      }

      if (!refreshedUser.emailVerified) {
        await _showDialogMsg(
          'Verifica tu correo',
          'Tu cuenta aún no ha sido verificada.',
          showVerifyButton: true,
          email: refreshedUser.email,
        );
        await auth.signOut();
        return;
      }

      await _ensureUserProfile(refreshedUser);

      final snap =
          await firestore.collection('users').doc(refreshedUser.uid).get();
      final data = snap.data() ?? {};
      final role = (data['role'] as String?)?.trim() ?? '';

      final fullName =
          '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();

      final name = fullName.isEmpty
          ? (refreshedUser.email?.split('@').first ?? 'Usuario')
          : fullName;

      if (!mounted) return;

      if (role == 'Cuidador') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomeCaregiverPage.route,
          (_) => false,
          arguments: {'name': name},
        );
      } else if (role == 'Consultante') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomeConsultantPage.route,
          (_) => false,
          arguments: {'name': name},
        );
      } else {
        await _showDialogMsg(
          'Cuenta sin rol',
          'Tu cuenta no tiene rol asignado.',
        );
      }
    } catch (_) {
      await _showDialogMsg('Error', 'Ocurrió un error al iniciar sesión.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final resetLabel = _resetSecondsLeft > 0
        ? '¿Olvidaste tu contraseña? (${_resetSecondsLeft}s)'
        : '¿Olvidaste tu contraseña?';

    final pulseScale =
        (_resetSecondsLeft > 0 && _resetSecondsLeft <= _pulseThreshold && _pulseUp)
            ? 1.06
            : 1.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                ChoiceStart.route,
                (_) => false,
              );
            }
          },
        ),
        title: Text(
          'Iniciar sesión',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Align(child: BrandLogo(size: 170)),
                    const SizedBox(height: 22),
                    const _FieldLabel('Correo electrónico'),
                    const SizedBox(height: 6),
                    _FieldBox(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailRule,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('Contraseña'),
                    const SizedBox(height: 6),
                    ShakeWidget(
                      key: _passShakeKey,
                      child: TextFormField(
                        controller: _pass,
                        obscureText: _obscurePass,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _loading ? null : _submit(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                        onChanged: (_) {
                          if (_passwordError) {
                            setState(() {
                              _passwordError = false;
                              _passwordErrorText = null;
                            });
                          }
                        },
                        style: TextStyle(color: colors.textPrimary),
                        decoration: InputDecoration(
                          errorText: _passwordError ? _passwordErrorText : null,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: colors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() => _obscurePass = !_obscurePass);
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedScale(
                        scale: pulseScale,
                        duration: const Duration(milliseconds: 300),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: colors.secondaryButton,
                          ),
                          onPressed: _resetSecondsLeft > 0
                              ? null
                              : _sendPasswordResetDialog,
                          child: Text(resetLabel),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      child: SizedBox(
                        width: 296,
                        height: 56,
                        child: FilledButton.icon(
                          style: pillLav(context),
                          onPressed: _loading ? null : _submit,
                          icon: Icon(
                            Icons.login_rounded,
                            color: colors.secondaryButtonText,
                          ),
                          label: _loading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.secondaryButtonText,
                                  ),
                                )
                              : Text(
                                  'Entrar',
                                  style: TextStyle(
                                    color: colors.secondaryButtonText,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(child: Divider(color: colors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'o continúa con',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                        Expanded(child: Divider(color: colors.border)),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Align(
                      child: SizedBox(
                        width: 296,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _signInWithGoogle,
                          icon: Icon(
                            Icons.g_mobiledata,
                            size: 28,
                            color: colors.textPrimary,
                          ),
                          label: Text(
                            'Continuar con Google',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.appColors.textPrimary,
        ),
      );
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.controller,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: colors.textPrimary),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class ShakeWidget extends StatefulWidget {
  const ShakeWidget({
    super.key,
    required this.child,
    this.magnitude = 10,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final double magnitude;
  final Duration duration;

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  Future<void> shake() async {
    if (!mounted) return;
    await _controller.forward(from: 0);
    if (!mounted) return;
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final t = _anim.value;
        final dx =
            math.sin(t * 3 * 2 * math.pi) * widget.magnitude * (1.0 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}