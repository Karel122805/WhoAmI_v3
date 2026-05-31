import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/support_contacts/data/default_support_contacts.dart';
import 'package:whoami_app/src/features/support_contacts/data/support_contacts_service.dart';
import 'package:whoami_app/src/features/support_contacts/models/support_contact_model.dart';

class PanicButtonPage extends StatelessWidget {
  const PanicButtonPage({super.key});

  static const route = '/panic-button';

  Future<void> _confirmAndCall(
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
            'Confirmar llamada',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '¿Quieres llamar a ${contact.name}?',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No, cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.emergency,
                foregroundColor: colors.emergencyText,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sí, llamar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final uri = Uri(scheme: 'tel', path: contact.phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo abrir la llamada. Revisa que el dispositivo permita hacer llamadas.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: const Text('Botón de pánico'),
        centerTitle: true,
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.emergency.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.emergency.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emergency_share_rounded,
                      size: 64,
                      color: colors.emergency,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Elige a quién llamar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Puedes llamar al 911 o a uno de tus contactos de apoyo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ...contacts.map(
                (contact) => _PanicContactCard(
                  contact: contact,
                  onTap: () => _confirmAndCall(context, contact),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PanicContactCard extends StatelessWidget {
  const _PanicContactCard({
    required this.contact,
    required this.onTap,
  });

  final SupportContactModel contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor:
              contact.isDefault ? colors.emergency : colors.secondaryButton,
          foregroundColor:
              contact.isDefault ? colors.emergencyText : colors.secondaryButtonText,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(
              contact.isDefault
                  ? Icons.local_phone_rounded
                  : Icons.contact_phone_outlined,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact.phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.call_rounded),
          ],
        ),
      ),
    );
  }
}