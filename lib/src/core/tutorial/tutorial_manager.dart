// lib/src/core/tutorial/tutorial_manager.dart

import 'package:flutter/material.dart';

import 'tutorial_keys.dart';
import 'tutorial_messages.dart';
import 'tutorial_overlay.dart';
import 'tutorial_service.dart';

class TutorialManager {
  const TutorialManager._();

  static bool _isOpeningTutorial = false;

  static Future<void> maybeShowCaregiverHome(
    BuildContext context,
  ) async {
    if (_isOpeningTutorial) {
      return;
    }

    final hasSeen =
        await TutorialService.hasSeenCaregiverHome();

    if (hasSeen || !context.mounted) {
      return;
    }

    final steps = TutorialMessages.caregiverHomeSteps();

    await _showTutorial(
      context: context,
      steps: steps,
      onComplete: TutorialService.markCaregiverHomeSeen,
    );
  }

  static Future<void> maybeShowConsultantHome(
    BuildContext context,
  ) async {
    if (_isOpeningTutorial) {
      return;
    }

    final hasSeen =
        await TutorialService.hasSeenConsultantHome();

    if (hasSeen || !context.mounted) {
      return;
    }

    final steps = TutorialMessages.consultantHomeSteps();

    await _showTutorial(
      context: context,
      steps: steps,
      onComplete: TutorialService.markConsultantHomeSeen,
    );
  }

  static Future<void> showCaregiverHomeAgain(
    BuildContext context,
  ) async {
    if (_isOpeningTutorial) {
      return;
    }

    await _showTutorial(
      context: context,
      steps: TutorialMessages.caregiverHomeSteps(),
      onComplete: () async {},
    );
  }

  static Future<void> showConsultantHomeAgain(
    BuildContext context,
  ) async {
    if (_isOpeningTutorial) {
      return;
    }

    await _showTutorial(
      context: context,
      steps: TutorialMessages.consultantHomeSteps(),
      onComplete: () async {},
    );
  }

  static Future<void> maybeShow(
    BuildContext context,
    TutorialKey key,
  ) async {
    if (_isOpeningTutorial) {
      return;
    }

    final tutorialName = key.name;
    final hasSeen = await TutorialService.hasSeen(
      tutorialName,
    );

    if (hasSeen || !context.mounted) {
      return;
    }

    await _showTutorial(
      context: context,
      steps: <TutorialKey>[key],
      onComplete: () {
        return TutorialService.markSeen(
          tutorialName,
        );
      },
    );
  }

  static Future<void> showAgain(
    BuildContext context,
    TutorialKey key,
  ) async {
    if (_isOpeningTutorial) {
      return;
    }

    await _showTutorial(
      context: context,
      steps: <TutorialKey>[key],
      onComplete: () async {},
    );
  }

  static Future<void> _showTutorial({
    required BuildContext context,
    required List<TutorialKey> steps,
    required Future<void> Function() onComplete,
  }) async {
    if (_isOpeningTutorial ||
        steps.isEmpty ||
        !context.mounted) {
      return;
    }

    _isOpeningTutorial = true;

    try {
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      if (!context.mounted) {
        return;
      }

      final messages = steps
          .map(TutorialMessages.getMessage)
          .toList(growable: false);

      TutorialOverlay.show(
        context: context,
        messages: messages,
        onClose: () async {
          try {
            await onComplete();
          } finally {
            _isOpeningTutorial = false;
          }
        },
      );
    } catch (_) {
      _isOpeningTutorial = false;
      rethrow;
    }
  }

  static void closeCurrentTutorial() {
    TutorialOverlay.hide();
    _isOpeningTutorial = false;
  }
}