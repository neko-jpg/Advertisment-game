/// Fast onboarding system that provides 15-second fun-first tutorial experience
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/onboarding_models.dart';
import '../core/analytics/analytics_service.dart';

/// Manages the fast onboarding experience with fun-first approach
class FastOnboardingSystem extends ChangeNotifier {
  FastOnboardingSystem({
    required AnalyticsService analytics,
  }) : _analytics = analytics;

  final AnalyticsService _analytics;
  
  OnboardingState _state = OnboardingState.notStarted;
  OnboardingProgress? _progress;
  OnboardingPreferences _preferences = const OnboardingPreferences();
  Timer? _stepTimer;
  Timer? _helpTimer;

  // Getters
  OnboardingState get state => _state;
  OnboardingProgress? get progress => _progress;
  OnboardingPreferences get preferences => _preferences;
  bool get isActive => _state == OnboardingState.tutorial;
  bool get isCompleted => _state == OnboardingState.completed;

  /// Start the fast onboarding experience
  Future<void> startOnboarding({
    OnboardingPreferences? userPreferences,
  }) async {
    if (_state != OnboardingState.notStarted) return;

    _preferences = userPreferences ?? _preferences;
    
    // Skip if user has opted out
    if (_preferences.skipTutorial) {
      await _skipOnboarding();
      return;
    }

    _state = OnboardingState.tutorial;
    _progress = OnboardingProgress(
      currentStep: TutorialStep.welcome,
      startTime: DateTime.now(),
    );

    await _analytics.trackEvent('onboarding_started');
    
    // Start with welcome step
    await _startWelcomeStep();
    
    notifyListeners();
  }

  /// Skip the onboarding process
  Future<void> skipOnboarding() async {
    if (_state != OnboardingState.tutorial) return;
    
    await _analytics.trackEvent('onboarding_skipped', parameters: {
      'step': _progress?.currentStep.name,
      'elapsed_seconds': _progress?.elapsedTime.inSeconds,
    });
    
    await _skipOnboarding();
  }

  Future<void> _skipOnboarding() async {
    _state = OnboardingState.skipped;
    _cleanupTimers();
    notifyListeners();
  }

  /// Record user interaction during onboarding
  void recordInteraction(String action, {bool success = false}) {
    if (_progress == null) return;

    final interaction = OnboardingInteraction(
      timestamp: DateTime.now(),
      action: action,
      step: _progress!.currentStep,
      success: success,
    );

    _progress = _progress!.copyWith(
      interactions: [..._progress!.interactions, interaction],
    );

    // Check if step is completed
    if (success) {
      _completeCurrentStep();
    }

    notifyListeners();
  }

  /// Start the welcome step (immediate fun)
  Future<void> _startWelcomeStep() async {
    // Provide immediate haptic feedback for engagement
    if (_preferences.hapticFeedback) {
      await HapticFeedback.lightImpact();
    }

    // Auto-advance to first interactive step after 2 seconds
    _stepTimer = Timer(const Duration(seconds: 2), () {
      _advanceToStep(TutorialStep.tapToJump);
    });

    // Set up help timer for stuck users
    _setupHelpTimer();
  }

  /// Advance to the next tutorial step
  void _advanceToStep(TutorialStep nextStep) {
    if (_progress == null) return;

    _progress = _progress!.copyWith(
      currentStep: nextStep,
      completedSteps: [..._progress!.completedSteps, _progress!.currentStep],
    );

    _cleanupTimers();
    _setupStepLogic(nextStep);
    notifyListeners();
  }

