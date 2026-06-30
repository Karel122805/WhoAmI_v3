import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

import '../data/default_support_contacts.dart';
import '../data/support_contacts_service.dart';
import '../models/support_contact_model.dart';
import 'support_contact_form_screen.dart';

class SupportContactsScreen extends StatelessWidget {
  const SupportContactsScreen({
    super.key,
  });

  static const route =
      '/support-contacts';

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    return Scaffold(
      backgroundColor:
          colors.pageBackground,
      appBar:
          AppBar(
        title:
            const Text(
          'Contactos de apoyo',
        ),
        centerTitle:
            true,
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor:
            colors.primaryButton,
        foregroundColor:
            colors.primaryButtonText,
        elevation:
            context.isDark
                ? 0
                : 4,
        shape:
            const StadiumBorder(),
        icon:
            const Icon(
          Icons.add_rounded,
        ),
        label:
            const Text(
          'Agregar',
          style:
              TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        onPressed:
            () {
          _openContactForm(
            context,
          );
        },
      ),
      body:
          StreamBuilder<List<SupportContactModel>>(
        stream:
            SupportContactsService.watchUserContacts(),
        builder:
            (
          context,
          snapshot,
        ) {
          final userContacts =
              snapshot.data ??
                  <SupportContactModel>[];

          final contacts =
              <SupportContactModel>[
            ...defaultSupportContacts,
            ...userContacts,
          ];

          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              userContacts.isEmpty) {
            return Center(
              child:
                  CircularProgressIndicator(
                color:
                    colors.primaryButton,
              ),
            );
          }

          if (snapshot.hasError) {
            return _SupportContactsError(
              onRetry:
                  () {
                Navigator.of(
                  context,
                ).pushReplacement(
                  MaterialPageRoute<void>(
                    builder:
                        (_) {
                      return const SupportContactsScreen();
                    },
                  ),
                );
              },
            );
          }

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              110,
            ),
            children: [
              // ==================================================
              // ENCABEZADO
              // ==================================================

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      colors.elevatedCard,
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                  border:
                      Border.all(
                    color:
                        colors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(
                        alpha:
                            context.isDark
                                ? 0.20
                                : 0.06,
                      ),
                      blurRadius:
                          18,
                      offset:
                          const Offset(
                        0,
                        7,
                      ),
                    ),
                  ],
                ),
                child:
                    Column(
                  children: [
                    Container(
                      width:
                          72,
                      height:
                          72,
                      decoration:
                          BoxDecoration(
                        color:
                            colors.categoryBlue.withValues(
                          alpha:
                              context.isDark
                                  ? 0.35
                                  : 0.50,
                        ),
                        shape:
                            BoxShape.circle,
                      ),
                      child:
                          Icon(
                        Icons.support_agent_rounded,
                        color:
                            colors.textPrimary,
                        size:
                            38,
                      ),
                    ),
                    const SizedBox(
                      height:
                          14,
                    ),
                    Text(
                      'Tus contactos de apoyo',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            21,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height:
                          8,
                    ),
                    Text(
                      'Aquí puedes guardar teléfonos importantes '
                      'para pedir ayuda rápidamente.',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            colors.textSecondary,
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w500,
                        height:
                            1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    22,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        Text(
                      'Contactos disponibles',
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          12,
                      vertical:
                          7,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          colors.chipBackground,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      border:
                          Border.all(
                        color:
                            colors.border,
                      ),
                    ),
                    child:
                        Text(
                      '${contacts.length}',
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    14,
              ),

              ...contacts.map(
                (
                  contact,
                ) {
                  return _SupportContactCard(
                    contact:
                        contact,
                    onEdit:
                        contact.isDefault
                            ? null
                            : () {
                                _openContactForm(
                                  context,
                                  contact:
                                      contact,
                                );
                              },
                    onDelete:
                        contact.isDefault
                            ? null
                            : () {
                                _confirmDelete(
                                  context,
                                  contact,
                                );
                              },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ABRIR FORMULARIO
  // ============================================================

  static Future<void> _openContactForm(
    BuildContext context, {
    SupportContactModel? contact,
  }) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder:
            (_) {
          return SupportContactFormScreen(
            contact:
                contact,
          );
        },
      ),
    );

    /*
     * No se muestra otro mensaje aquí.
     * SupportContactFormScreen ya muestra:
     *
     * - Contacto guardado
     * - Contacto actualizado
     */
  }

  // ============================================================
  // CONFIRMAR ELIMINACIÓN
  // ============================================================

  static Future<void> _confirmDelete(
    BuildContext context,
    SupportContactModel contact,
  ) async {
    final colors =
        context.appColors;

    final confirmed =
        await showDialog<bool>(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (
        dialogContext,
      ) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(
            horizontal:
                28,
          ),
          child:
              Container(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              24,
              22,
              20,
            ),
            decoration:
                BoxDecoration(
              color:
                  colors.elevatedCard,
              borderRadius:
                  BorderRadius.circular(
                26,
              ),
              border:
                  Border.all(
                color:
                    colors.emergency,
                width:
                    1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(
                    alpha:
                        context.isDark
                            ? 0.35
                            : 0.12,
                  ),
                  blurRadius:
                      24,
                  offset:
                      const Offset(
                    0,
                    10,
                  ),
                ),
              ],
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width:
                      74,
                  height:
                      74,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.emergency.withValues(
                      alpha:
                          context.isDark
                              ? 0.28
                              : 0.32,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Icon(
                    Icons.delete_outline_rounded,
                    color:
                        colors.emergency,
                    size:
                        42,
                  ),
                ),

                const SizedBox(
                  height:
                      18,
                ),

                Text(
                  'Eliminar contacto',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      10,
                ),

                Text(
                  '¿Deseas eliminar a ${contact.name} '
                  'de tus contactos de apoyo?',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        colors.textSecondary,
                    fontSize:
                        15,
                    height:
                        1.4,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                const SizedBox(
                  height:
                      8,
                ),

                Text(
                  'Esta acción no se puede deshacer.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        colors.emergency,
                    fontSize:
                        13,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                      22,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          colors.emergency,
                      foregroundColor:
                          colors.emergencyText,
                      minimumSize:
                          const Size.fromHeight(
                        50,
                      ),
                      shape:
                          const StadiumBorder(),
                    ),
                    onPressed:
                        () {
                      Navigator.of(
                        dialogContext,
                      ).pop(
                        true,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.delete_outline_rounded,
                    ),
                    label:
                        const Text(
                      'Sí, eliminar',
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                      10,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          colors.textPrimary,
                      side:
                          BorderSide(
                        color:
                            colors.border,
                      ),
                      minimumSize:
                          const Size.fromHeight(
                        50,
                      ),
                      shape:
                          const StadiumBorder(),
                    ),
                    onPressed:
                        () {
                      Navigator.of(
                        dialogContext,
                      ).pop(
                        false,
                      );
                    },
                    icon:
                        const Icon(
                      Icons.close_rounded,
                    ),
                    label:
                        const Text(
                      'No, conservar',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed !=
        true) {
      return;
    }

    await _deleteContact(
      context,
      contact,
    );
  }

  // ============================================================
  // ELIMINAR CONTACTO
  // ============================================================

  static Future<void> _deleteContact(
    BuildContext context,
    SupportContactModel contact,
  ) async {
    _showLoadingDialog(
      context,
      message:
          'Eliminando contacto...',
    );

    try {
      await SupportContactsService.deleteContact(
        contact.id,
      );

      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      await _showStatusDialog(
        context,
        title:
            'Contacto eliminado',
        message:
            '${contact.name} fue eliminado correctamente '
            'de tus contactos de apoyo.',
        success:
            true,
        icon:
            Icons.delete_sweep_outlined,
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error eliminando contacto: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!context.mounted) {
        return;
      }

      Navigator.of(
        context,
        rootNavigator:
            true,
      ).pop();

      await _showStatusDialog(
        context,
        title:
            'No se pudo eliminar',
        message:
            'No pudimos eliminar el contacto. '
            'Revisa tu conexión e inténtalo nuevamente.',
        success:
            false,
        icon:
            Icons.error_outline_rounded,
      );
    }
  }

  // ============================================================
  // DIÁLOGO DE CARGA
  // ============================================================

  static void _showLoadingDialog(
    BuildContext context, {
    required String message,
  }) {
    showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (
        loadingContext,
      ) {
        final colors =
            loadingContext.appColors;

        return PopScope(
          canPop:
              false,
          child:
              Dialog(
            backgroundColor:
                Colors.transparent,
            child:
                Container(
              padding:
                  const EdgeInsets.all(
                22,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colors.elevatedCard,
                borderRadius:
                    BorderRadius.circular(
                  22,
                ),
                border:
                    Border.all(
                  color:
                      colors.border,
                ),
              ),
              child:
                  Row(
                children: [
                  SizedBox(
                    width:
                        28,
                    height:
                        28,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          3,
                      color:
                          colors.primaryButton,
                    ),
                  ),
                  const SizedBox(
                    width:
                        18,
                  ),
                  Expanded(
                    child:
                        Text(
                      message,
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DIÁLOGO DE RESULTADO
  // ============================================================

  static Future<void> _showStatusDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool success,
    required IconData icon,
  }) async {
    if (!context.mounted) {
      return;
    }

    final colors =
        context.appColors;

    await showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder:
          (
        dialogContext,
      ) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(
            horizontal:
                28,
          ),
          child:
              Container(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              24,
              22,
              20,
            ),
            decoration:
                BoxDecoration(
              color:
                  colors.elevatedCard,
              borderRadius:
                  BorderRadius.circular(
                26,
              ),
              border:
                  Border.all(
                color:
                    success
                        ? colors.categoryGreen
                        : colors.emergency,
                width:
                    1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(
                    alpha:
                        context.isDark
                            ? 0.35
                            : 0.12,
                  ),
                  blurRadius:
                      24,
                  offset:
                      const Offset(
                    0,
                    10,
                  ),
                ),
              ],
            ),
            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width:
                      74,
                  height:
                      74,
                  decoration:
                      BoxDecoration(
                    color:
                        success
                            ? colors.categoryGreen.withValues(
                                alpha:
                                    context.isDark
                                        ? 0.28
                                        : 0.42,
                              )
                            : colors.emergency.withValues(
                                alpha:
                                    context.isDark
                                        ? 0.28
                                        : 0.34,
                              ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Icon(
                    icon,
                    size:
                        42,
                    color:
                        success
                            ? colors.categoryGreen
                            : colors.emergency,
                  ),
                ),

                const SizedBox(
                  height:
                      18,
                ),

                Text(
                  title,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      10,
                ),

                Text(
                  message,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        colors.textSecondary,
                    fontSize:
                        15,
                    height:
                        1.4,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                const SizedBox(
                  height:
                      22,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton(
                    style:
                        FilledButton.styleFrom(
                      backgroundColor:
                          success
                              ? colors.primaryButton
                              : colors.emergency,
                      foregroundColor:
                          success
                              ? colors.primaryButtonText
                              : colors.emergencyText,
                      minimumSize:
                          const Size.fromHeight(
                        50,
                      ),
                      shape:
                          const StadiumBorder(),
                    ),
                    onPressed:
                        () {
                      Navigator.of(
                        dialogContext,
                      ).pop();
                    },
                    child:
                        const Text(
                      'Aceptar',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// TARJETA DE CONTACTO
// ============================================================

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
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            14,
      ),
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            contact.isDefault
                ? colors.categoryPink.withValues(
                    alpha:
                        context.isDark
                            ? 0.42
                            : 0.72,
                  )
                : colors.elevatedCard,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              contact.isDefault
                  ? colors.emergency
                  : colors.border,
          width:
              contact.isDefault
                  ? 1.4
                  : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha:
                  context.isDark
                      ? 0.18
                      : 0.06,
            ),
            blurRadius:
                14,
            offset:
                const Offset(
              0,
              5,
            ),
          ),
        ],
      ),
      child:
          Row(
        children: [
          Container(
            width:
                54,
            height:
                54,
            decoration:
                BoxDecoration(
              color:
                  contact.isDefault
                      ? colors.emergency.withValues(
                          alpha:
                              0.24,
                        )
                      : colors.primaryButton.withValues(
                          alpha:
                              context.isDark
                                  ? 0.30
                                  : 0.42,
                        ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              contact.isDefault
                  ? Icons.emergency_rounded
                  : Icons.person_outline_rounded,
              color:
                  colors.textPrimary,
              size:
                  28,
            ),
          ),

          const SizedBox(
            width:
                14,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style:
                      TextStyle(
                    color:
                        colors.textPrimary,
                    fontSize:
                        17,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      5,
                ),

                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      color:
                          colors.textSecondary,
                      size:
                          17,
                    ),
                    const SizedBox(
                      width:
                          6,
                    ),
                    Expanded(
                      child:
                          Text(
                        contact.phone,
                        style:
                            TextStyle(
                          color:
                              colors.textSecondary,
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (contact.isDefault) ...[
                  const SizedBox(
                    height:
                        7,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          9,
                      vertical:
                          5,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          colors.emergency.withValues(
                        alpha:
                            0.22,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child:
                        Text(
                      'Disponible siempre',
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (!contact.isDefault)
            PopupMenuButton<String>(
              tooltip:
                  'Opciones del contacto',
              color:
                  colors.elevatedCard,
              icon:
                  Icon(
                Icons.more_vert_rounded,
                color:
                    colors.textPrimary,
              ),
              onSelected:
                  (
                value,
              ) {
                if (value ==
                    'edit') {
                  onEdit?.call();
                }

                if (value ==
                    'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder:
                  (
                menuContext,
              ) {
                return [
                  PopupMenuItem<String>(
                    value:
                        'edit',
                    child:
                        Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color:
                              colors.primaryButton,
                        ),
                        const SizedBox(
                          width:
                              10,
                        ),
                        Text(
                          'Editar',
                          style:
                              TextStyle(
                            color:
                                colors.textPrimary,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value:
                        'delete',
                    child:
                        Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color:
                              colors.emergency,
                        ),
                        const SizedBox(
                          width:
                              10,
                        ),
                        Text(
                          'Eliminar',
                          style:
                              TextStyle(
                            color:
                                colors.emergency,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// ESTADO DE ERROR
// ============================================================

class _SupportContactsError extends StatelessWidget {
  const _SupportContactsError({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        context.appColors;

    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child:
            Container(
          padding:
              const EdgeInsets.all(
            24,
          ),
          decoration:
              BoxDecoration(
            color:
                colors.elevatedCard,
            borderRadius:
                BorderRadius.circular(
              24,
            ),
            border:
                Border.all(
              color:
                  colors.emergency,
            ),
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Container(
                width:
                    74,
                height:
                    74,
                decoration:
                    BoxDecoration(
                  color:
                      colors.emergency.withValues(
                    alpha:
                        0.25,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    Icon(
                  Icons.cloud_off_outlined,
                  color:
                      colors.emergency,
                  size:
                      40,
                ),
              ),
              const SizedBox(
                height:
                    16,
              ),
              Text(
                'No se pudieron cargar los contactos',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      colors.textPrimary,
                  fontSize:
                      20,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height:
                    8,
              ),
              Text(
                'Revisa tu conexión e inténtalo nuevamente.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      colors.textSecondary,
                  fontSize:
                      15,
                  height:
                      1.4,
                ),
              ),
              const SizedBox(
                height:
                    20,
              ),
              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      onRetry,
                  icon:
                      const Icon(
                    Icons.refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Volver a intentar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}