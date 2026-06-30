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

class _SupportContactFormScreenState
    extends State<SupportContactFormScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _nameController;

  late final TextEditingController
      _phoneController;

  bool _saving =
      false;

  bool get _isEditing =>
      widget.contact != null;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text:
          widget.contact?.name ??
              '',
    );

    _phoneController =
        TextEditingController(
      text:
          widget.contact?.phone ??
              '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  // ============================================================
  // DIÁLOGO CON DISEÑO DE LA APLICACIÓN
  // ============================================================

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    required bool success,
  }) async {
    if (!mounted) {
      return;
    }

    final colors =
        context.appColors;

    await showDialog<void>(
      context:
          context,
      barrierDismissible:
          false,
      builder: (
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
                            ? colors.categoryGreen
                                .withValues(
                                alpha:
                                    context.isDark
                                        ? 0.28
                                        : 0.45,
                              )
                            : colors.emergency
                                .withValues(
                                alpha:
                                    context.isDark
                                        ? 0.28
                                        : 0.35,
                              ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Icon(
                    success
                        ? Icons
                            .check_circle_outline_rounded
                        : Icons
                            .error_outline_rounded,
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
                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w700,
                      ),
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

  // ============================================================
  // GUARDAR O ACTUALIZAR CONTACTO
  // ============================================================

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final formState =
        _formKey.currentState;

    if (formState == null ||
        !formState.validate()) {
      return;
    }

    FocusScope.of(
      context,
    ).unfocus();

    setState(
      () {
        _saving =
            true;
      },
    );

    try {
      final name =
          _nameController.text.trim();

      final phone =
          _phoneController.text.trim();

      if (_isEditing) {
        await SupportContactsService.updateContact(
          id:
              widget.contact!.id,
          name:
              name,
          phone:
              phone,
        );
      } else {
        await SupportContactsService.addContact(
          name:
              name,
          phone:
              phone,
        );
      }

      if (!mounted) {
        return;
      }

      await _showStatusDialog(
        title:
            _isEditing
                ? 'Contacto actualizado'
                : 'Contacto guardado',
        message:
            _isEditing
                ? 'Los datos del contacto se actualizaron correctamente.'
                : 'El contacto se guardó correctamente y ya está disponible en tu lista de apoyo.',
        success:
            true,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(
        _isEditing
            ? 'updated'
            : 'created',
      );
    } catch (
      error,
      stackTrace
    ) {
      debugPrint(
        'Error guardando contacto: $error',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(
        () {
          _saving =
              false;
        },
      );

      await _showStatusDialog(
        title:
            'No se pudo guardar',
        message:
            'No pudimos guardar el contacto. '
            'Revisa tu conexión e inténtalo nuevamente.',
        success:
            false,
      );
    }
  }

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
            Text(
          _isEditing
              ? 'Editar contacto'
              : 'Nuevo contacto',
        ),
        centerTitle:
            true,
      ),
      body:
          SafeArea(
        child:
            ListView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding:
              const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28,
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
                              : 0.05,
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
                          colors.categoryBlue
                              .withValues(
                        alpha:
                            context.isDark
                                ? 0.35
                                : 0.55,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        Icon(
                      _isEditing
                          ? Icons
                              .manage_accounts_outlined
                          : Icons
                              .person_add_alt_1_rounded,
                      color:
                          colors.textPrimary,
                      size:
                          36,
                    ),
                  ),
                  const SizedBox(
                    height:
                        14,
                  ),
                  Text(
                    _isEditing
                        ? 'Actualiza el contacto'
                        : 'Agrega un contacto de apoyo',
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
                    _isEditing
                        ? 'Actualiza el nombre o el teléfono de este contacto.'
                        : 'Agrega un teléfono de confianza para pedir ayuda cuando sea necesario.',
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

            // ==================================================
            // FORMULARIO
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.all(
                18,
              ),
              decoration:
                  BoxDecoration(
                color:
                    colors.cardBackground,
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
                  Form(
                key:
                    _formKey,
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del contacto',
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height:
                          16,
                    ),

                    TextFormField(
                      controller:
                          _nameController,
                      enabled:
                          !_saving,
                      textCapitalization:
                          TextCapitalization.words,
                      textInputAction:
                          TextInputAction.next,
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            16,
                      ),
                      decoration:
                          InputDecoration(
                        labelText:
                            'Nombre',
                        hintText:
                            'Ejemplo: Mamá, hermana o médico',
                        prefixIcon:
                            Icon(
                          Icons.person_outline_rounded,
                          color:
                              colors.textSecondary,
                        ),
                      ),
                      validator:
                          (
                        value,
                      ) {
                        final text =
                            value?.trim() ??
                                '';

                        if (text.isEmpty) {
                          return 'Escribe el nombre del contacto.';
                        }

                        if (text.length <
                            2) {
                          return 'El nombre parece muy corto. Revísalo.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height:
                          16,
                    ),

                    TextFormField(
                      controller:
                          _phoneController,
                      enabled:
                          !_saving,
                      keyboardType:
                          TextInputType.phone,
                      textInputAction:
                          TextInputAction.done,
                      style:
                          TextStyle(
                        color:
                            colors.textPrimary,
                        fontSize:
                            16,
                      ),
                      decoration:
                          InputDecoration(
                        labelText:
                            'Número de teléfono',
                        hintText:
                            'Ejemplo: 7711234567',
                        prefixIcon:
                            Icon(
                          Icons.phone_outlined,
                          color:
                              colors.textSecondary,
                        ),
                      ),
                      onFieldSubmitted:
                          (_) {
                        if (!_saving) {
                          _save();
                        }
                      },
                      validator:
                          (
                        value,
                      ) {
                        final text =
                            value?.trim() ??
                                '';

                        if (text.isEmpty) {
                          return 'Escribe el número de teléfono.';
                        }

                        if (!RegExp(
                          r'^[0-9]+$',
                        ).hasMatch(
                          text,
                        )) {
                          return 'Escribe solo números.';
                        }

                        if (text.length <
                            3) {
                          return 'El número parece muy corto. Revísalo.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height:
                          28,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        style:
                            FilledButton.styleFrom(
                          backgroundColor:
                              colors.primaryButton,
                          foregroundColor:
                              colors.primaryButtonText,
                          minimumSize:
                              const Size.fromHeight(
                            54,
                          ),
                          shape:
                              const StadiumBorder(),
                        ),
                        onPressed:
                            _saving
                                ? null
                                : _save,
                        icon:
                            _saving
                                ? SizedBox(
                                    width:
                                        20,
                                    height:
                                        20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.4,
                                      color:
                                          colors.primaryButtonText,
                                    ),
                                  )
                                : Icon(
                                    _isEditing
                                        ? Icons
                                            .save_outlined
                                        : Icons
                                            .person_add_alt_1_rounded,
                                  ),
                        label:
                            Text(
                          _saving
                              ? 'Guardando...'
                              : _isEditing
                                  ? 'Guardar cambios'
                                  : 'Agregar contacto',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          12,
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
                            52,
                          ),
                          shape:
                              const StadiumBorder(),
                        ),
                        onPressed:
                            _saving
                                ? null
                                : () {
                                    Navigator.pop(
                                      context,
                                    );
                                  },
                        icon:
                            const Icon(
                          Icons.close_rounded,
                        ),
                        label:
                            const Text(
                          'Cancelar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}