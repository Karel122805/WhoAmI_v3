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
  // Definición de colores utilizados para las categorías.
  static const Color yellow = Color(0xFFFFF49F);
  static const Color pink = Color(0xFFFF9FA1);
  static const Color blue = Color(0xFF9ED3FF);
  static const Color green = Color(0xFF9EEE97);
  static const Color purple = Color(0xFFD99FFF);

  static const Color textColor = Color(0xFF111111);

  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  // Controla si se muestra el menú principal o la vista de contenido.
  bool _showCategoryMenu = true;

  // Información agrupada por categorías.
  final Map<String, List<String>> _guidesByCategory = {
    'Emergencia': [
      'Mantén la calma y acompaña al paciente en todo momento.',
      'Si se desorienta, llévalo a un lugar seguro y familiar.',
      'Verifica signos vitales si hay caída.',
      'Evita mover al paciente si siente dolor intenso.',
      'Llama a emergencias si presenta cambios bruscos de conducta.',
      'Asegura que tenga identificación siempre consigo.',
      'Busca un lugar tranquilo para evitar sobreestimulación.',
      'Llama a un familiar si la situación se complica.',
      'Revisa si tomó sus medicamentos correctamente.',
      'Mantente atento a signos de deshidratación o fiebre.',
    ],
    'Rutina': [
      'Establece horarios fijos para levantarse y dormir.',
      'Organiza la ropa un día antes.',
      'Divide actividades en pasos sencillos.',
      'Incluye pausas para evitar cansancio.',
      'Usa recordatorios visuales en casa.',
      'Mantén rutinas constantes para generar seguridad.',
      'Evita cambios bruscos de última hora.',
      'Realiza actividades tranquilas antes de dormir.',
      'Ordena el entorno para reducir estrés.',
      'Permite que participe en tareas simples.',
    ],
    'Comunicación': [
      'Habla despacio y usa frases cortas.',
      'Haz contacto visual siempre.',
      'Haz preguntas simples de sí/no.',
      'Usa gestos o imágenes como apoyo.',
      'Evita discusiones o correcciones duras.',
      'Dale tiempo para responder.',
      'Evita hablar rápido.',
      'Refuerza con gestos calmados.',
      'Escucha sin interrumpir.',
      'Valida sus emociones cuando esté confundido.',
    ],
    'Seguridad': [
      'Retira alfombras que puedan causar caídas.',
      'Asegura puertas y ventanas.',
      'Coloca iluminación nocturna.',
      'Guarda objetos peligrosos fuera de alcance.',
      'Evita pisos mojados.',
      'Coloca barandales en lugares clave.',
      'Mantén productos tóxicos bajo llave.',
      'Evita cables sueltos.',
      'Supervisa al usar la cocina.',
      'Usa calzado seguro y cómodo.',
    ],
    'Medicina': [
      'Usa un pastillero semanal para organizar medicamentos.',
      'Configura alarmas para recordar horarios.',
      'No cambies dosis sin consultar al médico.',
      'Registra efectos secundarios inusuales.',
      'Verifica que no falte ninguna dosis.',
      'Guarda medicamentos fuera del alcance.',
      'Acompáñalo mientras los toma.',
      'Ten la receta médica a la mano.',
      'Revisa fechas de caducidad.',
      'No mezcles medicamentos sin supervisión.',
    ],
  };

  // Color asociado a cada categoría.
  late final Map<String, Color> _catColor = {
    'Emergencia': yellow,
    'Rutina': pink,
    'Comunicación': blue,
    'Seguridad': green,
    'Medicina': purple,
  };

  // Icono asociado a cada categoría.
  late final Map<String, IconData> _catIcon = {
    'Emergencia': Icons.warning_rounded,
    'Rutina': Icons.schedule_rounded,
    'Comunicación': Icons.chat_rounded,
    'Seguridad': Icons.shield_rounded,
    'Medicina': Icons.medical_services_rounded,
  };

  late final List<String> _categories;

  String _selected = 'Emergencia';
  List<String> _visible = [];

  @override
  void initState() {
    super.initState();
    _categories = [..._guidesByCategory.keys];
    _configureTts();
  }

  // Configura parámetros del motor de texto a voz.
  Future<void> _configureTts() async {
    await _tts.setLanguage('es-MX');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  // Detiene cualquier reproducción activa.
  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Se ignoran errores internos del motor.
    }
  }

  // Carga y mezcla aleatoriamente el contenido seleccionado.
  Future<void> _loadCategory(String category) async {
    await _stopTts();

    _selected = category;

    final shuffled =
        List<String>.from(_guidesByCategory[category]!)..shuffle(_rnd);

    if (!mounted) return;

    setState(() {
      _visible = shuffled;
      _showCategoryMenu = false;
    });
  }

  // Reproduce una guía mediante texto a voz.
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
      onPopInvokedWithResult: (didPop, result) async {
        // Detiene reproducción al salir mediante navegación del sistema.
        await _stopTts();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Guías'),
          centerTitle: true,
          elevation: 0,
        ),
        body: _showCategoryMenu
            ? _buildCategoryMenu()
            : _buildGuidesView(),
      ),
    );
  }

  Widget _buildCategoryMenu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: _categories.map((category) {
          return GestureDetector(
            onTap: () => _loadCategory(category),
            child: Container(
              decoration: BoxDecoration(
                color: _catColor[category],
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
                    Icon(
                      _catIcon[category],
                      size: 48,
                      color: textColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
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

  Widget _buildGuidesView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
      child: Column(
        children: [
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _stopTts();

                if (!mounted) return;

                setState(() {
                  _showCategoryMenu = true;
                });
              },
              child: const Text('Volver al menú'),
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
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            const Icon(Icons.volume_up),
          ],
        ),
      ),
    );
  }
}