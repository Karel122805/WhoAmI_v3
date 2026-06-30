// lib/src/ui/screens/register_name_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:whoami_app/src/core/tutorial/tutorial_keys.dart';
import 'package:whoami_app/src/core/tutorial/tutorial_manager.dart';

import 'package:whoami_app/src/core/widgets/brand_logo.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'register_password_page.dart';

class RegisterNamePage extends StatefulWidget {
  const RegisterNamePage({super.key});
  static const route = '/register/name';

  @override
  State<RegisterNamePage> createState() => _RegisterNamePageState();
}

class _RegisterNamePageState extends State<RegisterNamePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _dobCtrl = TextEditingController();

  DateTime? _birthday;
  String? _birthdayError;

  bool _fromGoogle = false;
  String? _uid;
  String? _email;
  String? _photoURL;

  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _loadArgsIfNeeded();

      if (!mounted) return;

      await TutorialManager.maybeShow(
        context,
        TutorialKey.registerName,
      );
    });
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime get _today => DateTime.now();
  DateTime get _adultCutoff =>
      DateTime(_today.year - 18, _today.month, _today.day);

  bool _isAdult(DateTime date) {
    final t = _today;
    final age = t.year -
        date.year -
        ((t.month < date.month || (t.month == date.month && t.day < date.day))
            ? 1
            : 0);
    return age >= 18;
  }

  DateTime? _parseDob(String s) {
    final p = s.split('/');
    if (p.length != 3) return null;

    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);

    if (d == null || m == null || y == null) return null;
    if (m < 1 || m > 12) return null;
    if (d < 1 || d > 31) return null;
    if (y < 1900 || y > DateTime.now().year) return null;

    try {
      final dt = DateTime(y, m, d);
      if (dt.day == d && dt.month == m && dt.year == y) return dt;
    } catch (_) {}
    return null;
  }

  void _onDobChanged(String _) {
    final dt = _parseDob(_dobCtrl.text);
    setState(() {
      _birthday = dt;
      _birthdayError = null;
    });
  }

  Future<void> _pickDob() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'MX'),
      initialDate: _birthday ?? _adultCutoff,
      firstDate: DateTime(1900),
      lastDate: _adultCutoff,
      helpText: 'Selecciona tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        _birthday = DateTime(picked.year, picked.month, picked.day);
        _dobCtrl.text = _fmt(_birthday!);
        _birthdayError = null;
      });
    }
  }

  void _loadArgsIfNeeded() {
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    _fromGoogle = (args['fromGoogle'] == true);
    _uid = args['uid'] as String?;
    _email = args['email'] as String?;
    _photoURL = args['photoURL'] as String?;

    final first = (args['firstName'] as String?)?.trim() ?? '';
    final last = (args['lastName'] as String?)?.trim() ?? '';

    if (_nombre.text.trim().isEmpty && first.isNotEmpty) _nombre.text = first;
    if (_apellidos.text.trim().isEmpty && last.isNotEmpty) {
      _apellidos.text = last;
    }

    setState(() {});
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();

    final validForm = _formKey.currentState!.validate();

    final dob = _parseDob(_dobCtrl.text);
    if (dob == null) {
      setState(
        () => _birthdayError = 'Fecha inválida. Usa el formato dd/mm/aaaa',
      );
      return;
    }
    if (!_isAdult(dob)) {
      setState(() => _birthdayError = 'Debes tener al menos 18 años');
      return;
    }

    setState(() {
      _birthday = dob;
      _birthdayError = null;
    });

    if (!validForm) return;

    Navigator.pushNamed(
      context,
      RegisterPasswordPage.route,
      arguments: {
        'nombre': _nombre.text.trim(),
        'apellidos': _apellidos.text.trim(),
        'birthday': _birthday!.toIso8601String(),
        'fromGoogle': _fromGoogle,
        'uid': _uid,
        'email': _email,
        'photoURL': _photoURL,
      },
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = _fromGoogle ? 'Completa tu perfil' : 'Regístrate';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.pageBackground,
        appBar: AppBar(
          backgroundColor: colors.pageBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.maybePop(context);
          },
        ),
          centerTitle: true,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Align(child: BrandLogo(size: 170)),
                      const SizedBox(height: 22),

                      const _FieldLabel('Nombre'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nombre,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Tu nombre',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),

                      const SizedBox(height: 14),

                      const _FieldLabel('Apellidos'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _apellidos,
                        style: TextStyle(color: colors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Tus apellidos',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Los apellidos son obligatorios'
                            : null,
                      ),

                      const SizedBox(height: 14),

                      const _FieldLabel('Fecha de nacimiento'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dobCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: _onDobChanged,
                        style: TextStyle(color: colors.textPrimary),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                          const _DateSlashFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText: 'dd/mm/aaaa',
                          suffixIcon: IconButton(
                            tooltip: 'Elegir en calendario',
                            icon: Icon(
                              Icons.calendar_today,
                              color: colors.textSecondary,
                            ),
                            onPressed: _pickDob,
                          ),
                        ),
                      ),
                      if (_birthdayError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _birthdayError!,
                            style: TextStyle(
                              color: colors.emergency,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      const SizedBox(height: 28),

                      Align(
                        child: SizedBox(
                          width: 296,
                          height: 56,
                          child: FilledButton(
                            style: pillBlue(context),
                            onPressed: _next,
                            child: Text(
                              'Siguiente',
                              style: TextStyle(
                                color: colors.primaryButtonText,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
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

class _DateSlashFormatter extends TextInputFormatter {
  const _DateSlashFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buf.write(digits[i]);
      if (i == 1 || i == 3) buf.write('/');
    }

    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}





