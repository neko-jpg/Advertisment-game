/// Models for the onboarding system
library;

import 'dart:ui' show Offset;

/// Represents the current state of the onboarding process
enum OnboardingState {
  notStarted,
  tutorial,
  firstPlay,
  completed,
  skipped,
}

/// Tutorial step types
enum TutorialStep {
  welcome,
  tapToJump,
  drawPlatform,
  collectCoin,
  avoidObstacle,
  completed,
}

/// User interaction patterns during onboarding
class OnboardingInteraction {
  const OnboardingInteraction({
    required this.timestamp,
    required this.action,
    required this.step,
    this.duration,
    this.success = false,
  });

  final DateTime timestamp;
  final String action;
  final TutorialStep step;
  final Duration? duration;
  final bool success;
}

/// Progress tracking for onboarding
class OnboardingProgress {
  const OnboardingProgress({
    required this.currentStep,
    required this.startTime,
    this.completedSteps = const [],
    this.interactions = const [],
    this.needsHelp = false,
    this.skipRequested = false,
  });

  final TutorialStep currentStep;
  final DateTime startTime;
  final List<TutorialStep> completedSteps;
  final List<OnboardingInteraction> interactions;
  final bool needsHelp;
  final bool skipRequested;

  /// Calculate elapsed time since onboarding started
  Duration get elapsedTime => DateTime.now().difference(startTime);

  /// Check if user is taking too long on current step
  bool get isStuck => elapsedTime.inSeconds > 10 && interactions.length < 2;

  /// Check if user completed step successfully
  bool isStepCompleted(TutorialStep step) => completedSteps.contains(step);

  /// Create a copy with updated values
  OnboardingProgress copyWith({
    TutorialStep? currentStep,
    DateTime? startTime,
    List<TutorialStep>? completedSteps,
    List<OnboardingInteraction>? interactions,
    bool? needsHelp,
    bool? skipRequested,
  }) {
    return OnboardingProgress(
      currentStep: currentStep ?? this.currentStep,
      startTime: startTime ?? this.startTime,
      completedSteps: completedSteps ?? this.completedSteps,
      interactions: interactions ?? this.interactions,
      needsHelp: needsHelp ?? this.needsHelp,
      skipRequested: skipRequested ?? this.skipRequested,
    );
  }
}

/// Visual guide configuration
class VisualGuide {
  const VisualGuide({
    required this.type,
    required this.position,
    required this.message,
    this.duration = const Duration(seconds: 3),
    this.useHaptic = true,
    this.animated = true,
  });

  final GuideType type;
  final Offset position;
  final String message;
  final Duration duration;
  final bool useHaptic;
  final bool animated;
}

/// Types of visual guides
enum GuideType {
  tap,
  hold,
  swipe,
  draw,
  highlight,
}

/// Motivation message configuration
class MotivationMessage {
  const MotivationMessage({
    required this.title,
    required this.message,
    required this.type,
    this.actionText,
    this.reward,
  });

  final String title;
  final String message;
  final MotivationType type;
  final String? actionText;
  final int? reward;
}

/// Types of motivation messages
enum MotivationType {
  encouragement,
  progress,
  reward,
  comeback,
  achievement,
}

/// User onboarding preferences
class OnboardingPreferences {
  const OnboardingPreferences({
    this.skipTutorial = false,
    this.reducedAnimations = false,
    this.hapticFeedback = true,
    this.autoHelp = true,
  });

  final bool skipTutorial;
  final bool reducedAnimations;
  final bool hapticFeedback;
  final bool autoHelp;

  OnboardingPreferences copyWith({
    bool? skipTutorial,
    bool? reducedAnimations,
    bool? hapticFeedback,
    bool? autoHelp,
  }) {
    return OnboardingPreferences(
      skipTutorial: skipTutorial ?? this.skipTutorial,
      reducedAnimations: reducedAnimations ?? this.reducedAnimations,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      autoHelp: autoHelp ?? this.autoHelp,
    );
  }
}