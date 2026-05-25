// lib/widgets/mascot_intro.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MascotIntro extends StatefulWidget {
  final String message;
  final VoidCallback onClose;

  const MascotIntro({
    super.key,
    required this.message,
    required this.onClose,
  });

  @override
  State<MascotIntro> createState() => _MascotIntroState();
}

class _MascotIntroState extends State<MascotIntro> {
  final FlutterTts tts = FlutterTts();

  bool isSpeaking = false;
  bool isPaused = false;
  bool hasStarted = false;

  int spokenChars = 0; // progreso por caracteres

  @override
  void initState() {
    super.initState();
    _configureTTS();
    _autoSpeak();
  }

  // ===============================
  // CONFIGURACIÓN DEL TTS
  // ===============================
  Future<void> _configureTTS() async {
    await tts.setLanguage("es-MX");

    await tts.setVoice({
      "name": "es-mx-x-mib-network",
      "locale": "es-MX",
    });

    await tts.setSpeechRate(0.52);
    await tts.setPitch(1.1);

    // PROGRESO REAL
    tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      setState(() => spokenChars = end);
    });

    // TERMINÓ (NO CIERRA LA VENTANA)
    tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        isSpeaking = false;
        isPaused = false;
        spokenChars = widget.message.length;
      });
    });
  }

  Future<void> _autoSpeak() async {
    await Future.delayed(const Duration(milliseconds: 400));
    speakFull();
  }

  // ===============================
  // REPRODUCIR COMPLETO
  // ===============================
  Future<void> speakFull() async {
    await tts.stop();

    setState(() {
      isSpeaking = true;
      isPaused = false;
      hasStarted = true;
      spokenChars = 0;
    });

    await tts.speak(widget.message);
  }

  // ===============================
  // PAUSAR (simulada)
  // ===============================
  Future<void> pauseSpeech() async {
    if (!hasStarted) {
      _showFloatingAlert("Debes iniciar el audio antes.");
      return;
    }

    if (!isSpeaking) {
      _showFloatingAlert("El audio no está en reproducción.");
      return;
    }

    await tts.stop();

    setState(() {
      isPaused = true;
      isSpeaking = false;
    });
  }

  // ===============================
  // CONTINUAR DESDE DONDE SE QUEDÓ
  // ===============================
  Future<void> continueSpeech() async {
    if (!isPaused) {
      _showFloatingAlert("El audio no está en pausa.");
      return;
    }

    if (spokenChars >= widget.message.length) {
      _showFloatingAlert("El audio ya terminó. Usa repetir.");
      return;
    }

    final remaining = widget.message.substring(spokenChars);

    setState(() {
      isPaused = false;
      isSpeaking = true;
    });

    await tts.speak(remaining);
  }

  // ===============================
  // DETENER
  // ===============================
  Future<void> stopSpeech() async {
    if (!hasStarted) {
      _showFloatingAlert("Debes iniciar el audio antes.");
      return;
    }

    if (!isSpeaking && !isPaused) {
      if (spokenChars >= widget.message.length) {
        _showFloatingAlert("El audio ya terminó. Usa repetir.");
      } else {
        _showFloatingAlert("El audio no se está reproduciendo.");
      }
      return;
    }

    await tts.stop();

    setState(() {
      isSpeaking = false;
      isPaused = false;
      spokenChars = 0;
    });
  }

  // ===============================
  // ALERTA FLOTANTE (sin subrayado, encima de todo)
  // ===============================
  void _showFloatingAlert(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (_) {
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD6A7F4),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  // ===============================
  // UI COMPLETA DEL TUTORIAL
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF9ED3FF),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("assets/assistant.png", height: 150),

              const SizedBox(height: 12),

              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // REPEAT
                  _roundedButton(
                    icon: Icons.refresh_rounded,
                    onTap: speakFull,
                  ),

                  const SizedBox(width: 12),

                  // PLAY / PAUSE
                  _roundedButton(
                    icon: isSpeaking ? Icons.pause : Icons.play_arrow,
                    onTap: () {
                      if (isSpeaking) {
                        pauseSpeech();
                      } else if (isPaused) {
                        continueSpeech();
                      } else {
                        speakFull();
                      }
                    },
                  ),

                  const SizedBox(width: 12),

                  // STOP
                  _roundedButton(
                    icon: Icons.stop,
                    onTap: stopSpeech,
                  ),

                  const SizedBox(width: 14),

                  ElevatedButton(
                    onPressed: () {
                      stopSpeech();
                      widget.onClose();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD6A7F4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      "Omitir",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundedButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFFD6A7F4),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}






