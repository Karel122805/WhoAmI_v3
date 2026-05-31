import 'package:flutter/material.dart';

class RecommendationModel {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> recommendations;

  const RecommendationModel({
    required this.title,
    required this.icon,
    required this.color,
    required this.recommendations,
  });
}