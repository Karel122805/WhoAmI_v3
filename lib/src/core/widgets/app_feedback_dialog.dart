import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum FeedbackDialogType {
  success,
  error,
  warning,
  info,
}

class AppFeedbackDialog extends StatelessWidget {
  final FeedbackDialogType type;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onPressed;

  const AppFeedbackDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.buttonText = 'Aceptar',
    this.onPressed,
  });

  IconData get _icon {
    switch (type) {
      case FeedbackDialogType.success:
        return Icons.check_circle_outline_rounded;

      case FeedbackDialogType.error:
        return Icons.cancel_outlined;

      case FeedbackDialogType.warning:
        return Icons.warning_amber_rounded;

      case FeedbackDialogType.info:
        return Icons.info_outline_rounded;
    }
  }

  Color _iconColor(AppColors colors) {
    switch (type) {
      case FeedbackDialogType.success:
        return colors.categoryGreen;

      case FeedbackDialogType.error:
        return colors.emergency;

      case FeedbackDialogType.warning:
        return Colors.orange;

      case FeedbackDialogType.info:
        return colors.primaryButton;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 28,
        vertical: 24,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: _iconColor(colors).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 42,
                color: _iconColor(colors),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryButton,
                  foregroundColor: colors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: onPressed ??
                    () {
                      Navigator.pop(context);
                    },
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}