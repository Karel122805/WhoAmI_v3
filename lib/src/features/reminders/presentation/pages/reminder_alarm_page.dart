import 'package:flutter/material.dart';

import 'package:whoami_app/src/core/theme/app_theme.dart';

class ReminderAlarmPage extends StatelessWidget {
  const ReminderAlarmPage({
    super.key,
    required this.title,
    this.description,
  });

  static const route = '/reminder-alarm';

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cleanDescription = description?.trim();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.pageBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 430),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colors.primaryButton.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.alarm_rounded,
                        size: 56,
                        color: colors.primaryButton,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Alarma de recordatorio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (cleanDescription != null &&
                        cleanDescription.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        cleanDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'Entendido',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}