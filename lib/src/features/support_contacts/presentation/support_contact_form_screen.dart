import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

import '../data/support_contacts_service.dart';
import '../models/support_contact_model.dart';

class SupportContactFormScreen extends StatefulWidget {
  const SupportContactFormScreen({
    super.key,
    this.contact,
  });

  final SupportContactModel? contact;

  @override
  State<SupportContactFormScreen> createState() =>
      _SupportContactFormScreenState();
}

class _SupportContactFormScreenState extends State<SupportContactFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  bool _saving = false;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController = TextEditingController(text: widget.contact?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _saving = true);

    try {
      if (_isEditing) {
        await SupportContactsService.updateContact(
          id: widget.contact!.id,
          name: _nameController.text,
          phone: _phoneController.text,
        );
      } else {
        await SupportContactsService.addContact(
          name: _nameController.text,
          phone: _phoneController.text,
        );
      }

      if (!mounted) return;

      Navigator.pop(
        context,
        _isEditing ? 'updated' : 'created',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos guardar el contacto. Revisa tu conexión e inténtalo otra vez.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar contacto' : 'Nuevo contacto'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(
              _isEditing
                  ? 'Actualiza el nombre o teléfono de este contacto.'
                  : 'Agrega un teléfono de confianza para pedir ayuda cuando sea necesario.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 22),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ejemplo: Mamá, hermana, médico',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return 'Escribe el nombre del contacto.';
                      }

                      if (text.length < 2) {
                        return 'El nombre parece muy corto. Revísalo por favor.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Número de teléfono',
                      hintText: 'Ejemplo: 7711234567',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return 'Escribe el número de teléfono.';
                      }

                      if (!RegExp(r'^[0-9]+$').hasMatch(text)) {
                        return 'Escribe solo números.';
                      }

                      if (text.length < 3) {
                        return 'El número parece muy corto. Revísalo por favor.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing
                                  ? 'Guardar cambios'
                                  : 'Agregar contacto',
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}