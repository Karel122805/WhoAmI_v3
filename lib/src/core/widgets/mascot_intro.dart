// lib/src/core/widgets/mascot_intro.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

class MascotIntro extends StatefulWidget {
  const MascotIntro({
    super.key,
    this.message,
    this.messages,
    required this.onClose,
  }) : assert(
          message != null || messages != null,
          'Debes proporcionar message o messages.',
        );

  final String? message;
  final List<String>? messages;
  final VoidCallback onClose;

  @override
  State<MascotIntro> createState() => _MascotIntroState();
}

class _MascotIntroState extends State<MascotIntro> {
  final FlutterTts _tts = FlutterTts();

  late final List<String> _messages;

  int _currentStep = 0;
  int _spokenChars = 0;

  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _hasStarted = false;
  bool _isClosing = false;

  String get _currentMessage => _messages[_currentStep];

  bool get _isFirstStep => _currentStep == 0;

  bool get _isLastStep => _currentStep == _messages.length - 1;

  @override
  void initState() {
    super.initState();

    if (widget.messages != null && widget.messages!.isNotEmpty) {
      _messages = List<String>.from(widget.messages!);
    } else {
      _messages = <String>[
        widget.message ?? 'Bienvenido a WhoAmI.',
      ];
    }

    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('es-MX');

    try {
      await _tts.setVoice({
        'name': 'es-mx-x-mib-network',
        'locale': 'es-MX',
      });
    } catch (_) {
      // Se utiliza la voz predeterminada si esta no está disponible.
    }

    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.1);

    _tts.setProgressHandler(
      (
        String text,
        int start,
        int end,
        String word,
      ) {
        if (!mounted) {
          return;
        }

        setState(() {
          _spokenChars = end.clamp(
            0,
            _currentMessage.length,
          );
        });
      },
    );

    _tts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _spokenChars = _currentMessage.length;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSpeaking = false;
      });
    });

    _tts.setErrorHandler((message) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    if (mounted && !_isClosing) {
      await _speakFull();
    }
  }

  Future<void> _speakFull() async {
    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeaking = true;
      _isPaused = false;
      _hasStarted = true;
      _spokenChars = 0;
    });

    await _tts.speak(_currentMessage);
  }

  Future<void> _pauseSpeech() async {
    if (!_hasStarted) {
      _showFloatingAlert(
        'Debes iniciar el audio antes.',
      );
      return;
    }

    if (!_isSpeaking) {
      _showFloatingAlert(
        'El audio no está en reproducción.',
      );
      return;
    }

    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeaking = false;
      _isPaused = true;
    });
  }

  Future<void> _continueSpeech() async {
    if (!_isPaused) {
      _showFloatingAlert(
        'El audio no está en pausa.',
      );
      return;
    }

    if (_spokenChars >= _currentMessage.length) {
      _showFloatingAlert(
        'El audio ya terminó. Usa repetir.',
      );
      return;
    }

    final int safeIndex = _spokenChars.clamp(
      0,
      _currentMessage.length,
    );

    final String remainingMessage =
        _currentMessage.substring(safeIndex);

    if (!mounted) {
      return;
    }

    setState(() {
      _isPaused = false;
      _isSpeaking = true;
    });

    await _tts.speak(remainingMessage);
  }

  Future<void> _stopSpeech({
    bool showAlert = true,
  }) async {
    if (!_hasStarted) {
      if (showAlert) {
        _showFloatingAlert(
          'Debes iniciar el audio antes.',
        );
      }
      return;
    }

    if (!_isSpeaking && !_isPaused) {
      if (showAlert) {
        _showFloatingAlert(
          'El audio no se está reproduciendo.',
        );
      }
      return;
    }

    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _spokenChars = 0;
    });
  }

  Future<void> _goToPreviousStep() async {
    if (_isFirstStep) {
      return;
    }

    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentStep--;
      _spokenChars = 0;
      _isSpeaking = false;
      _isPaused = false;
      _hasStarted = false;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (mounted) {
      await _speakFull();
    }
  }

  Future<void> _goToNextStep() async {
    if (_isLastStep) {
      await _closeTutorial();
      return;
    }

    await _tts.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _currentStep++;
      _spokenChars = 0;
      _isSpeaking = false;
      _isPaused = false;
      _hasStarted = false;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (mounted) {
      await _speakFull();
    }
  }

  Future<void> _closeTutorial() async {
    if (_isClosing) {
      return;
    }

    _isClosing = true;

    await _tts.stop();

    if (!mounted) {
      return;
    }

    widget.onClose();
  }

  void _showFloatingAlert(String text) {
    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        final colors = dialogContext.appColors;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 30,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: dialogContext.isDark
                    ? colors.categoryPurple.withValues(alpha: 0.92)
                    : const Color(0xFFD6A7F4),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.25,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dialogContext.isDark
                      ? colors.textPrimary
                      : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      },
    );

    Future<void>.delayed(
      const Duration(milliseconds: 1400),
      () {
        if (!mounted) {
          return;
        }

        final NavigatorState navigator = Navigator.of(
          context,
          rootNavigator: true,
        );

        if (navigator.canPop()) {
          navigator.pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final colors = context.appColors;

    final Color accentColor = context.isDark
        ? colors.categoryPurple
        : const Color(0xFFD6A7F4);

    final Color accentTextColor = context.isDark
        ? colors.categoryPurple
        : const Color(0xFF7D62A3);

    final Color progressBackground = context.isDark
        ? colors.elevatedCard
        : const Color(0xFFEDE7F6);

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.black.withValues(
          alpha: context.isDark ? 0.68 : 0.48,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: screenSize.height * 0.90,
                ),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: context.isDark
                          ? colors.categoryBlue
                          : const Color(0xFF9ED3FF),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _closeTutorial,
                          child: Text(
                            'Omitir',
                            style: TextStyle(
                              color: accentTextColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/assistant.png',
                        height: 135,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Icon(
                            Icons.smart_toy_rounded,
                            size: 100,
                            color: accentColor,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Paso ${_currentStep + 1} de ${_messages.length}',
                        style: TextStyle(
                          color: accentTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value:
                              (_currentStep + 1) / _messages.length,
                          minHeight: 8,
                          backgroundColor: progressBackground,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _currentMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: colors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildAudioButton(
                            tooltip: 'Repetir',
                            icon: Icons.refresh_rounded,
                            onPressed: _speakFull,
                          ),
                          _buildAudioButton(
                            tooltip: _isSpeaking
                                ? 'Pausar'
                                : 'Reproducir',
                            icon: _isSpeaking
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onPressed: () {
                              if (_isSpeaking) {
                                _pauseSpeech();
                              } else if (_isPaused) {
                                _continueSpeech();
                              } else {
                                _speakFull();
                              }
                            },
                          ),
                          _buildAudioButton(
                            tooltip: 'Detener',
                            icon: Icons.stop_rounded,
                            onPressed: _stopSpeech,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          if (!_isFirstStep)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _goToPreviousStep,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                ),
                                label: const Text('Anterior'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accentTextColor,
                                  side: BorderSide(
                                    color: accentColor,
                                    width: 2,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          if (!_isFirstStep)
                            const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _goToNextStep,
                              icon: Icon(
                                _isLastStep
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                              label: Text(
                                _isLastStep
                                    ? 'Finalizar'
                                    : 'Siguiente',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: context.isDark
                                    ? colors.textPrimary
                                    : Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final colors = context.appColors;

    final Color buttonColor = context.isDark
        ? colors.categoryPurple
        : const Color(0xFFD6A7F4);

    final Color iconColor = context.isDark
        ? colors.textPrimary
        : Colors.white;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}