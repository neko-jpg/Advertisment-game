import 'package:flutter_test/flutter_test.dart';

import '../../lib/onboarding/models/onboarding_models.dart';

void main() {
  group('Onboarding Models', () {
    test('OnboardingProgress should calculate elapsed time correctly', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 30));
      final progress = OnboardingProgress(
        currentStep: TutorialStep.welcome,
        startTime: startTime,
      );

      expect(progress.elapsedTime.inSeconds, greaterThanOrEqualTo(29));
      expect(progress.elapsedTime.inSeconds, lessThanOrEqualTo(31));
    });

    test('OnboardingProgress should detect stuck users', () {
      final oldStartTime = DateTime.now().subtract(const Duration(seconds: 15));
      final progress = OnboardingProgress(
        currentStep: TutorialStep.tapToJump,
        startTime: oldStartTime,
        interactions: [], // No interactions
      );

      expect(progress.isStuck, true);
    });

    test('OnboardingProgress should not detect stuck users with recent interactions', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 15));
      final progress = OnboardingProgress(
        currentStep: TutorialStep.tapToJump,
        startTime: startTime,
        interactions: [
          OnboardingInteraction(
            timestamp: DateTime.now().subtract(const Duration(seconds: 5)),
            action: 'jump',
            step: TutorialStep.tapToJump,
            success: true,
          ),
          OnboardingInteraction(
            timestamp: DateTime.now().subtract(const Duration(seconds: 3)),
            action: 'jump',
            step: TutorialStep.tapToJump,
            success: false,
          ),
        ],
      );

      expect(progress.isStuck, false);
    });

    test('OnboardingProgress should track completed steps', () {
      final progress = OnboardingProgress(
        currentStep: TutorialStep.drawPlatform,
        startTime: DateTime.now(),
        completedSteps: [TutorialStep.welcome, TutorialStep.tapToJump],
      );

      expect(progress.isStepCompleted(TutorialStep.welcome), true);
      expect(progress.isStepCompleted(TutorialStep.tapToJump), true);
      expect(progress.isStepCompleted(TutorialStep.drawPlatform), false);
    });

    test('OnboardingProgress copyWith should work correctly', () {
      final original = OnboardingProgress(
        currentStep: TutorialStep.welcome,
        startTime: DateTime.now(),
        needsHelp: false,
      );

      final updated = original.copyWith(
        currentStep: TutorialStep.tapToJump,
        needsHelp: true,
      );

      expect(updated.currentStep, TutorialStep.tapToJump);
      expect(updated.needsHelp, true);
      expect(updated.startTime, original.startTime); // Should remain unchanged
    });
  });

  group('VisualGuide', () {
    test('should create visual guide with correct properties', () {
      const guide = VisualGuide(
        type: GuideType.tap,
        position: Offset(100, 200),
        message: 'Tap here!',
        duration: Duration(seconds: 5),
        useHaptic: true,
        animated: true,
      );

      expect(guide.type, GuideType.tap);
      expect(guide.position, const Offset(100, 200));
      expect(guide.message, 'Tap here!');
      expect(guide.duration, const Duration(seconds: 5));
      expect(guide.useHaptic, true);
      expect(guide.animated, true);
    });
  });

  group('MotivationMessage', () {
    test('should create motivation message with reward', () {
      const message = MotivationMessage(
        title: 'Great Job!',
        message: 'You earned a reward!',
        type: MotivationType.reward,
        actionText: 'Claim',
        reward: 100,
      );

      expect(message.title, 'Great Job!');
      expect(message.message, 'You earned a reward!');
      expect(message.type, MotivationType.reward);
      expect(message.actionText, 'Claim');
      expect(message.reward, 100);
    });

    test('should create motivation message without reward', () {
      const message = MotivationMessage(
        title: 'Keep Going!',
        message: 'You can do it!',
        type: MotivationType.encouragement,
      );

      expect(message.title, 'Keep Going!');
      expect(message.message, 'You can do it!');
      expect(message.type, MotivationType.encouragement);
      expect(message.actionText, null);
      expect(message.reward, null);
    });
  });

  group('OnboardingPreferences', () {
    test('should create preferences with default values', () {
      const preferences = OnboardingPreferences();

      expect(preferences.skipTutorial, false);
      expect(preferences.reducedAnimations, false);
      expect(preferences.hapticFeedback, true);
      expect(preferences.autoHelp, true);
    });

    test('should create preferences with custom values', () {
      const preferences = OnboardingPreferences(
        skipTutorial: true,
        reducedAnimations: true,
        hapticFeedback: false,
        autoHelp: false,
      );

      expect(preferences.skipTutorial, true);
      expect(preferences.reducedAnimations, true);
      expect(preferences.hapticFeedback, false);
      expect(preferences.autoHelp, false);
    });

    test('copyWith should work correctly', () {
      const original = OnboardingPreferences(
        skipTutorial: false,
        hapticFeedback: true,
      );

      final updated = original.copyWith(
        skipTutorial: true,
        reducedAnimations: true,
      );

      expect(updated.skipTutorial, true);
      expect(updated.reducedAnimations, true);
      expect(updated.hapticFeedback, true); // Should remain unchanged
      expect(updated.autoHelp, true); // Should remain unchanged
    });
  });

  group('OnboardingInteraction', () {
    test('should create interaction with all properties', () {
      final timestamp = DateTime.now();
      final interaction = OnboardingInteraction(
        timestamp: timestamp,
        action: 'jump',
        step: TutorialStep.tapToJump,
        duration: const Duration(milliseconds: 500),
        success: true,
      );

      expect(interaction.timestamp, timestamp);
      expect(interaction.action, 'jump');
      expect(interaction.step, TutorialStep.tapToJump);
      expect(interaction.duration, const Duration(milliseconds: 500));
      expect(interaction.success, true);
    });

    test('should create interaction with minimal properties', () {
      final timestamp = DateTime.now();
      final interaction = OnboardingInteraction(
        timestamp: timestamp,
        action: 'draw',
        step: TutorialStep.drawPlatform,
      );

      expect(interaction.timestamp, timestamp);
      expect(interaction.action, 'draw');
      expect(interaction.step, TutorialStep.drawPlatform);
      expect(interaction.duration, null);
      expect(interaction.success, false); // Default value
    });
  });
}