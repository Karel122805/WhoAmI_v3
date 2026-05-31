import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:whoami_app/src/core/theme/app_theme.dart';

class QuickGuidesPage extends StatefulWidget {
  const QuickGuidesPage({super.key});

  static const route = '/quick-guides';

  @override
  State<QuickGuidesPage> createState() => _QuickGuidesPageState();
}

class _QuickGuidesPageState extends State<QuickGuidesPage> {
  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  bool _showCategoryMenu = true;

  final Map<String, List<String>> _guidesByCategory = {
    'Emergencia': [
      'Mantén la calma y acompaña al paciente en todo momento.',
      'Si se desorienta, llévalo a un lugar seguro y familiar.',
      'Verifica signos vitales si hay caída.',
      'Evita mover al paciente si siente dolor intenso.',
      'Llama a emergencias si presenta cambios bruscos de conducta.',
      'Asegura que tenga identificación siempre consigo.',
      'Busca un lugar tranquilo para evitar sobreestimulación.',
      'Llama a un familiar si la situación se complica.',
      'Revisa si tomó sus medicamentos correctamente.',
      'Mantente atento a signos de deshidratación o fiebre.',
    ],
    'Rutina': [
      'Establece horarios fijos para levantarse y dormir.',
      'Organiza la ropa un día antes.',
      'Divide actividades en pasos sencillos.',
      'Incluye pausas para evitar cansancio.',
      'Usa recordatorios visuales en casa.',
      'Mantén rutinas constantes para generar seguridad.',
      'Evita cambios bruscos de última hora.',
      'Realiza actividades tranquilas antes de dormir.',
      'Ordena el entorno para reducir estrés.',
      'Permite que participe en tareas simples.',
    ],
    'Comunicación': [
      'Habla despacio y usa frases cortas.',
      'Haz contacto visual siempre.',
      'Haz preguntas simples de sí/no.',
      'Usa gestos o imágenes como apoyo.',
      'Evita discusiones o correcciones duras.',
      'Dale tiempo para responder.',
      'Evita hablar rápido.',
      'Refuerza con gestos calmados.',
      'Escucha sin interrumpir.',
      'Valida sus emociones cuando esté confundido.',
    ],
    'Seguridad': [
      'Retira alfombras que puedan causar caídas.',
      'Asegura puertas y ventanas.',
      'Coloca iluminación nocturna.',
      'Guarda objetos peligrosos fuera de alcance.',
      'Evita pisos mojados.',
      'Coloca barandales en lugares clave.',
      'Mantén productos tóxicos bajo llave.',
      'Evita cables sueltos.',
      'Supervisa al usar la cocina.',
      'Usa calzado seguro y cómodo.',
    ],
    'Medicina': [
      'Usa un pastillero semanal para organizar medicamentos.',
      'Configura alarmas para recordar horarios.',
      'No cambies dosis sin consultar al médico.',
      'Registra efectos secundarios inusuales.',
      'Verifica que no falte ninguna dosis.',
      'Guarda medicamentos fuera del alcance.',
      'Acompáñalo mientras los toma.',
      'Ten la receta médica a la mano.',
      'Revisa fechas de caducidad.',
      'No mezcles medicamentos sin supervisión.',
    ],
  };

  late final Map<String, IconData> _catIcon = {
    'Emergencia': Icons.warning_rounded,
    'Rutina': Icons.bedtime_rounded,
    'Comunicación': Icons.chat_rounded,
    'Seguridad': Icons.shield_rounded,
    'Medicina': Icons.medical_services_rounded,
  };

  late final List<String> _categories;

  String _selected = 'Emergencia';
  List<String> _visible = [];

  @override
  void initState() {
    super.initState();
    _categories = [..._guidesByCategory.keys];
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('es-MX');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    await _stopTts();
    await _tts.speak(text);
  }

  Future<void> _loadCategory(String category) async {
    await _stopTts();

    final shuffled =
        List<String>.from(_guidesByCategory[category]!)..shuffle(_rnd);

    if (!mounted) return;

    setState(() {
      _selected = category;
      _visible = shuffled;
      _showCategoryMenu = false;
    });
  }

  Future<void> _backToMenu() async {
    await _stopTts();

    if (!mounted) return;

    setState(() {
      _showCategoryMenu = true;
      _visible = [];
    });
  }

  Future<void> _handleBack() async {
    if (!_showCategoryMenu) {
      await _backToMenu();
      return;
    }

    await _stopTts();

    if (!mounted) return;

    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _stopTts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopScope(
      canPop: _showCategoryMenu,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _stopTts();
          return;
        }

        if (!_showCategoryMenu) {
          await _backToMenu();
        }
      },
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        appBar: AppBar(
          title: Text(_showCategoryMenu ? 'Guías' : _selected),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: _showCategoryMenu ? _buildCategoryMenu() : _buildGuidesView(),
      ),
    );
  }

  Widget _buildCategoryMenu() {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: _categories.map((category) {
          return _CategoryCard(
            title: category,
            icon: _catIcon[category]!,
            color: _themeCategoryColor(category),
            textColor: colors.textPrimary,
            onTap: () => _loadCategory(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGuidesView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _visible.length,
              itemBuilder: (_, i) {
                final text = _visible[i];

                return _GuideCard(
                  text: text,
                  color: _themeCategoryColor(_selected),
                  icon: _catIcon[_selected]!,
                  onTap: () => _speak(text),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.appColors.secondaryButton,
                foregroundColor: context.appColors.secondaryButtonText,
              ),
              onPressed: _backToMenu,
              child: const Text('Volver al menú'),
            ),
          ),
        ],
      ),
    );
  }

  Color _themeCategoryColor(String category) {
    final colors = context.appColors;

    switch (category) {
      case 'Emergencia':
        return colors.categoryYellow;
      case 'Rutina':
        return colors.categoryGreen;
      case 'Comunicación':
        return colors.categoryBlue;
      case 'Seguridad':
        return colors.categoryPurple;
      case 'Medicina':
        return colors.categoryPink;
      default:
        return colors.categoryBlue;
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadowColor = context.isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.black.withValues(alpha: 0.22);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 4),
              color: shadowColor,
            ),
          ],
          border: Border.all(
            color: context.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: textColor,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.text,
    required this.onTap,
    required this.color,
    required this.icon,
  });

  final String text;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: colors.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.volume_up,
              color: colors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}