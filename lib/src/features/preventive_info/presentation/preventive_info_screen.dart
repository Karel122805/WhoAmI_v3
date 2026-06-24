import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

import '../data/preventive_info_data.dart';
import '../models/preventive_info_model.dart';

class PreventiveInfoScreen extends StatefulWidget {
  const PreventiveInfoScreen({super.key});

  static const route = '/preventive-info';

  @override
  State<PreventiveInfoScreen> createState() => _PreventiveInfoScreenState();
}

class _PreventiveInfoScreenState extends State<PreventiveInfoScreen> {
  final FlutterTts _tts = FlutterTts();

  bool _showCategoryMenu = true;
  String? _selectedCategory;
  List<PreventiveInfoModel> _visibleItems = [];

  @override
  void initState() {
    super.initState();
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

  Future<void> _openCategory(String category) async {
    await _stopTts();

    final items = preventiveInfoData
        .where((item) => item.active && item.category == category)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    if (!mounted) return;

    setState(() {
      _selectedCategory = category;
      _visibleItems = items;
      _showCategoryMenu = false;
    });
  }

  Future<void> _backToMenu() async {
    await _stopTts();

    if (!mounted) return;

    setState(() {
      _showCategoryMenu = true;
      _selectedCategory = null;
      _visibleItems = [];
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
          title: Text(
            _showCategoryMenu
                ? 'Información preventiva'
                : _selectedCategory ?? 'Información preventiva',
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: _showCategoryMenu ? _buildCategoryMenu() : _buildPreventiveList(),
      ),
    );
  }

  Widget _buildCategoryMenu() {
    final items = preventiveInfoData.where((item) => item.active).toList();
    final categories = items.map((e) => e.category).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: categories.map((category) {
          return _CategoryCard(
            title: category,
            icon: _categoryIcon(category),
            color: _categoryColor(category),
            onTap: () => _openCategory(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreventiveList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 70),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _visibleItems.length,
              itemBuilder: (_, index) {
                final item = _visibleItems[index];

                return _PreventiveSpeechCard(
                  item: item,
                  color: _categoryColor(item.category),
                  icon: _categoryIcon(item.category),
                  onTap: () => _speak(item.content),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.isDark
                    ? context.appColors.secondaryButton
                    : const Color(0xFFE7D4FF),
                foregroundColor: context.isDark
                    ? context.appColors.secondaryButtonText
                    : const Color(0xFF6B3FA0),
                shape: const StadiumBorder(),
                elevation: 4,
              ),
              onPressed: _backToMenu,
              child: const Text(
                'Volver al menú',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Memoria':
        return Icons.memory_rounded;
      case 'Sueño':
        return Icons.bedtime_rounded;
      case 'Alimentación':
        return Icons.restaurant_rounded;
      case 'Actividad física':
        return Icons.fitness_center_rounded;
      case 'Estrés':
        return Icons.self_improvement_rounded;
      case 'Hábitos saludables':
        return Icons.favorite_rounded;
      default:
        return Icons.health_and_safety_rounded;
    }
  }

  Color _categoryColor(String category) {
    if (context.isDark) {
      switch (category) {
        case 'Actividad física':
          return const Color(0xFF9A9052);
        case 'Alimentación':
          return const Color(0xFF5F9864);
        case 'Estrés':
          return const Color(0xFFA5626A);
        case 'Hábitos saludables':
          return const Color(0xFFA96F84);
        case 'Memoria':
          return const Color(0xFF5F86A8);
        case 'Sueño':
          return const Color(0xFF8D6BAD);
        default:
          return const Color(0xFF8D6BAD);
      }
    }

    switch (category) {
      case 'Actividad física':
        return const Color(0xFFFFF29A);
      case 'Alimentación':
        return const Color(0xFF9BE89A);
      case 'Estrés':
        return const Color(0xFFFF969D);
      case 'Hábitos saludables':
        return const Color(0xFFFFB3C7);
      case 'Memoria':
        return const Color(0xFF9FD2F7);
      case 'Sueño':
        return const Color(0xFFB98BE0);
      default:
        return const Color(0xFFB98BE0);
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = context.isDark ? Colors.white : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.26 : 0.18),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: textColor),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreventiveSpeechCard extends StatelessWidget {
  const _PreventiveSpeechCard({
    required this.item,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final PreventiveInfoModel item;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = context.isDark ? Colors.white : Colors.black;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.22 : 0.14),
              blurRadius: 7,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.volume_up_rounded,
              color: textColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}