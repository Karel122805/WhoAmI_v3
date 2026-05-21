import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../theme.dart';
import 'brain_says_page.dart';
import 'memorama_page.dart';

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
    _configureTts();
  }

  Future<void> _configureTts() async {
    await tts.setLanguage('es-MX');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
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

  Future<void> _stopTTS() async {
    await tts.stop();
  }

  Future<void> _showGameHelpDialog({
    required String title,
    required String description,
    required String audioText,
    required IconData icon,
  }) async {
    final colors = context.appColors;

    await _speak(audioText);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.elevatedCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.secondaryButton,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: colors.secondaryButtonText,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.isDark
                ? colors.inputFill.withValues(alpha: 0.45)
                : colors.inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            description,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.secondaryButton,
                    foregroundColor: colors.secondaryButtonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () => _speak(audioText),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text(
                    'Repetir audio',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primaryButton,
                    foregroundColor: colors.primaryButtonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () async {
                    await _stopTTS();
                    if (!mounted) return;
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sequenceIcon(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.34),
        shape: BoxShape.circle,
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.58),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.18 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.touch_app_rounded,
            size: 34,
            color: Colors.black,
          ),
          Positioned(
            top: 12,
            child: Icon(
              Icons.circle,
              size: 14,
              color: colors.emergency,
            ),
          ),
          Positioned(
            right: 12,
            child: Icon(
              Icons.circle,
              size: 14,
              color: colors.categoryBlue,
            ),
          ),
          Positioned(
            bottom: 12,
            child: Icon(
              Icons.circle,
              size: 14,
              color: colors.categoryGreen,
            ),
          ),
          Positioned(
            left: 12,
            child: Icon(
              Icons.circle,
              size: 14,
              color: colors.categoryPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memoramaIcon(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.34),
        shape: BoxShape.circle,
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.58),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.18 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: 22,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 34,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.categoryYellow.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 22,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                width: 34,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.categoryBlue.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Icon(
            Icons.extension_rounded,
            size: 38,
            color: context.isDark ? Colors.white : colors.categoryPurple,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton({
    required BuildContext context,
    required VoidCallback onPressed,
  }) {
    final colors = context.appColors;

    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.categoryGreen,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text(
        'Jugar',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildHelpButton({
    required BuildContext context,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: context.isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.40),
              width: 1.2,
            ),
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            color: Colors.black,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _gameCard({
    required BuildContext context,
    required Color backgroundColor,
    required Widget icon,
    required String title,
    required String subtitle,
    required bool useDarkText,
    required VoidCallback onHelp,
    required VoidCallback onOpen,
  }) {
    final colors = context.appColors;
    final titleColor = useDarkText ? colors.textPrimary : Colors.white;
    final subtitleColor = useDarkText
        ? colors.textPrimary.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onOpen,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: context.isDark
                    ? colors.border.withValues(alpha: 0.95)
                    : colors.border.withValues(alpha: 0.72),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.isDark
                      ? Colors.black.withValues(alpha: 0.24)
                      : colors.textPrimary.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPlayButton(
                              context: context,
                              onPressed: onOpen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildHelpButton(
                            context: context,
                            onPressed: onHelp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final memoramaCardColor = context.isDark
        ? colors.categoryPurple.withValues(alpha: 0.86)
        : colors.categoryPurple.withValues(alpha: 0.86);

    final sequenceCardColor = context.isDark
        ? colors.categoryYellow.withValues(alpha: 0.84)
        : colors.categoryYellow.withValues(alpha: 0.94);

    const memoramaHelpText =
        'En este juego debes voltear tarjetas y encontrar las parejas iguales. Memoriza la posición de cada tarjeta y trata de hacer la menor cantidad de intentos.';

    const sequenceHelpText =
        'En este juego debes observar una secuencia de colores y repetirla en el mismo orden. Cada ronda se vuelve más larga y desafiante.';

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        toolbarHeight: 56,
        centerTitle: true,
        title: Text(
          'Juegos',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () async {
            await _stopTTS();
            if (!mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Entrena tu memoria y atención con actividades simples y entretenidas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: context.isDark
                          ? colors.textPrimary.withValues(alpha: 0.82)
                          : colors.textPrimary.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _gameCard(
                    context: context,
                    backgroundColor: memoramaCardColor,
                    icon: _memoramaIcon(context),
                    title: 'Memorama',
                    subtitle:
                        'Encuentra las parejas iguales y fortalece tu atención.',
                    useDarkText: false,
                    onHelp: () => _showGameHelpDialog(
                      title: 'Memorama',
                      description:
                          'Encuentra las parejas iguales volteando tarjetas. Debes recordar dónde viste cada imagen para completar el tablero con menos intentos.',
                      audioText: memoramaHelpText,
                      icon: Icons.extension_rounded,
                    ),
                    onOpen: () async {
                      await _stopTTS();
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MemoramaPage(),
                          maintainState: false,
                        ),
                      );
                    },
                  ),
                  _gameCard(
                    context: context,
                    backgroundColor: sequenceCardColor,
                    icon: _sequenceIcon(context),
                    title: 'Secuencia',
                    subtitle:
                        'Observa el orden de colores y repítelo correctamente.',
                    useDarkText: true,
                    onHelp: () => _showGameHelpDialog(
                      title: 'Secuencia',
                      description:
                          'Observa el orden en que se iluminan o muestran los colores y repítelo correctamente. Cada nivel agrega un paso más y pone a prueba tu memoria y atención.',
                      audioText: sequenceHelpText,
                      icon: Icons.touch_app_rounded,
                    ),
                    onOpen: () async {
                      await _stopTTS();
                      if (!mounted) return;
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