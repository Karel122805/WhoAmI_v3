import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme.dart';
import 'memorama_page.dart';
import 'brain_says_page.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});
  static const route = '/games';

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  final FlutterTts tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    tts.setLanguage("es-MX");
    tts.setSpeechRate(0.45);
    tts.setVolume(1.0);
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await tts.stop();
    await tts.speak(text);
  }

  void _stopTTS() {
    tts.stop();
  }

  Widget gameCard({
    required Color color,
    required Widget icon,
    required String title,
    required VoidCallback onHelp,
    required VoidCallback onOpen,
  }) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        height: 150,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 4),
              blurRadius: 10,
            )
          ],
        ),
        child: Stack(
          children: [
            // ICONO CENTRADO
            Center(child: icon),

            // TEXTO CENTRADO ABAJO
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),

            // BOTÓN DE AYUDA EN LA ESQUINA SUPERIOR DERECHA
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline_rounded, color: kInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === ICONO PERSONALIZADO PARA SECUENCIA DE COLORES ===
  Widget sequenceIcon() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 18,
            child: Icon(Icons.circle, size: 22, color: Colors.red),
          ),
          Positioned(
            top: 22,
            right: 0,
            child: Icon(Icons.circle, size: 22, color: Colors.yellow),
          ),
          Positioned(
            bottom: 0,
            left: 18,
            child: Icon(Icons.circle, size: 22, color: Colors.blue),
          ),
          Positioned(
            bottom: 22,
            left: 0,
            child: Icon(Icons.circle, size: 22, color: Colors.green),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔥 AppBar corregida: no usa back automático → se arregla el bug 🔥
      appBar: AppBar(
        title: const Text('Juegos'),
        backgroundColor: Colors.white,
        foregroundColor: kInk,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            _stopTTS();
            Navigator.pop(context); // ← YA NO REDIRIGE A JUEGOS OTRA VEZ
          },
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Selecciona un juego",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 🟪 MEMORAMA
                  gameCard(
                    color: kPurple,
                    icon: const Icon(
                      Icons.extension_rounded,
                      size: 78,
                      color: kBlue,
                    ),
                    title: "Memorama",
                    onHelp: () => _speak(
                      "En este juego debes voltear tarjetas y encontrar las parejas iguales. Memoriza la posición de cada tarjeta y trata de hacer la menor cantidad de intentos.",
                    ),
                    onOpen: () {
                      _stopTTS();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MemoramaPage(),
                          maintainState: false,
                        ),
                      );
                    },
                  ),

                  // 🟨 SECUENCIA
                  gameCard(
                    color: const Color(0xFFF7F5C2),
                    icon: sequenceIcon(),
                    title: "Secuencia",
                    onHelp: () => _speak(
                      "En este juego debes observar una secuencia de colores y repetirla en el mismo orden. Cada ronda se vuelve más larga y desafiante.",
                    ),
                    onOpen: () {
                      _stopTTS();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BrainSaysPage(),
                          maintainState: false,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
