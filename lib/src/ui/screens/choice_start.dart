// lib/src/ui/screens/choice_start.dart
import 'package:flutter/material.dart';
import '../brand_logo.dart';
import '../theme.dart';
import 'login_page.dart';
import 'register_name_page.dart';
import 'package:whoami_app/services/permission_service.dart';

class ChoiceStart extends StatefulWidget {
  const ChoiceStart({super.key});

  static const route = '/auth/choice';

  @override
  State<ChoiceStart> createState() => _ChoiceStartState();
}

class _ChoiceStartState extends State<ChoiceStart> {
  bool acceptedTerms = false;
  bool acceptedPrivacy = false;

  // =====================================================
  // TEXTOS COMPLETOS (Términos y Privacidad)
  // =====================================================
  final String _termsText = """
TÉRMINOS Y CONDICIONES — WhoAmI?

1. ACEPTACIÓN  
Al utilizar la aplicación WhoAmI? aceptas estos Términos y Condiciones.

2. OBJETIVO  
WhoAmI? apoya la memoria, la organización y el bienestar emocional mediante:  
• registro de recuerdos con fotos y notas,  
• asistente con IA,  
• calendario y recordatorios,  
• seguimiento emocional,  
• ejercicios cognitivos.  

No sustituye atención médica o psicológica.

3. USO ADECUADO  
Te comprometes a usar la aplicación de manera responsable y no subir contenido ofensivo,
ilegal o inapropiado.

4. PERMISOS  
La app puede solicitar: cámara, galería, notificaciones, ubicación.  
Se usan exclusivamente para funciones internas.

5. PRIVACIDAD  
Tu información y recuerdos NO se comparten con terceros.

6. RESPONSABILIDAD  
El uso de la aplicación es responsabilidad del usuario.

7. ELIMINACIÓN DE DATOS  
Puedes eliminar tu cuenta y datos en cualquier momento.

8. CAMBIOS  
WhoAmI? puede actualizar estos términos. El uso continuo significa aceptación.
""";

  final String _privacyText = """
POLÍTICA DE PRIVACIDAD — WhoAmI?

1. DATOS QUE SE RECOPILAN  
• nombre, fecha de nacimiento, rol,  
• correo electrónico,  
• fotografías y notas,  
• estados de ánimo y actividad en la app.

2. USO DE LOS DATOS  
Se usan solo para:  
• guardar recuerdos,  
• mostrar calendario,  
• funcionamiento del asistente IA,  
• mejorar la experiencia del usuario.

3. ALMACENAMIENTO  
Los datos se guardan de forma segura en Firebase.

4. NO COMPARTIMOS DATOS  
WhoAmI? no vende, comparte ni distribuye tus datos sin permiso.

5. PERMISOS  
Los permisos solicitados se usan exclusivamente dentro de la app.

6. ELIMINACIÓN  
Puedes borrar toda tu información en cualquier momento.

7. SEGURIDAD  
Usamos buenas prácticas para proteger tus datos.

8. ACTUALIZACIONES  
La política puede cambiar. Continuar usando la app implica aceptación.
""";

  @override
  void initState() {
    super.initState();
    PermissionService.askAllPermissionsOnce();
  }

  // =====================================================
  // MODAL PARA TÉRMINOS O PRIVACIDAD
  // =====================================================
  void _openModal({required bool isPrivacy}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.3,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: controller,
                      children: [
                        Text(
                          isPrivacy
                              ? "Política de Privacidad"
                              : "Términos y Condiciones",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 20),

                        Text(
                          isPrivacy ? _privacyText : _termsText,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // BOTÓN DE CERRAR
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(Color(0xFFD6A7F4)),
                      ),
                      child: const Text(
                        "Cerrar",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allowButtons = acceptedTerms && acceptedPrivacy;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Comencemos',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
        ),

        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const BrandLogo(size: 160),
                    const SizedBox(height: 40),

                    // =======================
                    // BOTÓN INICIAR SESIÓN
                    // =======================
                    SizedBox(
                      width: 296,
                      height: 56,
                      child: FilledButton.icon(
                        style: pillLav(),
                        icon: const Icon(Icons.login_rounded, color: Colors.black),
                        label: const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        onPressed: allowButtons
                            ? () => Navigator.pushNamed(context, LoginPage.route)
                            : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =======================
                    // BOTÓN REGISTRARSE
                    // =======================
                    SizedBox(
                      width: 296,
                      height: 56,
                      child: FilledButton.icon(
                        style: pillBlue(),
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black),
                        label: const Text(
                          'Regístrate',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        onPressed: allowButtons
                            ? () => Navigator.pushNamed(context, RegisterNamePage.route)
                            : null,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // =======================
                    // ✔ CHECKBOXES CENTRADOS
                    // =======================
                    Column(
                      children: [
                        // ✔ Términos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: acceptedTerms,
                              onChanged: (v) {
                                setState(() => acceptedTerms = v ?? false);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                            InkWell(
                              onTap: () => _openModal(isPrivacy: false),
                              child: const Text(
                                "Términos y Condiciones",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ✔ Política
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: acceptedPrivacy,
                              onChanged: (v) {
                                setState(() => acceptedPrivacy = v ?? false);
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                            InkWell(
                              onTap: () => _openModal(isPrivacy: true),
                              child: const Text(
                                "Política de Privacidad",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
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
