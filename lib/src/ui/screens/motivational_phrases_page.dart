import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MotivationalPhrasesPage extends StatefulWidget {
  const MotivationalPhrasesPage({super.key});
  static const route = '/motivational-phrases';

  @override
  State<MotivationalPhrasesPage> createState() =>
      _MotivationalPhrasesPageState();
}

class _MotivationalPhrasesPageState extends State<MotivationalPhrasesPage> {
  // PALETA EXACTA PASTEL
  static const Color yellow = Color(0xFFFFF49F);
  static const Color pink = Color(0xFFFF9FA1);
  static const Color blue = Color(0xFF9ED3FF);
  static const Color green = Color(0xFF9EEE97);
  static const Color purple = Color(0xFFD99FFF);

  static const Color textColor = Color(0xFF111111);

  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  bool _showMenu = true;

  // FRASES POR CATEGORÍA (5 x 8)
  final Map<String, List<String>> _phrasesByCategory = {
    "Ánimo": [
      "Hoy es un buen día para intentarlo con calma.",
      "Paso a pasito, lo estoy haciendo bien.",
      "Puedo aprender algo pequeño hoy.",
      "Mi esfuerzo de hoy cuenta y vale.",
      "Respiro hondo y sigo adelante.",
      "Soy más fuerte de lo que pienso.",
      "Cada momento es una nueva oportunidad.",
      "Hago lo mejor que puedo y eso está bien.",
    ],
    "Calma": [
      "Respiro lento tres veces y siento paz.",
      "Puedo pausar un momento y descansar.",
      "Mi cuerpo se relaja cuando respiro suave.",
      "Puedo tomarme mi tiempo, no hay prisa.",
      "Si me confundo, respiro y vuelvo a empezar.",
      "La calma llega cuando escucho mi respiración.",
      "Estoy a salvo aquí y ahora.",
      "Puedo soltar la tensión de mis hombros y seguir.",
    ],
    "Memoria": [
      "Mi nombre es importante y vale mucho.",
      "Hay recuerdos bonitos guardados en mi corazón.",
      "Puedo pedir ayuda cuando la necesito.",
      "Lo que soy no se pierde: sigo siendo yo.",
      "Cada día puedo recordar algo sencillo.",
      "Soy valioso para mi familia y para mí.",
      "Puedo mirar una foto y sonreír.",
      "Mi historia sigue, paso a paso.",
    ],
    "Autonomía": [
      "Hoy puedo lograr una tarea sencilla.",
      "Si no sale a la primera, lo intento de nuevo.",
      "Puedo seguir instrucciones cortas y claras.",
      "Un pequeño logro es un gran avance.",
      "Puedo organizar mis cosas con ayuda.",
      "Mi ritmo es perfecto para mí.",
      "Celebro lo que sí pude hacer hoy.",
      "Puedo pedir indicaciones y seguirlas.",
    ],
    "Afecto": [
      "No estoy solo: hay gente que me quiere.",
      "Puedo pedir un abrazo cuando lo necesite.",
      "Mi voz es escuchada con cariño.",
      "Caminar acompañado me hace bien.",
      "Gracias por cuidar de mí; yo también cuido de mí.",
      "Puedo sonreír y agradecer las cosas simples.",
      "Juntos es más fácil y más bonito.",
      "La ternura también es una fuerza.",
    ],
  };

  // COLORES POR CATEGORÍA
  late final Map<String, Color> _catColor = {
    "Ánimo": yellow,
    "Calma": pink,
    "Memoria": blue,
    "Autonomía": green,
    "Afecto": purple,
  };

  // ICONOS POR CATEGORÍA
  late final Map<String, IconData> _catIcon = {
    "Ánimo": Icons.wb_sunny_rounded,
    "Calma": Icons.self_improvement_rounded,
    "Memoria": Icons.memory_rounded,
    "Autonomía": Icons.track_changes_rounded,
    "Afecto": Icons.favorite_rounded,
  };

  late final List<String> _categories;

  String _selected = "Ánimo";
  List<String> _visible = [];

  @override
  void initState() {
    super.initState();
    _categories = [..._phrasesByCategory.keys];
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage("es-MX");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  void _loadCategory(String cat) async {
    await _tts.stop();
    _selected = cat;

    final list = List<String>.from(_phrasesByCategory[cat]!)..shuffle(_rnd);

    setState(() {
      _visible = list;
      _showMenu = false;
    });
  }

  Future<void> _speak(String t) async {
    await _tts.stop();
    await _tts.speak(t);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Frases"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _showMenu ? _buildMenu() : _buildPhrases(),
    );
  }

  // ⭐ MENÚ DE CATEGORÍAS
  Widget _buildMenu() {
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
                          color: textColor),
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

  // ⭐ LISTA DE FRASES
  Widget _buildPhrases() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _visible.length,
              itemBuilder: (_, i) {
                return _PhraseCard(
                  text: _visible[i],
                  color: _catColor[_selected]!,
                  icon: _catIcon[_selected]!,
                  onTap: () => _speak(_visible[i]),
                );
              },
            ),
          ),

          // BOTÓN VOLVER AL MENÚ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _showMenu = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9D8FF),
                foregroundColor: Color(0xFF6B2FAF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                elevation: 4,
              ),
              child: const Text(
                "Volver al menú",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ⭐ CARD INDIVIDUAL
class _PhraseCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const _PhraseCard({
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
                  height: 1.3,
                  color: Colors.black,
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
