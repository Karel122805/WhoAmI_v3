import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'game_page.dart';

class BrainSaysPage extends StatefulWidget {
  const BrainSaysPage({super.key});
  static const route = '/brain_says_page.dart';

  @override
  State<BrainSaysPage> createState() => _BrainSaysPageState();
}

class _BrainSaysPageState extends State<BrainSaysPage> {
  int gridSize = 4;
  List<int> pattern = [];
  List<int> userInput = [];
  bool showingPattern = true;
  bool userTurn = false;
  int round = 1;
  int score = 0;
  int highlightedIndex = -1;
  bool paused = false;

  final Color kPurple = const Color(0xFFD6A7F4);
  final Color kBlue = const Color(0xFF9ED3FF);
  final Color kRed = const Color(0xFFFFB3B3);
  final Color kText = const Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartDialog();
    });
  }

  Future<void> _showStartDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          '¿Listo para comenzar?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Prepárate para poner a prueba tu memoria.',
          style: TextStyle(color: Colors.black87, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFB3B3),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);        // Cierra el diálogo
              Navigator.pop(context);        // 🔥 Sale del juego → vuelve a GamesPage
            },
            child: const Text('Salir al menú', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Color(0xFF9ED3FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text('Iniciar juego', style: TextStyle(fontSize: 14)),
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
    paused = false;
    _generatePattern();
    _showPattern();
  }

  void _generatePattern() {
    final random = Random();
    pattern.add(random.nextInt(gridSize));
  }

  Future<void> _showPattern() async {
    showingPattern = true;
    userTurn = false;
    setState(() {});

    for (int index in pattern) {
      if (!mounted || paused) return;
      setState(() => highlightedIndex = index);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => highlightedIndex = -1);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    showingPattern = false;
    userTurn = true;
    userInput.clear();
    setState(() {});
  }

  void onTileTap(int index) async {
    if (!userTurn || paused) return;

    setState(() => highlightedIndex = index);
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() => highlightedIndex = -1);

    userInput.add(index);

    if (userInput.last != pattern[userInput.length - 1]) {
      _showGameOver();
      return;
    }

    if (userInput.length == pattern.length) {
      score++;
      userTurn = false;
      await Future.delayed(const Duration(milliseconds: 500));

      if (round % 3 == 0 && gridSize < 9) {
        gridSize++;
      }

      round++;
      _generatePattern();
      _showPattern();
    }
  }

  double _calculateStars(int level) {
    if (level <= 1) return 0.5;
    if (level <= 3) return 1.0;
    if (level <= 5) return 1.5;
    if (level <= 7) return 2.0;
    if (level <= 9) return 2.5;
    return 3.0;
  }

  void _showGameOver() {
    final int levelReached = round - 1;
    final double starRating = _calculateStars(levelReached);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return GameEndModal(
          levelReached: levelReached,
          starRating: starRating,
          onRestart: () {
            Navigator.pop(context);
            _startGame();
          },
          onMenu: () {
            Navigator.pop(context);   // Cierra el dialogo
            Navigator.pop(context);   // 🔥 Sale hacia GamesPage
          },
          modalButtonColor: kPurple,
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
    bool result = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: kText, fontSize: 18)),
        content: Text(content,
            style: TextStyle(color: kText, fontSize: 15),
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(noText, style: const TextStyle(fontSize: 14)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              result = true;
              Navigator.pop(context);
            },
            child: Text(yesText, style: const TextStyle(fontSize: 14)),
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
    paused = true;
    final restart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Text('Juego en pausa',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: kText, fontSize: 18)),
        content: Text('¿Qué deseas hacer?',
            style: TextStyle(color: kText, fontSize: 15),
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
    paused = false;
    if (restart == true) _startGame();
  }

  @override
  Widget build(BuildContext context) {
    final tileCount = gridSize;
    final size = MediaQuery.of(context).size;
    final gridSide = sqrt(tileCount).ceil();

    return WillPopScope(
      onWillPop: () async {
        if (await _onWillPop()) {
          Navigator.pop(context);  // 🔥 Regresa al menú de juegos
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Colores',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context); // 🔥 Vuelve sin loop
              }
            },
          ),
        ),

        body: Center(
          child: SingleChildScrollView(
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
                  style:
                      const TextStyle(fontSize: 20, color: Colors.black87),
                ),
                const SizedBox(height: 15),
                Text('Nivel: $round  |  Puntuación: $score',
                    style: const TextStyle(
                        fontSize: 18, color: Colors.black54)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: size.width),
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
                      bool isActive = index == highlightedIndex;
                      return GestureDetector(
                        onTap: () => onTileTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isActive
                                ? showingPattern
                                    ? Colors.lightBlueAccent
                                    : Colors.purpleAccent.withOpacity(0.6)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black26.withOpacity(0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPurple,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        elevation: 3,
                      ),
                      onPressed: _onRestart,
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      label: const Text('Reiniciar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kRed,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        elevation: 3,
                      ),
                      onPressed: _onPause,
                      icon: const Icon(Icons.pause, color: Colors.black),
                      label: const Text('Pausa',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
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

// === MODAL DE FIN DE JUEGO ===
class StarRatingWidget extends StatelessWidget {
  final double rating;
  final Color color;
  const StarRatingWidget({super.key, required this.rating, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        double diff = rating - index;
        IconData iconData;
        if (diff >= 0.75) {
          iconData = Icons.star;
        } else if (diff >= 0.25) {
          iconData = Icons.star_half;
        } else {
          iconData = Icons.star_border;
        }
        return Icon(iconData, color: color, size: 36.0);
      }),
    );
  }
}

class GameEndModal extends StatelessWidget {
  final int levelReached;
  final double starRating;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  final Color modalButtonColor;

  const GameEndModal({
    super.key,
    required this.levelReached,
    required this.starRating,
    required this.onRestart,
    required this.onMenu,
    required this.modalButtonColor,
  });

  String getLevelName(int level) {
    if (level >= 10) return "¡Leyenda!";
    if (level >= 7) return "Avanzado";
    if (level >= 4) return "Intermedio";
    return "Fácil";
  }

  @override
  Widget build(BuildContext context) {
    final String levelName = getLevelName(levelReached);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Text('Partida Terminada',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Llegaste al nivel $levelReached ($levelName).',
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center),
          const SizedBox(height: 15),
          StarRatingWidget(rating: starRating, color: Colors.amber),
          const SizedBox(height: 20),
          const Text('¿Quieres seguir jugando?',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: onRestart,
            style: ElevatedButton.styleFrom(
              backgroundColor: modalButtonColor,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 4,
            ),
            child: const Text('Sí, jugar de nuevo',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onMenu,
            child: const Text('Salir al menú',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
