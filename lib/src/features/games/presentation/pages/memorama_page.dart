import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

class MemoramaPage extends StatefulWidget {
  const MemoramaPage({super.key});
  static const route = '/games/memorama';

  @override
  State<MemoramaPage> createState() => _MemoramaPageState();
}

class _MemoramaPageState extends State<MemoramaPage>
    with TickerProviderStateMixin {
  final List<IconData> _icons = const [
    Icons.favorite,
    Icons.star,
    Icons.pets,
    Icons.coffee,
    Icons.flash_on,
    Icons.face,
    Icons.catching_pokemon,
    Icons.rocket_launch,
    Icons.apple,
    Icons.sports_basketball,
    Icons.flight,
    Icons.icecream,
  ];

  late List<int> _cards;
  late List<bool> _revealed;
  int? _firstIndex;

  bool _waiting = false;
  bool _started = false;
  bool _paused = false;

  int _moves = 0;
  int _seconds = 0;
  int _score = 0;
  Timer? _timer;
  String? _level;

  final Map<String, int> _starsPerLevel = {};

  late final AnimationController _bannerCtrl;
  late final Animation<double> _bannerOpacity;
  late final Animation<Offset> _bannerSlide;
  bool _showBanner = false;
  String _bannerText = '';

  late final ConfettiController _confettiCtrl;

  @override
  void initState() {
    super.initState();

    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _bannerOpacity = CurvedAnimation(
      parent: _bannerCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _bannerCtrl,
        curve: Curves.decelerate,
        reverseCurve: Curves.easeIn,
      ),
    );

    _confettiCtrl = ConfettiController(
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmExitGame() async {
    if (!_started) {
      _goToGamesMenuClearingGame();
      return;
    }

    final colors = context.appColors;

    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          '¿Estás seguro que quieres salir?',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Perderás tu partida actual.',
          style: TextStyle(color: colors.textPrimary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
            ),
            child: const Text('No, continuar jugando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
            ),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );

    if (salir == true) {
      _goToGamesMenuClearingGame();
    }
  }

  void _goToGamesMenuClearingGame() {
    _timer?.cancel();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/games',
      (route) =>
          route.isFirst ||
          route.settings.name == '/home/caregiver' ||
          route.settings.name == '/home/consultant',
    );
  }

  int get _gridSize {
    switch (_level) {
      case 'Medio':
        return 4;
      case 'Difícil':
        return 6;
      default:
        return 3;
    }
  }

  int get _pairCount {
    switch (_level) {
      case 'Medio':
        return 8;
      case 'Difícil':
        return 12;
      default:
        return 4;
    }
  }

  void _startGame() {
    if (_level == null) {
      final colors = context.appColors;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona un nivel antes de iniciar.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colors.textPrimary,
        ),
      );
      return;
    }

    final base = List.generate(_pairCount, (i) => i);
    _cards = [...base, ...base]..shuffle(Random());
    _revealed = List<bool>.filled(_cards.length, false);
    _firstIndex = null;
    _waiting = false;
    _moves = 0;
    _seconds = 0;
    _score = 0;
    _paused = false;
    _started = true;

    _showLevelBanner('Nivel $_level iniciado');
    _timer?.cancel();
    _startTimer();
    setState(() {});
  }

  void _resetGame() => _startGame();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _started && !_paused) {
        setState(() => _seconds++);
      }
    });
  }

  void _pauseGame() {
    setState(() => _paused = !_paused);

    if (_paused) {
      _timer?.cancel();
      _showPauseDialog();
    } else {
      _startTimer();
    }
  }

  Future<void> _onCardTap(int index) async {
    if (!_started || _paused || _waiting || _revealed[index]) return;

    setState(() => _revealed[index] = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    _moves++;

    if (_cards[_firstIndex!] != _cards[index]) {
      _waiting = true;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() {
        _revealed[_firstIndex!] = false;
        _revealed[index] = false;
      });

      _waiting = false;
    } else {
      _score++;
    }

    _firstIndex = null;

    if (_revealed.every((r) => r)) {
      _timer?.cancel();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _showWinDialog();
    } else {
      if (mounted) setState(() {});
    }
  }

  void _showPauseDialog() {
    final colors = context.appColors;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Juego en pausa',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Puedes continuar o reiniciar el juego.',
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pauseGame();
            },
            style: TextButton.styleFrom(
              backgroundColor: colors.primaryButton,
              foregroundColor: colors.primaryButtonText,
            ),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            style: TextButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
            ),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }

  int _computeStars() {
    if (_level == 'Fácil') {
      if (_seconds <= 25 && _moves <= 10) return 3;
      if (_seconds <= 40 && _moves <= 15) return 2;
      if (_seconds <= 60 || _moves <= 20) return 1;
    } else if (_level == 'Medio') {
      if (_seconds <= 40 && _moves <= 14) return 3;
      if (_seconds <= 60 && _moves <= 18) return 2;
      if (_seconds <= 90 || _moves <= 24) return 1;
    } else if (_level == 'Difícil') {
      if (_seconds <= 60 && _moves <= 18) return 3;
      if (_seconds <= 90 && _moves <= 24) return 2;
      if (_seconds <= 120 || _moves <= 30) return 1;
    }
    return 0;
  }

  void _showWinDialog() {
    final colors = context.appColors;
    final stars = _computeStars();
    _starsPerLevel[_level ?? ''] = stars;

    String? nextLevel;
    if (_level == 'Fácil') {
      nextLevel = 'Medio';
    } else if (_level == 'Medio') {
      nextLevel = 'Difícil';
    }

    if (nextLevel == null) {
      _showFinalAverageDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Nivel completado',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Completaste el nivel $_level en $_moves movimientos y ${_seconds}s.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textPrimary),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  Icons.star_rounded,
                  size: 34,
                  color: i < stars ? Colors.amber : colors.border,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Quieres jugar de nuevo este nivel?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            style: TextButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
            ),
            child: const Text('Sí, jugar de nuevo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _level = nextLevel);
              _startGame();
            },
            child: Text(
              'Continuar al siguiente nivel',
              style: TextStyle(
                color: colors.secondaryButton,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _goToGamesMenuClearingGame();
            },
            child: Text(
              'Salir al menú',
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showFinalAverageDialog() {
    final colors = context.appColors;
    _confettiCtrl.play();

    final totalStars = _starsPerLevel.values.fold<int>(0, (a, b) => a + b);
    final avg = totalStars / _starsPerLevel.length;
    final fullStars = avg.floor();
    final hasHalf = avg - fullStars >= 0.5;

    String feedback;
    if (avg >= 2.5) {
      feedback = 'Excelente desempeño, has logrado dominar el juego.';
    } else if (avg >= 1.5) {
      feedback = 'Buen trabajo, tu memoria está mejorando.';
    } else {
      feedback = 'Sigue practicando, puedes hacerlo mejor.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.08,
              numberOfParticles: 14,
              maxBlastForce: 25,
              minBlastForce: 10,
              gravity: 0.25,
              shouldLoop: true,
              colors: [
                colors.secondaryButton,
                colors.primaryButton,
                Colors.amber,
                colors.cardBackground,
              ],
            ),
          ),
          Center(
            child: Container(
              width: 330,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                border: Border.all(color: colors.primaryButton, width: 2),
                borderRadius: BorderRadius.circular(28),
                boxShadow: context.isDark
                    ? []
                    : [
                        BoxShadow(
                          color: colors.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Has completado los tres niveles',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: _starsPerLevel.entries.map((entry) {
                      final stars = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${entry.key}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Row(
                              children: List.generate(
                                3,
                                (i) => Icon(
                                  Icons.star_rounded,
                                  color: i < stars ? Colors.amber : colors.border,
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Divider(thickness: 1, color: colors.border),
                  const SizedBox(height: 8),
                  Text(
                    'Estrellas finales',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < fullStars; i++)
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 34,
                        ),
                      if (hasHalf)
                        const Icon(
                          Icons.star_half_rounded,
                          color: Colors.amber,
                          size: 34,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    feedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextButton(
                    onPressed: () {
                      _confettiCtrl.stop();
                      _goToGamesMenuClearingGame();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: colors.secondaryButton,
                      foregroundColor: colors.secondaryButtonText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Volver al menú de juegos',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLevelBanner(String text) async {
    setState(() {
      _bannerText = text;
      _showBanner = true;
    });

    await _bannerCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    await _bannerCtrl.reverse();

    if (!mounted) return;
    setState(() => _showBanner = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: _confirmExitGame,
        ),
        title: Text(
          'Memorama',
          style: TextStyle(color: colors.textPrimary),
        ),
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          SafeArea(
            child: !_started ? _buildMenuInicio(context) : _buildGameUI(context),
          ),
          if (_showBanner)
            FadeTransition(
              opacity: _bannerOpacity,
              child: SlideTransition(
                position: _bannerSlide,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    border: Border.all(color: colors.primaryButton, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _bannerText,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuInicio(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          border: Border.all(color: colors.primaryButton, width: 2),
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.isDark
              ? []
              : [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Comienza tu juego',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _level,
              dropdownColor: colors.cardBackground,
              decoration: InputDecoration(
                labelText: 'Selecciona el nivel',
                labelStyle: TextStyle(color: colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              style: TextStyle(color: colors.textPrimary),
              items: [
                DropdownMenuItem(
                  value: 'Fácil',
                  child: Text('Fácil', style: TextStyle(color: colors.textPrimary)),
                ),
                DropdownMenuItem(
                  value: 'Medio',
                  child: Text('Medio', style: TextStyle(color: colors.textPrimary)),
                ),
                DropdownMenuItem(
                  value: 'Difícil',
                  child: Text('Difícil', style: TextStyle(color: colors.textPrimary)),
                ),
              ],
              onChanged: (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _level == null ? null : _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryButton,
                foregroundColor: colors.primaryButtonText,
              ),
              child: const Text('Iniciar juego'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameUI(BuildContext context) {
    final colors = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = _gridSize;
        const spacing = 8.0;
        final totalSpacing = spacing * (crossCount + 1);
        final availableWidth = constraints.maxWidth - totalSpacing;
        final cardSize = availableWidth / crossCount;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Movimientos: $_moves',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Pares: $_score',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTime(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (_, i) {
                    final isUp = _revealed[i];
                    final icon = _icons[_cards[i] % _icons.length];

                    return SizedBox.square(
                      dimension: cardSize,
                      child: InkWell(
                        onTap: () => _onCardTap(i),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isUp
                                ? colors.primaryButton.withValues(alpha: 0.90)
                                : (context.isDark
                                    ? colors.inputFill
                                    : colors.chipBackground),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUp ? colors.secondaryButton : colors.border,
                              width: 2,
                            ),
                            boxShadow: context.isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: colors.textPrimary.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isUp ? 1 : 0,
                              child: Icon(
                                icon,
                                size: cardSize * 0.45,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _resetGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.secondaryButton,
                      foregroundColor: colors.secondaryButtonText,
                      minimumSize: const Size(140, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: context.isDark ? 0 : 3,
                    ),
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
                    onPressed: _pauseGame,
                    icon: Icon(
                      Icons.pause,
                      color: colors.emergencyText,
                    ),
                    label: const Text('Pausa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.emergency,
                      foregroundColor: colors.emergencyText,
                      minimumSize: const Size(140, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: context.isDark ? 0 : 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTime() {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}





