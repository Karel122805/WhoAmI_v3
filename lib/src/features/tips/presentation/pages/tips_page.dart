import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});
  static const route = '/tips';

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  // Definición de colores utilizados para las categorías.
  static const Color yellow = Color(0xFFFFF49F);
  static const Color pink = Color(0xFFFF9FA1);
  static const Color blue = Color(0xFF9ED3FF);
  static const Color green = Color(0xFF9EEE97);
  static const Color purple = Color(0xFFD99FFF);

  static const Color textColor = Color(0xFF111111);

  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  // Controla si se muestra el menú principal o la lista de consejos.
  bool _showCategoryMenu = true;

  // Consejos agrupados por categoría.
  final Map<String, List<String>> _tipsByCategory = {
    'Salud física': [
      'Haz estiramientos suaves al despertar.',
      'Toma agua cada 60 minutos.',
      'Camina 10 minutos en un lugar seguro.',
      'Evita levantar objetos pesados.',
      'Detente si sientes mareo y respira profundo.',
      'Mueve tobillos y hombros antes de levantarte.',
      'Descansa cinco minutos si te sientes cansado.',
      'Carga solo cosas ligeras.',
      'Haz respiraciones profundas 3 veces.',
      'Cuéntale a un familiar si sientes dolor.',
    ],
    'Salud mental': [
      'Cuenta del 1 al 10 lentamente si te sientes nervioso.',
      'Escucha una canción relajante.',
      'Piensa en un recuerdo bonito.',
      'Mira por la ventana y describe lo que ves.',
      'Respira hondo tres veces si te enojas.',
      'Dite: “Hoy haré lo mejor que pueda”.',
      'Busca un espacio silencioso si hay ruido.',
      'Pide compañía si te sientes solo.',
      'Tómate un minuto para cerrar los ojos y respirar.',
      'Apaga sonidos fuertes si te molestan.',
    ],
    'Memoria': [
      'Di en voz alta tu nombre y dónde estás.',
      'Mira el calendario y señala la fecha.',
      'Coloca tus llaves siempre en el mismo lugar.',
      'Lee tu lista de actividades del día.',
      'Toma una foto del lugar donde dejas tus cosas.',
      'Repite nombres de familiares en fotos.',
      'Pregunta sin pena si no recuerdas algo.',
      'Usa un reloj visible por la mañana.',
      'Revisa tu agenda antes de salir.',
      'Mantén una tarjeta con tu número de contacto.',
    ],
    'Rutina y sueño': [
      'Duerme y despierta a la misma hora.',
      'Prepara la ropa antes de acostarte.',
      'Evita pantallas una hora antes de dormir.',
      'Toma poca cafeína en la tarde.',
      'Mantén el cuarto con poca luz al dormir.',
      'Haz una lista corta para el día siguiente.',
      'Apaga luces intensas antes de dormir.',
      'Evita comer muy tarde.',
      'Haz una actividad tranquila antes de acostarte.',
      'Respira profundo si despiertas en la noche.',
    ],
    'Seguridad': [
      'Mantén pasillos libres de objetos.',
      'Enciende una luz pequeña por la noche.',
      'Usa zapatos cerrados y seguros.',
      'Guarda objetos peligrosos en alto.',
      'No subas a sillas ni bancos.',
      'Revisa que la estufa esté apagada.',
      'Coloca etiquetas en puertas: Baño, Cocina, Recámara.',
      'Evita pisos mojados.',
      'Mantén cables lejos del paso.',
      'Lleva un teléfono con emergencias guardadas.',
    ],
  };

  // Color asociado a cada categoría.
  late final Map<String, Color> _catColor = {
    'Salud física': yellow,
    'Salud mental': pink,
    'Memoria': blue,
    'Rutina y sueño': green,
    'Seguridad': purple,
  };

  // Icono asociado a cada categoría.
  late final Map<String, IconData> _catIcon = {
    'Salud física': Icons.fitness_center_rounded,
    'Salud mental': Icons.self_improvement_rounded,
    'Memoria': Icons.memory_rounded,
    'Rutina y sueño': Icons.nightlight_round,
    'Seguridad': Icons.shield_rounded,
  };

  late final List<String> _categories;

  String _selected = 'Salud física';
  List<String> _visible = [];

  @override
  void initState() {
    super.initState();
    _categories = [..._tipsByCategory.keys];
    _configureTts();
  }

  // Configura el motor de texto a voz en español de México.
  Future<void> _configureTts() async {
    await _tts.setLanguage('es-MX');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  // Detiene cualquier reproducción de audio activa.
  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Se ignoran errores internos del motor de voz para no afectar la interfaz.
    }
  }

  // Carga una categoría y mezcla sus consejos de forma aleatoria.
  Future<void> _loadCategory(String category) async {
    await _stopTts();

    _selected = category;

    final tips = List<String>.from(_tipsByCategory[category]!)..shuffle(_rnd);

    if (!mounted) return;

    setState(() {
      _visible = tips;
      _showCategoryMenu = false;
    });
  }

  // Reproduce el consejo seleccionado mediante texto a voz.
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
        await _stopTts();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consejos'),
          centerTitle: true,
          elevation: 0,
        ),
        body: _showCategoryMenu ? _buildCategoryMenu() : _buildTipsView(),
      ),
    );
  }

  // Construye el menú principal de categorías.
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
                  ),
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

  // Construye la lista de consejos de la categoría seleccionada.
  Widget _buildTipsView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _visible.length,
              itemBuilder: (_, i) {
                return _TipCard(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9D8FF),
                foregroundColor: const Color(0xFF6B2FAF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Volver al menú',
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

// Tarjeta individual para mostrar y reproducir un consejo.
class _TipCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const _TipCard({
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
            ),
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