import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

import '../data/default_support_contacts.dart';
import '../data/support_contacts_service.dart';
import '../models/support_contact_model.dart';
import 'support_contact_form_screen.dart';

class SupportContactsScreen extends StatelessWidget {
  const SupportContactsScreen({super.key});

  static const route = '/support-contacts';

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: const Text('Contactos de apoyo'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primaryButton,
        foregroundColor: colors.primaryButtonText,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
        onPressed: () => _openContactForm(context),
      ),
      body: StreamBuilder<List<SupportContactModel>>(
        stream: SupportContactsService.watchUserContacts(),
        builder: (context, snapshot) {
          final userContacts = snapshot.data ?? [];
          final contacts = [
            ...defaultSupportContacts,
            ...userContacts,
          ];

          if (snapshot.connectionState == ConnectionState.waiting &&
              userContacts.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: colors.primaryButton,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Text(
                'Aquí puedes guardar teléfonos importantes para pedir ayuda rápidamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              ...contacts.map(
                (contact) => _SupportContactCard(
                  contact: contact,
                  onEdit: contact.isDefault
                      ? null
                      : () => _openContactForm(context, contact: contact),
                  onDelete: contact.isDefault
                      ? null
                      : () => _confirmDelete(context, contact),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _openContactForm(
    BuildContext context, {
    SupportContactModel? contact,
  }) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportContactFormScreen(contact: contact),
      ),
    );

    if (!context.mounted || result == null) return;

    final message = result == 'created'
        ? 'Listo, el contacto se guardó correctamente.'
        : 'Listo, los datos del contacto se actualizaron.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    SupportContactModel contact,
  ) async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.elevatedCard,
          title: Text(
            'Eliminar contacto',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '¿Deseas eliminar a ${contact.name} de tus contactos de apoyo?',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No, conservar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.emergency,
                foregroundColor: colors.emergencyText,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sí, eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await SupportContactsService.deleteContact(contact.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listo, el contacto fue eliminado.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _SupportContactCard extends StatelessWidget {
  const _SupportContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final SupportContactModel contact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: contact.isDefault ? colors.categoryPink : colors.elevatedCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: contact.isDefault ? colors.emergency : colors.border,
        ),
        boxShadow: [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: contact.isDefault
                ? colors.emergency.withValues(alpha: 0.18)
                : colors.primaryButton.withValues(alpha: 0.18),
            child: Icon(
              contact.isDefault
                  ? Icons.emergency_rounded
                  : Icons.person_outline_rounded,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phone,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contact.isDefault) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Disponible siempre',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!contact.isDefault) ...[
            IconButton(
              tooltip: 'Editar contacto',
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                color: colors.textPrimary,
              ),
            ),
            IconButton(
              tooltip: 'Eliminar contacto',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colors.emergency,
              ),
            ),
          ],
        ],
      ),
    );
  }
}