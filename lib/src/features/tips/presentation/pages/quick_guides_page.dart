import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class QuickGuidesPage extends StatefulWidget {
  const QuickGuidesPage({super.key});
  static const route = '/quick-guides';

  @override
  State<QuickGuidesPage> createState() => _QuickGuidesPageState();
}

class _QuickGuidesPageState extends State<QuickGuidesPage> {
  // Paleta pastel exacta
  static const Color yellow = Color(0xFFFFF49F);
  static const Color pink = Color(0xFFFF9FA1);
  static const Color blue = Color(0xFF9ED3FF);
  static const Color green = Color(0xFF9EEE97);
  static const Color purple = Color(0xFFD99FFF);

  static const Color textColor = Color(0xFF111111);

  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  // PRIMERA VISTA: menú de categorías
  bool _showCategoryMenu = true;

  final Map<String, List<String>> _guidesByCategory = {
    "Emergencia": [
      "Mantén la calma y acompaña al paciente en todo momento.",
      "Si se desorienta, llévalo a un lugar seguro y familiar.",
      "Verifica signos vitales si hay caída.",
      "Evita mover al paciente si siente dolor intenso.",
      "Llama a emergencias si presenta cambios bruscos de conducta.",
      "Asegura que tenga identificación siempre consigo.",
      "Busca un lugar tranquilo para evitar sobreestimulación.",
      "Llama a un familiar si la situación se complica.",
      "Revisa si tomó sus medicamentos correctamente.",
      "Mantente atento a signos de deshidratación o fiebre.",
    ],
    "Rutina": [
      "Establece horarios fijos para levantarse y dormir.",
      "Organiza la ropa un día antes.",
      "Divide actividades en pasos sencillos.",
      "Incluye pausas para evitar cansancio.",
      "Usa recordatorios visuales en casa.",
      "Mantén rutinas constantes para generar seguridad.",
      "Evita cambios bruscos de última hora.",
      "Realiza actividades tranquilas antes de dormir.",
      "Ordena el entorno para reducir estrés.",
      "Permite que participe en tareas simples.",
    ],
    "Comunicación": [
      "Habla despacio y usa frases cortas.",
      "Haz contacto visual siempre.",
      "Haz preguntas simples de sí/no.",
      "Usa gestos o imágenes como apoyo.",
      "Evita discusiones o correcciones duras.",
      "Dale tiempo para responder.",
      "Evita hablar rápido.",
      "Refuerza con gestos calmados.",
      "Escucha sin interrumpir.",
      "Valida sus emociones cuando esté confundido.",
    ],
    "Seguridad": [
      "Retira alfombras que puedan causar caídas.",
      "Asegura puertas y ventanas.",
      "Coloca iluminación nocturna.",
      "Guarda objetos peligrosos fuera de alcance.",
      "Evita pisos mojados.",
      "Coloca barandales en lugares clave.",
      "Mantén productos tóxicos bajo llave.",
      "Evita cables sueltos.",
      "Supervisa al usar la cocina.",
      "Usa calzado seguro y cómodo.",
    ],
    "Medicina": [
      "Usa un pastillero semanal para organizar medicamentos.",
      "Configura alarmas para recordar horarios.",
      "No cambies dosis sin consultar al médico.",
      "Registra efectos secundarios inusuales.",
      "Verifica que no falte ninguna dosis.",
      "Guarda medicamentos fuera del alcance.",
      "Acompáñalo mientras los toma.",
      "Ten la receta médica a la mano.",
      "Revisa fechas de caducidad.",
      "No mezcles medicamentos sin supervisión.",
    ],
  };

  // Colores de categoría
  late final Map<String, Color> _catColor = {
    "Emergencia": yellow,
    "Rutina": pink,
    "Comunicación": blue,
    "Seguridad": green,
    "Medicina": purple,
  };

  // Íconos representativos
  late final Map<String, IconData> _catIcon = {
    "Emergencia": Icons.warning_rounded,
    "Rutina": Icons.schedule_rounded,
    "Comunicación": Icons.chat_rounded,
    "Seguridad": Icons.shield_rounded,
    "Medicina": Icons.medical_services_rounded,
  };

  late final List<String> _categories;

  String _selected = "Emergencia";
  List<String> _visible = [];

  @override
  void initState() {
    super.initState();
    _categories = [..._guidesByCategory.keys];
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage("es-MX");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  // ✅ STOP centralizado (se usa en todos los casos)
  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignorar errores del motor de TTS para no romper la navegación
    }
  }

  // Cargar categoría
  Future<void> _loadCategory(String cat) async {
    await _stopTts();
    _selected = cat;

    final pool = _guidesByCategory[cat]!;
    final shuffled = List<String>.from(pool)..shuffle(_rnd);

    if (!mounted) return;
    setState(() {
      _visible = shuffled;
      _showCategoryMenu = false;
    });
  }

  Future<void> _speak(String text) async {
    await _stopTts();
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _stopTts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        // ✅ Si el usuario sale con el botón atrás/gesto, detenemos el audio
        await _stopTts();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Guías"),
          centerTitle: true,
          elevation: 0,
        ),
        body: _showCategoryMenu ? _buildCategoryMenu() : _buildGuidesView(),
      ),
    );
  }

  // 1️⃣ MENÚ DE CATEGORÍAS
  Widget _buildCategoryMenu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: _categories.map((cat) {
          return GestureDetector(
            onTap: () => _loadCategory(cat),
            child: Container(
              decoration: BoxDecoration(
                color: _catColor[cat],
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,
                    offset: Offset(0, 4),
                    color: Colors.black26,
                  )
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_catIcon[cat], size: 48, color: textColor),
                    const SizedBox(height: 10),
                    Text(
                      cat,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 2️⃣ VISTA DE GUÍAS (SIN DROPDOWN)
  Widget _buildGuidesView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // LISTA DE GUÍAS
          Expanded(
            child: ListView.builder(
              itemCount: _visible.length,
              itemBuilder: (_, i) {
                return _GuideCard(
                  text: _visible[i],
                  color: _catColor[_selected]!,
                  icon: _catIcon[_selected]!,
                  onTap: () => _speak(_visible[i]),
                );
              },
            ),
          ),

          // BOTÓN NUEVO — MUY VISIBLE
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // ✅ al volver al menú, detenemos el TTS
                await _stopTts();
                if (!mounted) return;
                setState(() => _showCategoryMenu = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFE9D8FF), // violeta pastel claro
                foregroundColor: const Color(0xFF6B2FAF), // texto morado
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 4,
              ),
              child: const Text(
                "Volver al menú",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const _GuideCard({
    required this.text,
    required this.onTap,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              offset: Offset(0, 2),
              color: Color(0x22000000),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15.5,
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
            ),
            const Icon(Icons.volume_up, size: 22, color: Colors.black),
          ],
        ),
      ),
    );
  }
}






