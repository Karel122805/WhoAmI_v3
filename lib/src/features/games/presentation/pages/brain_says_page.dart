import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/games/data/brain_says_progress_service.dart';

class BrainSaysPage extends StatefulWidget {
  const BrainSaysPage({super.key});
  static const route = '/brain_says_page.dart';

  @override
  State<BrainSaysPage> createState() => _BrainSaysPageState();
}

class _BrainSaysPageState extends State<BrainSaysPage> {
  final BrainSaysProgressService _progressService =
      BrainSaysProgressService();

  int gridSize = 4;
  List<int> pattern = [];
  List<int> userInput = [];

  bool showingPattern = true;
  bool userTurn = false;
  bool paused = false;
  bool loadingRecord = true;

  int round = 1;
  int score = 0;
  int highlightedIndex = -1;

  int highScore = 0;
  int highLevel = 0;

  final Random _random = Random();

  final List<String> _recordMessages = [
    '¡Excelente trabajo! Hoy lograste un nuevo récord.',
    '¡Muy bien! Tu memoria sigue mejorando.',
    '¡Gran avance! Cada intento te hace más fuerte.',
    '¡Lo hiciste increíble! Superaste tu mejor puntuación.',
    '¡Felicidades! Tu esfuerzo está dando resultados.',
    '¡Buen trabajo! Vas progresando paso a paso.',
    '¡Qué gran partida! Sigue así.',
    '¡Muy buen esfuerzo! Hoy llegaste más lejos.',
  ];

  final List<String> _encouragementMessages = [
    'Buen trabajo, podemos mejorar un poco más en el siguiente intento.',
    'Lo hiciste bien. Cada ronda ayuda a entrenar tu memoria.',
    'Vas muy bien, intenta una vez más con calma.',
    'No pasa nada, lo importante es seguir practicando.',
    'Buen intento. Poco a poco vas fortaleciendo tu memoria.',
    'Cada partida cuenta. Sigue practicando a tu ritmo.',
    'Muy buen esfuerzo. La próxima puede salir mejor.',
    'Sigue así, estás entrenando tu mente.',
    'Lo estás haciendo bien. Respira y vuelve a intentarlo.',
    'Buen trabajo, vamos paso a paso.',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final savedScore = await _progressService.getHighScore();
    final savedLevel = await _progressService.getHighLevel();

    if (!mounted) return;

    setState(() {
      highScore = savedScore;
      highLevel = savedLevel;
      loadingRecord = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartDialog();
    });
  }

  String _getRandomMotivationalMessage(bool newRecord) {
    final messages = newRecord ? _recordMessages : _encouragementMessages;
    return messages[_random.nextInt(messages.length)];
  }

