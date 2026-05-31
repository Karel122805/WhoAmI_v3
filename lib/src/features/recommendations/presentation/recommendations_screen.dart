import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

import '../data/recommendations_data.dart';
import '../models/recommendation_model.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final FlutterTts _tts = FlutterTts();
  final Random _rnd = Random();

  bool _showCategoryMenu = true;
  RecommendationModel? _selectedRecommendation;
  List<String> _visibleRecommendations = [];

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

  Future<void> _openCategory(RecommendationModel recommendation) async {
    await _stopTts();

    final shuffled = List<String>.from(recommendation.recommendations)
      ..shuffle(_rnd);

    if (!mounted) return;

    setState(() {
      _selectedRecommendation = recommendation;
      _visibleRecommendations = shuffled;
      _showCategoryMenu = false;
    });
  }

  Future<void> _backToMenu() async {
    await _stopTts();

    if (!mounted) return;

    setState(() {
      _showCategoryMenu = true;
      _selectedRecommendation = null;
      _visibleRecommendations = [];
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
          title: Text(_showCategoryMenu
              ? 'Recomendaciones'
              : _selectedRecommendation?.title ?? 'Recomendaciones'),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: _showCategoryMenu ? _buildCategoryMenu() : _buildRecommendationsView(),
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
        children: caregiverRecommendations.map((recommendation) {
          return _CategoryCard(
            recommendation: recommendation,
            color: _themeCategoryColor(recommendation),
            textColor: colors.textPrimary,
            onTap: () => _openCategory(recommendation),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendationsView() {
    final selected = _selectedRecommendation;
    if (selected == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _visibleRecommendations.length,
              itemBuilder: (_, i) {
                final text = _visibleRecommendations[i];

                return _RecommendationCard(
                  text: text,
                  color: _themeCategoryColor(selected),
                  icon: selected.icon,
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

  Color _themeCategoryColor(RecommendationModel item) {
    final colors = context.appColors;

    switch (item.title) {
      case 'Salud física':
        return colors.categoryYellow;
      case 'Salud mental':
        return colors.categoryPink;
      case 'Memoria':
        return colors.categoryBlue;
      case 'Rutina y sueño':
        return colors.categoryGreen;
      case 'Seguridad':
        return colors.categoryPurple;
      default:
        return item.color;
    }
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.recommendation,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final RecommendationModel recommendation;
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
                recommendation.icon,
                size: 48,
                color: textColor,
              ),
              const SizedBox(height: 10),
              Text(
                recommendation.title,
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

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
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