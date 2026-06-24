import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

import '../models/preventive_info_model.dart';

class PreventiveInfoDetailScreen extends StatelessWidget {
  const PreventiveInfoDetailScreen({
    super.key,
    required this.item,
  });

  final PreventiveInfoModel item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: const Text('Detalle'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.elevatedCard,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor:
                        colors.primaryButton.withValues(alpha: 0.14),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      size: 46,
                      color: colors.primaryButton,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  item.category,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  item.content,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}