// lib/src/features/profile/presentation/pages/settings_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:whoami_app/src/core/services/fcm_token_service.dart';

import 'package:whoami_app/src/features/auth/presentation/pages/choice_start.dart';
import 'package:whoami_app/src/core/widgets/user_avatar.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

// HU-03
import 'package:whoami_app/src/core/accessibility/accessibility_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.a11y});
  static const route = '/settings';

  final AccessibilityController a11y;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _db = FirebaseFirestore.instance;

  User? get _user => FirebaseAuth.instance.currentUser;
  String? get _uid => _user?.uid;

  bool _showTrashAnim = false;

  Future<void> _deleteAccount(BuildContext context) async {
    if (_uid == null || _user == null) return;

    final colors = context.appColors;

    final userDoc = await _db.collection('users').doc(_uid).get();
    final data = userDoc.data() ?? {};
    final role = (data['role'] ?? '').toString();

    String message;
    if (role == 'Consultante') {
      message =
          'Perderás todos tus recuerdos, fotos y datos vinculados. Tu cuidador dejará de verte en su lista.';
    } else if (role == 'Cuidador') {
      message =
          'Se eliminarán tus datos, tus consultantes dejarán de estar vinculados y no podrán verte más.';
    } else {
      message =
          'Esta acción eliminará permanentemente tu cuenta y toda tu información.';
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final passCtrl = TextEditingController();
        bool obscure = true;
        String? errorText;
        bool verifying = false;

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: colors.elevatedCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              '¿Eliminar cuenta?',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$message\n\nPor seguridad, ingresa tu contraseña para confirmar.',
                  style: TextStyle(color: colors.textPrimary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: TextStyle(color: colors.textPrimary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: colors.emergency,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  backgroundColor: colors.secondaryButton,
                  foregroundColor: colors.secondaryButtonText,
                ),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: verifying
                    ? null
                    : () async {
                        final password = passCtrl.text.trim();
                        if (password.isEmpty) {
                          setState(() =>
                              errorText = 'Por favor, ingresa tu contraseña.');
                          return;
                        }

                        setState(() {
                          verifying = true;
                          errorText = null;
                        });

                        try {
                          final cred = EmailAuthProvider.credential(
                            email: _user!.email!,
                            password: password,
                          );
                          await _user!.reauthenticateWithCredential(cred);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (_) {
                          setState(() {
                            errorText = 'Contraseña incorrecta.';
                            verifying = false;
                          });
                        }
                      },
                style: TextButton.styleFrom(
                  backgroundColor: colors.emergency,
                  foregroundColor: colors.emergencyText,
                ),
                child: verifying
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.emergencyText,
                        ),
                      )
                    : const Text('Eliminar cuenta'),
              ),
            ],
          );
        });
      },
    );

    if (confirm != true) return;

    try {
      if (role == 'Cuidador') {
        final patients = await _db
            .collection('users')
            .where('caregiverId', isEqualTo: _uid)
            .get();
        for (var doc in patients.docs) {
          await doc.reference.update({'caregiverId': null});
        }
      }

      if (!kIsWeb) {
        try {
          await FCMTokenService.clearToken();
        } catch (_) {}
      }

      await _db.collection('users').doc(_uid).delete();
      await _user?.delete();

      if (!mounted) return;

      setState(() => _showTrashAnim = true);
      await Future.delayed(const Duration(seconds: 3));
      setState(() => _showTrashAnim = false);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: colors.elevatedCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Cuenta eliminada',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Text(
              'Tu cuenta ha sido eliminada correctamente.',
              style: TextStyle(color: colors.textPrimary),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  foregroundColor: colors.primaryButtonText,
                ),
                onPressed: () async {
                  Navigator.of(context).pop();

                  await FirebaseAuth.instance.signOut();

                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      ChoiceStart.route,
                      (_) => false,
                    );
                  }
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.elevatedCard,
          content: Text(
            'Error al eliminar cuenta: $e',
            style: TextStyle(color: colors.textPrimary),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainUI(context),
        if (_showTrashAnim)
          AnimatedTrashAnimation(
            onDone: () => setState(() => _showTrashAnim = false),
          ),
      ],
    );
  }

  Widget _buildMainUI(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colors.pageBackground,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
        ),
        title: Text(
          'Ajustes',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  const UserAvatar(radius: 60),
                  const SizedBox(height: 14),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _uid != null
                        ? _db.collection('users').doc(_uid).snapshots()
                        : const Stream.empty(),
                    builder: (context, snap) {
                      if (!snap.hasData || !snap.data!.exists) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Usuario no encontrado',
                            style: TextStyle(color: colors.textPrimary),
                          ),
                        );
                      }

                      final me = snap.data!.data() ?? {};
                      final role = (me['role'] as String?)?.trim() ?? '';
                      final firstName =
                          (me['firstName'] as String?)?.trim() ?? '';
                      final lastName = (me['lastName'] as String?)?.trim() ?? '';
                      final caregiverId = me['caregiverId'] as String?;
                      final myName = [firstName, lastName]
                          .where((e) => e.isNotEmpty)
                          .join(' ');

                      final roleBg = role == 'Cuidador'
                          ? (context.isDark
                              ? colors.categoryPurple.withValues(alpha: 0.28)
                              : const Color(0xFFF5E9FC))
                          : (context.isDark
                              ? colors.categoryBlue.withValues(alpha: 0.28)
                              : const Color(0xFFE8F5FF));

                      final roleBorder = role == 'Cuidador'
                          ? (context.isDark
                              ? colors.categoryPurple
                              : const Color(0xFF9D4DCB))
                          : (context.isDark
                              ? colors.categoryBlue
                              : const Color(0xFF4C99E8));

                      return Column(
                        children: [
                          Text(
                            myName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              border: Border.all(
                                color: roleBorder,
                                width: 2.0,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                color: roleBorder,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (role == 'Consultante')
                            _buildCaregiverBlock(caregiverId)
                          else if (role == 'Cuidador')
                            _buildConsultantsBlock(_uid ?? ''),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  Text(
                    'Gestiona tu cuenta',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  _buildAccessibilityBlock(),
                  const SizedBox(height: 14),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibilityBlock() {
    return AnimatedBuilder(
      animation: widget.a11y,
      builder: (context, _) {
        final s = widget.a11y.settings;
        final colors = context.appColors;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accesibilidad',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tamaño de letra',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _sizeChip(
                    label: 'Normal',
                    selected: s.textSizeLevel == 0,
                    onTap: () => widget.a11y.setTextSizeLevel(0),
                    color: context.isDark
                        ? colors.categoryBlue
                        : const Color(0xFF9ED3FF),
                  ),
                  _sizeChip(
                    label: 'Medio',
                    selected: s.textSizeLevel == 1,
                    onTap: () => widget.a11y.setTextSizeLevel(1),
                    color: context.isDark
                        ? colors.categoryPurple
                        : const Color(0xFFD6A7F4),
                  ),
                  _sizeChip(
                    label: 'Grande',
                    selected: s.textSizeLevel == 2,
                    onTap: () => widget.a11y.setTextSizeLevel(2),
                    color: context.isDark
                        ? colors.categoryPink
                        : const Color(0xFFFFB3B3),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.darkMode,
                onChanged: (v) => widget.a11y.setDarkMode(v),
                title: Text(
                  'Modo oscuro',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Activa un tema oscuro en toda la app.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.simplified,
                onChanged: (v) => widget.a11y.setSimplified(v),
                title: Text(
                  'Modo simplificado',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Reduce efectos y hace la interfaz más simple.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sizeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final colors = context.appColors;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: context.isDark ? 0.38 : 0.65),
      backgroundColor: colors.elevatedCard,
      side: BorderSide(
        color: selected ? color : colors.border,
        width: selected ? 1.8 : 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildCaregiverBlock(String? caregiverId) {
    final colors = context.appColors;

    if (caregiverId == null || caregiverId.isEmpty) {
      final bg = context.isDark
          ? colors.categoryPurple.withValues(alpha: 0.18)
          : const Color(0xFFD6A7F4).withValues(alpha: 0.2);
      final border =
          context.isDark ? colors.categoryPurple : const Color(0xFF9D4DCB);

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 2.0),
        ),
        child: Text(
          'No tienes un cuidador asignado actualmente.',
          style: TextStyle(
            color: border,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _db.collection('users').doc(caregiverId).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return CircularProgressIndicator(color: colors.primaryButton);
        }
        final data = snap.data!.data() as Map<String, dynamic>?;
        final name = data != null
            ? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim()
            : '(Desconocido)';

        final bg = context.isDark
            ? colors.categoryPurple.withValues(alpha: 0.18)
            : const Color(0xFFD6A7F4).withValues(alpha: 0.2);
        final border =
            context.isDark ? colors.categoryPurple : const Color(0xFF9D4DCB);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 2.0),
          ),
          child: Text(
            'Tu cuidador: $name',
            style: TextStyle(
              color: border,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsultantsBlock(String caregiverId) {
    final colors = context.appColors;

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('caregiverId', isEqualTo: caregiverId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return CircularProgressIndicator(color: colors.primaryButton);
        }
        final patients = snap.data!.docs;

        final bg = context.isDark
            ? colors.categoryBlue.withValues(alpha: 0.18)
            : const Color(0xFF9ED3FF).withValues(alpha: 0.2);
        final border =
            context.isDark ? colors.categoryBlue : const Color(0xFF4C99E8);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 2.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tus consultantes:',
                style: TextStyle(
                  color: border,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              if (patients.isEmpty)
                Text(
                  'Aún no tienes consultantes asignados.',
                  style: TextStyle(
                    color: border,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              for (var doc in patients)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: border),
                    const SizedBox(width: 6),
                    Text(
                      '${doc['firstName']} ${doc['lastName']}',
                      style: TextStyle(
                        color: border,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () =>
                Navigator.pushNamed(context, '/settings/edit-profile'),
            icon: const Icon(Icons.person_outline),
            label: const Text('Perfil'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () async {
              try {
                if (!kIsWeb) {
                  try {
                    await FCMTokenService.unregisterCurrentDeviceToken();
                  } catch (_) {}
                }

                await FirebaseAuth.instance.signOut();

                if (!mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: colors.elevatedCard,
                    content: Text(
                      'Error al cerrar sesión: $e',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () => _deleteAccount(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Eliminar cuenta'),
          ),
        ),
      ],
    );
  }
}

class AnimatedTrashAnimation extends StatefulWidget {
  final VoidCallback onDone;
  const AnimatedTrashAnimation({super.key, required this.onDone});

  @override
  State<AnimatedTrashAnimation> createState() => _AnimatedTrashAnimationState();
}

class _AnimatedTrashAnimationState extends State<AnimatedTrashAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _paperAnim;
  late Animation<double> _lidAnim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _paperAnim = Tween<double>(begin: -1, end: 0.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _lidAnim = Tween<double>(begin: 0, end: -0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      color: context.isDark
          ? Colors.black.withValues(alpha: 0.88)
          : Colors.white.withValues(alpha: 0.95),
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, 200 * _paperAnim.value),
                child: Icon(
                  Icons.description_outlined,
                  size: 60,
                  color: colors.textSecondary,
                ),
              ),
              Positioned(
                bottom: 200,
                child: Icon(
                  Icons.delete_outline,
                  size: 100,
                  color: colors.textPrimary,
                ),
              ),
              Positioned(
                bottom: 280,
                child: Transform.rotate(
                  angle: _lidAnim.value,
                  origin: const Offset(30, 10),
                  child: Icon(
                    Icons.horizontal_rule_rounded,
                    size: 100,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
