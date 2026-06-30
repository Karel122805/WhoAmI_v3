import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  static const route = '/settings/edit-profile';

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _genderCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _stageCtrl = TextEditingController();
  final _bloodTypeCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _doctorNameCtrl = TextEditingController();
  final _doctorPhoneCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;

  DateTime? _birthDate;
  String? _photoUrl;
  File? _localPhoto;

  Map<String, String?> _original = {};

  final List<String> _genderOptions = const [
    'Masculino',
    'Femenino',
    'Otro',
    'Prefiero no decirlo',
  ];

  final List<String> _stageOptions = const [
    'Leve',
    'Moderada',
    'Avanzada',
    'No especificada',
  ];

  final List<String> _bloodTypeOptions = const [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'No especificado',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _showDialogOk({
    required String title,
    required String message,
    IconData? icon,
    bool success = true,
  }) async {
    if (!mounted) return;

    final colors = context.appColors;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: success ? colors.categoryGreen : colors.emergency,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Aceptar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmBeforeLeave() async {
    if (!_dirty) return true;

    final colors = context.appColors;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cambios sin guardar',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Tienes cambios sin guardar. ¿Deseas salir y descartarlos?',
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Seguir editando',
              style: TextStyle(color: colors.primaryButton),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleBackNavigation() async {
    final canLeave = await _confirmBeforeLeave();

    if (!mounted || !canLeave) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/settings',
      (route) => false,
    );
  }

  String _fmt(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  DateTime? _parseBirthDate(dynamic raw) {
    if (raw == null) return null;

    try {
      if (raw is Timestamp) return raw.toDate();
    } catch (_) {}

    if (raw is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      } catch (_) {}
    }

    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        final parts = raw.split('/');

        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);

          if (day != null && month != null && year != null) {
            final parsed = DateTime(year, month, day);

            if (parsed.year == year &&
                parsed.month == month &&
                parsed.day == day) {
              return parsed;
            }
          }
        }
      }
    }

    return null;
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;

    final now = DateTime.now();
    int age = now.year - birthDate.year;

    final hasHadBirthdayThisYear = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);

    if (!hasHadBirthdayThisYear) age--;

    return age < 0 ? 0 : age;
  }

  void _updateAgeController() {
    final age = _calculateAge(_birthDate);
    _ageCtrl.text = age == null ? '' : age.toString();
  }

  String _safeString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? <String, dynamic>{};
      final medicalInfo = data['medicalInfo'] is Map
          ? Map<String, dynamic>.from(data['medicalInfo'])
          : <String, dynamic>{};

      _firstName.text = _safeString(data['firstName']);
      _lastName.text = _safeString(data['lastName']);
      _email.text = _safeString(data['email']).isNotEmpty
          ? _safeString(data['email'])
          : (user.email ?? '');
      _phoneCtrl.text = _safeString(data['phone']);
      _addressCtrl.text = _safeString(data['address']);

      _genderCtrl.text = _safeString(data['gender']);

      _diagnosisCtrl.text = _safeString(medicalInfo['diagnosis']);
      _stageCtrl.text = _safeString(medicalInfo['stage']);
      _bloodTypeCtrl.text = _safeString(medicalInfo['bloodType']);
      _allergiesCtrl.text = _safeString(medicalInfo['allergies']);
      _medicationsCtrl.text = _safeString(medicalInfo['medications']);
      _doctorNameCtrl.text = _safeString(medicalInfo['doctorName']);
      _doctorPhoneCtrl.text = _safeString(medicalInfo['doctorPhone']);
      _medicalNotesCtrl.text = _safeString(medicalInfo['notes']);

      _photoUrl = _safeString(data['photoURL']).isNotEmpty
          ? _safeString(data['photoURL'])
          : user.photoURL;

      final rawDob = data['birthDate'] ??
          data['birthday'] ??
          data['dob'] ??
          data['dateOfBirth'];

      _birthDate = _parseBirthDate(rawDob);
      _dobCtrl.text = _birthDate == null ? '' : _fmt(_birthDate!);
      _updateAgeController();

      _original = {
        'firstName': _firstName.text,
        'lastName': _lastName.text,
        'email': _email.text,
        'photo': _photoUrl,
        'birthDate': _birthDate?.toIso8601String(),
        'phone': _phoneCtrl.text,
        'address': _addressCtrl.text,
        'gender': _genderCtrl.text,
        'diagnosis': _diagnosisCtrl.text,
        'stage': _stageCtrl.text,
        'bloodType': _bloodTypeCtrl.text,
        'allergies': _allergiesCtrl.text,
        'medications': _medicationsCtrl.text,
        'doctorName': _doctorNameCtrl.text,
        'doctorPhone': _doctorPhoneCtrl.text,
        'medicalNotes': _medicalNotesCtrl.text,
      };

      _localPhoto = null;
      _dirty = false;
    } catch (_) {
      await _showDialogOk(
        title: 'Error',
        message: 'No se pudo cargar la información del perfil.',
        icon: Icons.error_outline,
        success: false,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recomputeDirty() {
    final birthIso = _birthDate?.toIso8601String();

    final textChanged =
        _firstName.text.trim() != (_original['firstName'] ?? '') ||
            _lastName.text.trim() != (_original['lastName'] ?? '') ||
            _email.text.trim() != (_original['email'] ?? '') ||
            birthIso != _original['birthDate'] ||
            _phoneCtrl.text.trim() != (_original['phone'] ?? '') ||
            _addressCtrl.text.trim() != (_original['address'] ?? '') ||
            _genderCtrl.text.trim() != (_original['gender'] ?? '') ||
            _diagnosisCtrl.text.trim() != (_original['diagnosis'] ?? '') ||
            _stageCtrl.text.trim() != (_original['stage'] ?? '') ||
            _bloodTypeCtrl.text.trim() != (_original['bloodType'] ?? '') ||
            _allergiesCtrl.text.trim() != (_original['allergies'] ?? '') ||
            _medicationsCtrl.text.trim() != (_original['medications'] ?? '') ||
            _doctorNameCtrl.text.trim() != (_original['doctorName'] ?? '') ||
            _doctorPhoneCtrl.text.trim() != (_original['doctorPhone'] ?? '') ||
            _medicalNotesCtrl.text.trim() !=
                (_original['medicalNotes'] ?? '');

    final photoChanged = _localPhoto != null;
    final newDirty = textChanged || photoChanged;

    if (newDirty != _dirty && mounted) {
      setState(() => _dirty = newDirty);
    }
  }

  void _restoreOriginal() {
    _firstName.text = _original['firstName'] ?? '';
    _lastName.text = _original['lastName'] ?? '';
    _email.text = _original['email'] ?? '';
    _photoUrl = _original['photo'];
    _phoneCtrl.text = _original['phone'] ?? '';
    _addressCtrl.text = _original['address'] ?? '';

    _genderCtrl.text = _original['gender'] ?? '';
    _diagnosisCtrl.text = _original['diagnosis'] ?? '';
    _stageCtrl.text = _original['stage'] ?? '';
    _bloodTypeCtrl.text = _original['bloodType'] ?? '';
    _allergiesCtrl.text = _original['allergies'] ?? '';
    _medicationsCtrl.text = _original['medications'] ?? '';
    _doctorNameCtrl.text = _original['doctorName'] ?? '';
    _doctorPhoneCtrl.text = _original['doctorPhone'] ?? '';
    _medicalNotesCtrl.text = _original['medicalNotes'] ?? '';

    final origDob = _original['birthDate'];
    _birthDate = origDob == null ? null : DateTime.tryParse(origDob);
    _dobCtrl.text = _birthDate == null ? '' : _fmt(_birthDate!);
    _updateAgeController();

    _localPhoto = null;
    _dirty = false;

    if (mounted) setState(() {});
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es'),
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Selecciona tu fecha de nacimiento',
    );

    if (picked != null) {
      setState(() {
        _birthDate = DateTime(picked.year, picked.month, picked.day);
        _dobCtrl.text = _fmt(_birthDate!);
        _updateAgeController();
      });

      _recomputeDirty();
    }
  }
    Future<void> _showPhotoViewer() async {
    final colors = context.appColors;
    final hasPhoto = _localPhoto != null || (_photoUrl?.isNotEmpty ?? false);

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.elevatedCard,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Foto de perfil',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: hasPhoto
                      ? (_localPhoto != null
                          ? Image.file(_localPhoto!, fit: BoxFit.cover)
                          : Image.network(_photoUrl!, fit: BoxFit.cover))
                      : Container(
                          color: colors.inputFill,
                          child: Icon(
                            Icons.person,
                            size: 100,
                            color: colors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.secondaryButton,
                  foregroundColor: colors.secondaryButtonText,
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _pickPhoto();
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text(
                  'Cambiar foto',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.elevatedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text(
                'Seleccionar foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Divider(height: 20, color: colors.border),
              ListTile(
                leading: Icon(
                  Icons.visibility_outlined,
                  color: colors.textPrimary,
                ),
                title: Text(
                  'Ver foto actual',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showPhotoViewer();
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.camera_alt_outlined, color: colors.textPrimary),
                title: Text(
                  'Tomar foto',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  final img = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );

                  if (img != null) {
                    setState(() => _localPhoto = File(img.path));
                    _recomputeDirty();
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_outlined, color: colors.textPrimary),
                title: Text(
                  'Elegir de galería',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  final img = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );

                  if (img != null) {
                    setState(() => _localPhoto = File(img.path));
                    _recomputeDirty();
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadPhoto(User user) async {
    if (_localPhoto == null) return _photoUrl;

    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('avatar.jpg');

    final task = await ref.putFile(
      _localPhoto!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    if (task.state == TaskState.success) {
      return await ref.getDownloadURL();
    }

    return _photoUrl;
  }

  Future<void> _requestPasswordReset() async {
    final email = _email.text.trim().toLowerCase();

    if (email.isEmpty) {
      await _showDialogOk(
        title: 'Correo no disponible',
        message: 'Tu cuenta no tiene un correo válido.',
        icon: Icons.info_outline,
        success: false,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      await _showDialogOk(
        title: 'Revisa tu correo',
        message:
            'Te enviamos un enlace para cambiar tu contraseña a:\n\n$email\n\nSi no lo ves, revisa también SPAM.',
        icon: Icons.mark_email_read_outlined,
      );
    } catch (_) {
      await _showDialogOk(
        title: 'No se pudo enviar',
        message: 'Ocurrió un error inesperado al enviar el correo.',
        icon: Icons.error_outline,
        success: false,
      );
    }
  }

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final colors = context.appColors;
    final newEmailCtrl = TextEditingController(text: _email.text.trim());
    final passCtrl = TextEditingController();
    bool obscurePass = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.elevatedCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Cambiar correo',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Para cambiar tu correo, confirma tu contraseña actual. Después recibirás un enlace de verificación en el nuevo correo.',
                  style: TextStyle(color: colors.textPrimary),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo correo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña actual',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setDialogState(() {
                          obscurePass = !obscurePass;
                        });
                      },
                      icon: Icon(
                        obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primaryButton,
                foregroundColor: colors.primaryButtonText,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Enviar verificación',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      newEmailCtrl.dispose();
      passCtrl.dispose();
      return;
    }

    final newEmail = newEmailCtrl.text.trim().toLowerCase();
    final currentPass = passCtrl.text.trim();

    newEmailCtrl.dispose();
    passCtrl.dispose();

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      await _showDialogOk(
        title: 'Correo inválido',
        message: 'Escribe un correo válido.',
        icon: Icons.error_outline,
        success: false,
      );
      return;
    }

    if (user.email == null || user.email!.isEmpty) {
      await _showDialogOk(
        title: 'No disponible',
        message:
            'Esta cuenta no tiene correo principal disponible para cambiar.',
        icon: Icons.error_outline,
        success: false,
      );
      return;
    }

    if (newEmail == user.email!.trim().toLowerCase()) {
      await _showDialogOk(
        title: 'Sin cambios',
        message: 'El nuevo correo es igual al correo actual.',
        icon: Icons.info_outline,
        success: false,
      );
      return;
    }

    if (currentPass.isEmpty) {
      await _showDialogOk(
        title: 'Falta contraseña',
        message: 'Debes escribir tu contraseña actual.',
        icon: Icons.error_outline,
        success: false,
      );
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPass,
      );

      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(newEmail);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pendingEmail': newEmail,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      await _showDialogOk(
        title: 'Verifica tu nuevo correo',
        message:
            'Te enviamos un enlace de verificación a:\n\n$newEmail\n\nEl cambio se aplicará cuando confirmes ese correo.',
        icon: Icons.mark_email_read_outlined,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo solicitar el cambio de correo.';

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'La contraseña actual es incorrecta.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Ese correo ya está en uso.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo nuevo no es válido.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Debes volver a iniciar sesión antes de cambiar tu correo.';
      } else if (e.code == 'operation-not-allowed') {
        message =
            'El cambio de correo no está habilitado para este método de inicio de sesión.';
      }

      await _showDialogOk(
        title: 'Error',
        message: message,
        icon: Icons.error_outline,
        success: false,
      );
    } catch (_) {
      await _showDialogOk(
        title: 'Error',
        message:
            'Ocurrió un problema inesperado al solicitar el cambio de correo.',
        icon: Icons.error_outline,
        success: false,
      );
    }
  }

  Future<void> _save({bool exitAfter = false}) async {
    if (!_dirty) {
      await _showDialogOk(
        title: 'Sin cambios',
        message: 'No hay cambios para guardar.',
        icon: Icons.info_outline,
        success: false,
      );
      return;
    }

    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      await _showDialogOk(
        title: 'Campos obligatorios',
        message: 'Nombre y apellidos no pueden quedar vacíos.',
        icon: Icons.error_outline,
        success: false,
      );
      return;
    }

    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      if (_localPhoto != null) {
        final url = await _uploadPhoto(user);

        if (url != null) {
          _photoUrl = url;
          await user.updatePhotoURL(url);

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {'photoURL': url},
            SetOptions(merge: true),
          );
        }
      }

      final displayName =
          '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();

      final updates = <String, dynamic>{
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
        'email': _email.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'gender': _genderCtrl.text.trim(),
        'medicalInfo': {
          'diagnosis': _diagnosisCtrl.text.trim(),
          'stage': _stageCtrl.text.trim(),
          'bloodType': _bloodTypeCtrl.text.trim(),
          'allergies': _allergiesCtrl.text.trim(),
          'medications': _medicationsCtrl.text.trim(),
          'doctorName': _doctorNameCtrl.text.trim(),
          'doctorPhone': _doctorPhoneCtrl.text.trim(),
          'notes': _medicalNotesCtrl.text.trim(),
        },
        'updatedAt': Timestamp.now(),
      };

      if (_birthDate != null) {
        updates['birthDate'] = Timestamp.fromDate(_birthDate!);
        updates['birthday'] = Timestamp.fromDate(_birthDate!);
      } else {
        updates['birthDate'] = null;
        updates['birthday'] = null;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updates, SetOptions(merge: true));

      if (displayName != (user.displayName ?? '').trim()) {
        await user.updateDisplayName(displayName);
      }

      await user.reload();
      await _load();

      _localPhoto = null;
      _dirty = false;

      if (mounted) setState(() {});

      await _showDialogOk(
        title: 'Listo',
        message: 'Cambios guardados exitosamente.',
        icon: Icons.check_circle_outline,
      );

      if (exitAfter && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/settings',
          (route) => false,
        );
      }
    } catch (_) {
      await _showDialogOk(
        title: 'Error',
        message: 'No se pudieron guardar los cambios.',
        icon: Icons.error_outline,
        success: false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool enabled = true,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    final colors = context.appColors;

    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onTap: onTap,
      onChanged: onChanged,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required List<String> options,
  }) {
    final colors = context.appColors;
    final currentValue =
        options.contains(controller.text.trim()) ? controller.text.trim() : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      isExpanded: true,
      dropdownColor: colors.elevatedCard,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        controller.text = value ?? '';
        _recomputeDirty();
      },
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: colors.primaryButton),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    final colors = context.appColors;

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Colors.black,
        size: 20,
      ),
      label: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: colors.secondaryButton,
        foregroundColor: Colors.black,
        disabledBackgroundColor: colors.secondaryButton.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        minimumSize: const Size.fromHeight(46),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasPhoto = _localPhoto != null || (_photoUrl?.isNotEmpty ?? false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.pageBackground,
          foregroundColor: colors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Perfil',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: CircularProgressIndicator(
                        color: colors.primaryButton,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                GestureDetector(
                                  onTap: _showPhotoViewer,
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundImage: _localPhoto != null
                                        ? FileImage(_localPhoto!)
                                        : (_photoUrl != null &&
                                                _photoUrl!.isNotEmpty
                                            ? NetworkImage(_photoUrl!)
                                            : null) as ImageProvider<Object>?,
                                    backgroundColor: colors.cardBackground,
                                    child: !hasPhoto
                                        ? Icon(
                                            Icons.person,
                                            size: 52,
                                            color: colors.textSecondary,
                                          )
                                        : null,
                                  ),
                                ),
                                Material(
                                  color: colors.secondaryButton,
                                  shape: const CircleBorder(),
                                  elevation: 3,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _pickPhoto,
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(
                                        Icons.photo_camera_outlined,
                                        color: Colors.black,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTopActionButton(
                                  icon: Icons.visibility_outlined,
                                  text: 'Ver foto',
                                  onPressed: _showPhotoViewer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTopActionButton(
                                  icon: Icons.alternate_email_outlined,
                                  text: 'Cambiar correo',
                                  onPressed: _changeEmail,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          _buildSectionTitle(
                            icon: Icons.person_outline,
                            title: 'Información personal',
                          ),
                          _buildTextField(
                            controller: _firstName,
                            label: 'Nombre',
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _lastName,
                            label: 'Apellidos',
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _dobCtrl,
                            label: 'Fecha de nacimiento',
                            readOnly: true,
                            suffixIcon: Icon(
                              Icons.calendar_today_outlined,
                              color: colors.textSecondary,
                            ),
                            onTap: _pickBirthDate,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _ageCtrl,
                            label: 'Edad',
                            enabled: false,
                            readOnly: true,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            controller: _genderCtrl,
                            label: 'Sexo',
                            options: _genderOptions,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _email,
                            label: 'Correo electrónico',
                            keyboardType: TextInputType.emailAddress,
                            enabled: false,
                            suffixIcon: Icon(
                              Icons.lock_outline,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _phoneCtrl,
                            label: 'Teléfono (opcional)',
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _addressCtrl,
                            label: 'Dirección (opcional)',
                            maxLines: 2,
                            keyboardType: TextInputType.streetAddress,
                            onChanged: (_) => _recomputeDirty(),
                          ),

                          const SizedBox(height: 18),
                          Divider(color: colors.border),
                          _buildSectionTitle(
                            icon: Icons.medical_information_outlined,
                            title: 'Información médica',
                          ),
                          _buildTextField(
                            controller: _diagnosisCtrl,
                            label: 'Enfermedad o diagnóstico principal',
                            hint: 'Ej. Alzheimer, deterioro cognitivo...',
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            controller: _stageCtrl,
                            label: 'Etapa o estado',
                            options: _stageOptions,
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            controller: _bloodTypeCtrl,
                            label: 'Tipo de sangre',
                            options: _bloodTypeOptions,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _allergiesCtrl,
                            label: 'Alergias',
                            hint: 'Ej. Penicilina, alimentos, polvo...',
                            maxLines: 2,
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _medicationsCtrl,
                            label: 'Medicamentos actuales',
                            hint: 'Ej. Nombre, dosis y horario',
                            maxLines: 3,
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _doctorNameCtrl,
                            label: 'Médico tratante',
                            hint: 'Nombre del médico',
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _doctorPhoneCtrl,
                            label: 'Teléfono del médico',
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => _recomputeDirty(),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _medicalNotesCtrl,
                            label: 'Notas importantes',
                            hint: 'Indicaciones, cuidados o alertas importantes',
                            maxLines: 4,
                            onChanged: (_) => _recomputeDirty(),
                          ),

                          const SizedBox(height: 22),
                          Divider(color: colors.border),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.secondaryButton,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _requestPasswordReset,
                              icon: const Icon(
                                Icons.lock_reset,
                                color: Colors.black,
                              ),
                              label: const Text(
                                'Solicitar cambio de contraseña',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _dirty ? _restoreOriginal : null,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: colors.emergencyText,
                                  ),
                                  label: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      color: colors.emergencyText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.emergency,
                                    disabledBackgroundColor:
                                        colors.emergency.withValues(alpha: 0.45),
                                    disabledForegroundColor: colors.emergencyText
                                        .withValues(alpha: 0.7),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed:
                                      (_saving || !_dirty) ? null : () => _save(),
                                  icon: _saving
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.primaryButtonText,
                                          ),
                                        )
                                      : Icon(
                                          Icons.save_outlined,
                                          color: colors.primaryButtonText,
                                        ),
                                  label: Text(
                                    _saving ? 'Guardando...' : 'Guardar',
                                    style: TextStyle(
                                      color: colors.primaryButtonText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.primaryButton,
                                    disabledBackgroundColor: colors.primaryButton
                                        .withValues(alpha: 0.45),
                                    disabledForegroundColor: colors
                                        .primaryButtonText
                                        .withValues(alpha: 0.7),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!_dirty && !_saving)
                            Text(
                              'Modifica tus datos para habilitar Guardar y Cancelar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
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

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _dobCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();

    _genderCtrl.dispose();
    _diagnosisCtrl.dispose();
    _stageCtrl.dispose();
    _bloodTypeCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicationsCtrl.dispose();
    _doctorNameCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    _medicalNotesCtrl.dispose();

    super.dispose();
  }
}