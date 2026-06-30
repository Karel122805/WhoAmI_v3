import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/games/data/memorama_progress_service.dart';

class MemoramaPage extends StatefulWidget {
  const MemoramaPage({super.key});
  static const route = '/games/memorama';

  @override
  State<MemoramaPage> createState() => _MemoramaPageState();
}

class _MemoramaPageState extends State<MemoramaPage>
    with TickerProviderStateMixin {
  final MemoramaProgressService _progressService = MemoramaProgressService();
  final Random _random = Random();

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

  final List<Color> _pairColors = const [
    Color(0xFFE57373),
    Color(0xFFFFD54F),
    Color(0xFF81C784),
    Color(0xFFA1887F),
    Color(0xFFFF8A65),
    Color(0xFFBA68C8),
    Color(0xFF64B5F6),
    Color(0xFF4DD0E1),
    Color(0xFFF48FB1),
    Color(0xFFFFB74D),
    Color(0xFF90A4AE),
    Color(0xFFAED581),
  ];

  late List<int> _cards;
  late List<bool> _revealed;
  late List<bool> _matched;

  int? _firstIndex;

  bool _waiting = false;
  bool _started = false;
  bool _paused = false;
  bool _loadingLevel = true;

  int _moves = 0;
  int _seconds = 0;
  int _score = 0;

  int _unlockedLevel = 1;
  int _selectedLevel = 1;

  Timer? _timer;

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

    _loadUnlockedLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnlockedLevel() async {
    final level = await _progressService.getUnlockedLevel();

    if (!mounted) return;

    setState(() {
      _unlockedLevel = level;
      _selectedLevel = level;
      _loadingLevel = false;
    });
  }

  String get _levelName => 'Nivel $_selectedLevel';

  double get _progressValue {
    return _unlockedLevel / MemoramaProgressService.maxLevel;
  }

  int get _gridSize {
    switch (_selectedLevel) {
      case 2:
        return 4;
      case 3:
        return 4;
      default:
        return 3;
    }
  }

  int get _pairCount {
    switch (_selectedLevel) {
      case 2:
        return 8;
      case 3:
        return 12;
      default:
        return 4;
    }
  }

  Color _pairColor(int cardValue) {
    return _pairColors[cardValue % _pairColors.length];
  }

  void _startGame() {
    final base = List.generate(_pairCount, (i) => i);
    _cards = [...base, ...base]..shuffle(_random);
    _revealed = List<bool>.filled(_cards.length, false);
    _matched = List<bool>.filled(_cards.length, false);

    _firstIndex = null;
    _waiting = false;
    _moves = 0;
    _seconds = 0;
    _score = 0;
    _paused = false;
    _started = true;

    _showLevelBanner('¡Vamos! Encuentra las parejas del mismo color.');
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

  Future<void> _onCardTap(int index) async {
    if (!_started ||
        _paused ||
        _waiting ||
        _revealed[index] ||
        _matched[index]) {
      return;
    }

    setState(() => _revealed[index] = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    _moves++;

    if (_cards[_firstIndex!] != _cards[index]) {
      _waiting = true;

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      setState(() {
        _revealed[_firstIndex!] = false;
        _revealed[index] = false;
      });

      _waiting = false;
    } else {
      setState(() {
        _matched[_firstIndex!] = true;
        _matched[index] = true;
        _score++;
      });

      _showLevelBanner('¡Encontraste una pareja!');
    }

    _firstIndex = null;

    if (_matched.every((r) => r)) {
      _timer?.cancel();

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await _showWinDialog();
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _showWinDialog() async {
    final colors = context.appColors;
    _confettiCtrl.play();

    final oldUnlocked = _unlockedLevel;
    final newUnlocked = await _progressService.unlockNextLevel(_selectedLevel);

    if (!mounted) return;

    setState(() {
      _unlockedLevel = newUnlocked;
    });

    final bool unlockedNewLevel = newUnlocked > oldUnlocked;
    final bool hasNextLevel =
        _selectedLevel < MemoramaProgressService.maxLevel &&
            newUnlocked > _selectedLevel;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          unlockedNewLevel
              ? '¡Nuevo nivel desbloqueado!'
              : '¡Excelente trabajo!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          unlockedNewLevel
              ? 'Completaste $_levelName. Ahora puedes avanzar al Nivel $newUnlocked.'
              : 'Cada partida ayuda a fortalecer tu memoria.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textPrimary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confettiCtrl.stop();
              _resetGame();
            },
            style: TextButton.styleFrom(
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
            ),
            child: const Text('Jugar de nuevo'),
          ),
          if (hasNextLevel)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confettiCtrl.stop();
                setState(() => _selectedLevel = newUnlocked);
                _startGame();
              },
              style: TextButton.styleFrom(
                backgroundColor: colors.primaryButton,
                foregroundColor: colors.primaryButtonText,
              ),
              child: const Text('Siguiente nivel'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confettiCtrl.stop();
              setState(() => _started = false);
            },
            child: Text(
              'Volver al inicio',
              style: TextStyle(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLevelBanner(String text) async {
    if (!mounted) return;

    _bannerCtrl.stop();
    _bannerCtrl.reset();

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

  Color _cardBackgroundColor({
    required int cardValue,
    required bool isUp,
    required bool isMatched,
  }) {
    final colors = context.appColors;
    final pairColor = _pairColor(cardValue);

    if (isUp || isMatched) {
      return context.isDark
          ? pairColor.withOpacity(0.45)
          : pairColor.withOpacity(0.30);
    }

    return context.isDark ? colors.inputFill : colors.chipBackground;
  }

  Color _cardBorderColor({
    required int cardValue,
    required bool isUp,
    required bool isMatched,
  }) {
    final colors = context.appColors;
    final pairColor = _pairColor(cardValue);

    if (isUp || isMatched) {
      return pairColor;
    }

    return colors.border;
  }

  Color _cardIconColor({
    required int cardValue,
    required bool isUp,
    required bool isMatched,
  }) {
    final colors = context.appColors;
    final pairColor = _pairColor(cardValue);

    if (isUp || isMatched) {
      return context.isDark ? colors.textPrimary : pairColor;
    }

    return colors.textSecondary;
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = context.appColors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: context.isDark ? colors.inputFill : colors.chipBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: colors.primaryButton),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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

  void _showPauseDialog() {
    final colors = context.appColors;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: colors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Juego en pausa',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tómate tu tiempo. Puedes continuar cuando estés listo.',
          style: TextStyle(color: colors.textPrimary),
        ),
        actionsAlignment: MainAxisAlignment.center,
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
              backgroundColor: colors.secondaryButton,
              foregroundColor: colors.secondaryButtonText,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Quieres salir del juego?',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Tu partida actual se cerrará, pero podrás intentarlo nuevamente cuando quieras.',
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
            child: const Text('Continuar jugando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: colors.emergency,
              foregroundColor: colors.emergencyText,
            ),
            child: const Text('Salir'),
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
            child: _loadingLevel
                ? Center(
                    child: CircularProgressIndicator(
                      color: colors.primaryButton,
                    ),
                  )
                : !_started
                    ? _buildMenuInicio(context)
                    : _buildGameUI(context),
          ),
          if (_showBanner)
            Positioned(
              top: 24,
              child: FadeTransition(
                opacity: _bannerOpacity,
                child: SlideTransition(
                  position: _bannerSlide,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 330),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      border: Border.all(color: colors.primaryButton, width: 2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _bannerText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            border: Border.all(color: colors.primaryButton, width: 2),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.extension_rounded,
                size: 60,
                color: colors.primaryButton,
              ),
              const SizedBox(height: 16),
              Text(
                'Entrena tu memoria',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 23,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Avanza poco a poco. Cada intento ayuda a ejercitar tu mente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Nivel actual',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nivel $_unlockedLevel',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  MemoramaProgressService.maxLevel,
                  (index) {
                    final level = index + 1;
                    final unlocked = level <= _unlockedLevel;
                    final selected = level == _selectedLevel;

                    return ChoiceChip(
                      selected: selected,
                      label: Text('Nivel $level'),
                      onSelected: unlocked
                          ? (_) => setState(() => _selectedLevel = level)
                          : null,
                      avatar: unlocked
                          ? Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: selected
                                  ? colors.primaryButtonText
                                  : colors.textPrimary,
                            )
                          : Icon(
                              Icons.lock_rounded,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                      selectedColor: colors.primaryButton,
                      backgroundColor: context.isDark
                          ? colors.inputFill
                          : colors.chipBackground,
                      disabledColor: context.isDark
                          ? colors.inputFill
                          : colors.chipBackground,
                      labelStyle: TextStyle(
                        color: selected
                            ? colors.primaryButtonText
                            : unlocked
                                ? colors.textPrimary
                                : colors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                      side: BorderSide(
                        color: selected ? colors.primaryButton : colors.border,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Jugar ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  foregroundColor: colors.primaryButtonText,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ],
          ),
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
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_alt_rounded,
                          color: colors.primaryButton,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _levelName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard(
                          icon: Icons.timer_outlined,
                          label: 'Tiempo',
                          value: _formatTime(),
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          icon: Icons.touch_app_outlined,
                          label: 'Movs.',
                          value: '$_moves',
                        ),
                        const SizedBox(width: 8),
                        _buildStatCard(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Pares',
                          value: '$_score/$_pairCount',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
                    final isMatched = _matched[i];
                    final cardValue = _cards[i];
                    final icon = _icons[cardValue % _icons.length];
                    final pairColor = _pairColor(cardValue);

                    return SizedBox.square(
                      dimension: cardSize,
                      child: InkWell(
                        onTap: () => _onCardTap(i),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 230),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: _cardBackgroundColor(
                              cardValue: cardValue,
                              isUp: isUp,
                              isMatched: isMatched,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _cardBorderColor(
                                cardValue: cardValue,
                                isUp: isUp,
                                isMatched: isMatched,
                              ),
                              width: isMatched ? 3 : (isUp ? 3 : 2),
                            ),
                            boxShadow: context.isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: isUp || isMatched
                                          ? pairColor.withOpacity(0.25)
                                          : colors.textPrimary
                                              .withOpacity(0.07),
                                      blurRadius:
                                          isMatched ? 16 : (isUp ? 12 : 8),
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 230),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: isUp || isMatched
                                  ? Icon(
                                      icon,
                                      key: ValueKey('icon_$i'),
                                      size: cardSize * 0.45,
                                      color: _cardIconColor(
                                        cardValue: cardValue,
                                        isUp: isUp,
                                        isMatched: isMatched,
                                      ),
                                    )
                                  : Icon(
                                      Icons.psychology_alt_outlined,
                                      key: ValueKey('back_$i'),
                                      size: cardSize * 0.34,
                                      color: colors.textSecondary,
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
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
                    ),
                    icon: Icon(Icons.refresh, color: colors.secondaryButtonText),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pauseGame,
                    icon: Icon(Icons.pause, color: colors.emergencyText),
                    label: const Text('Pausa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.emergency,
                      foregroundColor: colors.emergencyText,
                      minimumSize: const Size(140, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
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