  Future<void> _showStartDialog() async {
    final colors = context.appColors;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colors.cardBackground,
        title: Text(
          '¿Listo para comenzar?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          highScore > 0
              ? 'Tu récord actual es de $highScore puntos. ¡Intenta superarlo!'
              : 'Prepárate para poner a prueba tu memoria.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Salir al menú',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text(
              'Iniciar juego',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _startGame() {
    pattern.clear();
    userInput.clear();
    gridSize = 4;
    round = 1;
    score = 0;
    showingPattern = true;
    userTurn = false;
    paused = false;
    highlightedIndex = -1;

    _generatePattern();
    _showPattern();
  }

  void _generatePattern() {
    pattern.add(_random.nextInt(gridSize));
  }

  Future<void> _showPattern() async {
    showingPattern = true;
    userTurn = false;
    setState(() {});

    for (int index in pattern) {
      if (!mounted || paused) return;

      setState(() => highlightedIndex = index);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      setState(() => highlightedIndex = -1);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    showingPattern = false;
    userTurn = true;
    userInput.clear();

    if (mounted) setState(() {});
  }

  Future<void> onTileTap(int index) async {
    if (!userTurn || paused) return;

    setState(() => highlightedIndex = index);

    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    setState(() => highlightedIndex = -1);

    userInput.add(index);

    if (userInput.last != pattern[userInput.length - 1]) {
      await _showGameOver();
      return;
    }

    if (userInput.length == pattern.length) {
      score++;
      userTurn = false;

      if (score > highScore) {
        setState(() {
          highScore = score;
          highLevel = round;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (round % 3 == 0 && gridSize < 9) {
        gridSize++;
      }

      round++;
      _generatePattern();
      _showPattern();
    }
  }

  Future<void> _showGameOver() async {
    final int levelReached = round - 1;

    final bool newRecord = await _progressService.saveRecordIfBetter(
      score: score,
      level: levelReached,
    );

    final savedScore = await _progressService.getHighScore();
    final savedLevel = await _progressService.getHighLevel();

    if (!mounted) return;

    setState(() {
      highScore = savedScore;
      highLevel = savedLevel;
    });

    final motivationalMessage = _getRandomMotivationalMessage(newRecord);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return GameEndModal(
          levelReached: levelReached,
          score: score,
          highScore: highScore,
          highLevel: highLevel,
          newRecord: newRecord,
          motivationalMessage: motivationalMessage,
          onRestart: () {
            Navigator.pop(dialogContext);
            _startGame();
          },
          onMenu: () {
            Navigator.pop(dialogContext);
            Navigator.pop(context);
          },
          modalButtonColor: context.appColors.secondaryButton,
        );
      },
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String noText,
    required String yesText,
  }) async {
    final colors = context.appColors;
    bool result = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colors.cardBackground,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          content,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              noText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onPressed: () {
              result = true;
              Navigator.pop(context);
            },
            child: Text(
              yesText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return result;
  }

  Future<bool> _onWillPop() async {
    return await _showConfirmDialog(
      title: '¿Estás seguro que quieres salir?',
      content: 'Perderás tu partida actual.',
      noText: 'No, continuar jugando',
      yesText: 'Sí, salir',
    );
  }

  Future<void> _onRestart() async {
    final confirm = await _showConfirmDialog(
      title: '¿Reiniciar partida?',
      content: 'Se perderá tu progreso actual.',
      noText: 'No, continuar',
      yesText: 'Sí, reiniciar',
    );

    if (confirm) _startGame();
  }

  Future<void> _onPause() async {
    final colors = context.appColors;
    paused = true;

    final restart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colors.cardBackground,
        title: Text(
          'Juego en pausa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '¿Qué deseas hacer?',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Continuar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reiniciar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    paused = false;

    if (restart == true) {
      _startGame();
    } else {
      setState(() {});
    }
  }

  Color _tileBaseColor(BuildContext context) {
    final colors = context.appColors;
    return context.isDark ? colors.inputFill : colors.chipBackground;
  }

  Color _tileActiveColor(BuildContext context) {
    final colors = context.appColors;
    return showingPattern ? colors.primaryButton : colors.secondaryButton;
  }

  Future<void> _handleExit() async {
    final confirm = await _onWillPop();

    if (!mounted) return;

    if (confirm) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tileCount = gridSize;
    final size = MediaQuery.of(context).size;
    final gridSide = sqrt(tileCount).ceil();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Colores',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          backgroundColor: colors.pageBackground,
          foregroundColor: colors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: _handleExit,
          ),
        ),
        body: loadingRecord
            ? Center(
                child: CircularProgressIndicator(
                  color: colors.primaryButton,
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        showingPattern
                            ? 'Observa el patrón...'
                            : userTurn
                                ? 'Repite el patrón'
                                : 'Esperando...',
                        style: TextStyle(
                          fontSize: 20,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'Nivel: $round  |  Puntuación: $score',
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? colors.inputFill
                              : colors.chipBackground,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.primaryButton),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: colors.primaryButton,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Récord: $highScore puntos',
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: min(size.width - 32, 420),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.border),
                          boxShadow: context.isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color:
                                        colors.textPrimary.withOpacity(0.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tileCount,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridSide,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final isActive = index == highlightedIndex;
                            final tileColor = isActive
                                ? _tileActiveColor(context)
                                : _tileBaseColor(context);

                            return GestureDetector(
                              onTap: () => onTileTap(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isActive
                                        ? colors.textPrimary.withOpacity(0.12)
                                        : colors.border,
                                    width: isActive ? 1.8 : 1.1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: tileColor.withOpacity(0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: colors.textPrimary
                                                .withOpacity(
                                              context.isDark ? 0.04 : 0.08,
                                            ),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.secondaryButton,
                              foregroundColor: colors.secondaryButtonText,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              elevation: context.isDark ? 0 : 3,
                            ),
                            onPressed: _onRestart,
                            icon: Icon(
                              Icons.refresh,
                              color: colors.secondaryButtonText,
                            ),
                            label: const Text(
                              'Reiniciar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.emergency,
                              foregroundColor: colors.emergencyText,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              elevation: context.isDark ? 0 : 3,
                            ),
                            onPressed: _onPause,
                            icon: Icon(
                              Icons.pause,
                              color: colors.emergencyText,
                            ),
                            label: const Text(
                              'Pausa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class GameEndModal extends StatelessWidget {
  final int levelReached;
  final int score;
  final int highScore;
  final int highLevel;
  final bool newRecord;
  final String motivationalMessage;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  final Color modalButtonColor;

  const GameEndModal({
    super.key,
    required this.levelReached,
    required this.score,
    required this.highScore,
    required this.highLevel,
    required this.newRecord,
    required this.motivationalMessage,
    required this.onRestart,
    required this.onMenu,
    required this.modalButtonColor,
  });

  String getLevelName(int level) {
    if (level >= 10) return '¡Leyenda!';
    if (level >= 7) return 'Avanzado';
    if (level >= 4) return 'Intermedio';
    return 'Fácil';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final levelName = getLevelName(levelReached);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            newRecord
                ? Icons.emoji_events_rounded
                : Icons.psychology_alt_rounded,
            color: newRecord ? Colors.amber : colors.primaryButton,
            size: 54,
          ),
          const SizedBox(height: 10),
          Text(
            newRecord ? '¡Nuevo récord!' : 'Buen esfuerzo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Llegaste al nivel $levelReached ($levelName).',
            style: TextStyle(
              fontSize: 16,
              color: colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Puntuación: $score',
            style: TextStyle(
              fontSize: 17,
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Récord: $highScore puntos',
            style: TextStyle(
              fontSize: 16,
              color: colors.primaryButton,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (highLevel > 0)
            Text(
              'Nivel récord: $highLevel',
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.isDark ? colors.inputFill : colors.chipBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              motivationalMessage,
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              backgroundColor: modalButtonColor,
              foregroundColor: colors.secondaryButtonText,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: context.isDark ? 0 : 4,
            ),
            child: const Text(
              'Sí, jugar de nuevo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onMenu,
            child: Text(
              'Salir al menú',
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}