  /// Complete the current step and advance
  void _completeCurrentStep() {
    final currentStep = _progress?.currentStep;
    if (currentStep == null) return;

    // Provide success feedback
    if (_preferences.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    // Determine next step
    final nextStep = _getNextStep(currentStep);
    if (nextStep != null) {
      _advanceToStep(nextStep);
    } else {
      _completeOnboarding();
    }
  }

  /// Get the next tutorial step
  TutorialStep? _getNextStep(TutorialStep current) {
    switch (current) {
      case TutorialStep.welcome:
        return TutorialStep.tapToJump;
      case TutorialStep.tapToJump:
        return TutorialStep.drawPlatform;
      case TutorialStep.drawPlatform:
        return TutorialStep.collectCoin;
      case TutorialStep.collectCoin:
        return TutorialStep.avoidObstacle;
      case TutorialStep.avoidObstacle:
        return TutorialStep.completed;
      case TutorialStep.completed:
        return null;
    }
  }

  /// Set up logic for specific tutorial step
  void _setupStepLogic(TutorialStep step) {
    switch (step) {
      case TutorialStep.tapToJump:
        _setupTapToJumpStep();
        break;
      case TutorialStep.drawPlatform:
        _setupDrawPlatformStep();
        break;
      case TutorialStep.collectCoin:
        _setupCollectCoinStep();
        break;
      case TutorialStep.avoidObstacle:
        _setupAvoidObstacleStep();
        break;
      case TutorialStep.completed:
        _completeOnboarding();
        break;
      case TutorialStep.welcome:
        break;
    }
    
    _setupHelpTimer();
  }

  /// Set up tap to jump tutorial step
  void _setupTapToJumpStep() {
    // Auto-complete after 5 seconds if user doesn't interact
    _stepTimer = Timer(const Duration(seconds: 5), () {
      if (_progress?.currentStep == TutorialStep.tapToJump) {
        recordInteraction('auto_jump', success: true);
      }
    });
  }

  /// Set up draw platform tutorial step
  void _setupDrawPlatformStep() {
    // Auto-complete after 6 seconds
    _stepTimer = Timer(const Duration(seconds: 6), () {
      if (_progress?.currentStep == TutorialStep.drawPlatform) {
        recordInteraction('auto_draw', success: true);
      }
    });
  }

  /// Set up collect coin tutorial step
  void _setupCollectCoinStep() {
    // Auto-complete after 4 seconds
    _stepTimer = Timer(const Duration(seconds: 4), () {
      if (_progress?.currentStep == TutorialStep.collectCoin) {
        recordInteraction('auto_collect', success: true);
      }
    });
  }

  /// Set up avoid obstacle tutorial step
  void _setupAvoidObstacleStep() {
    // Auto-complete after 3 seconds
    _stepTimer = Timer(const Duration(seconds: 3), () {
      if (_progress?.currentStep == TutorialStep.avoidObstacle) {
        recordInteraction('auto_avoid', success: true);
      }
    });
  }

  /// Set up help timer for stuck users
  void _setupHelpTimer() {
    _helpTimer?.cancel();
    _helpTimer = Timer(const Duration(seconds: 8), () {
      if (_progress != null && !_progress!.needsHelp) {
        _progress = _progress!.copyWith(needsHelp: true);
        notifyListeners();
      }
    });
  }

  /// Complete the onboarding process
  Future<void> _completeOnboarding() async {
    final elapsedTime = _progress?.elapsedTime.inSeconds ?? 0;
    
    await _analytics.trackEvent('onboarding_completed', parameters: {
      'duration_seconds': elapsedTime,
      'interactions_count': _progress?.interactions.length ?? 0,
      'help_needed': _progress?.needsHelp ?? false,
    });

    _state = OnboardingState.completed;
    _cleanupTimers();
    notifyListeners();
  }

  /// Clean up timers
  void _cleanupTimers() {
    _stepTimer?.cancel();
    _helpTimer?.cancel();
    _stepTimer = null;
    _helpTimer = null;
  }

  /// Update user preferences
  void updatePreferences(OnboardingPreferences newPreferences) {
    _preferences = newPreferences;
    notifyListeners();
  }

  /// Get tutorial message for current step
  String getTutorialMessage() {
    if (_progress == null) return '';

    switch (_progress!.currentStep) {
      case TutorialStep.welcome:
        return 'Welcome to Quick Draw Dash!';
      case TutorialStep.tapToJump:
        return 'Tap to jump over obstacles!';
      case TutorialStep.drawPlatform:
        return 'Hold and drag to draw platforms!';
      case TutorialStep.collectCoin:
        return 'Collect coins for rewards!';
      case TutorialStep.avoidObstacle:
        return 'Avoid the red obstacles!';
      case TutorialStep.completed:
        return 'Great job! You\'re ready to play!';
    }
  }

  /// Get tutorial hint for current step
  String getTutorialHint() {
    if (_progress == null || !_progress!.needsHelp) return '';

    switch (_progress!.currentStep) {
      case TutorialStep.welcome:
        return '';
      case TutorialStep.tapToJump:
        return 'Try tapping anywhere on the screen';
      case TutorialStep.drawPlatform:
        return 'Hold your finger down and drag to create a line';
      case TutorialStep.collectCoin:
        return 'Jump or draw platforms to reach the golden coin';
      case TutorialStep.avoidObstacle:
        return 'Jump over or draw around the red spikes';
      case TutorialStep.completed:
        return '';
    }
  }

  /// Check if onboarding should be fast-tracked (under 15 seconds)
  bool shouldFastTrack() {
    if (_progress == null) return false;
    return _progress!.elapsedTime.inSeconds > 12;
  }

  @override
  void dispose() {
    _cleanupTimers();
    super.dispose();
  }
}