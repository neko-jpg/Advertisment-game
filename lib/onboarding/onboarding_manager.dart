/// Main onboarding manager that coordinates all onboarding systems
library;

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'fast_onboarding_system.dart';
import 'visual_guide_system.dart';
import 'motivation_system.dart';
import 'models/onboarding_models.dart';
import '../core/analytics/analytics_service.dart';

/// Coordinates all onboarding systems to provide seamless user experience
class OnboardingManager extends ChangeNotifier {
  OnboardingManager({
    required AnalyticsService analytics,
  }) : _analytics = analytics,
       _fastOnboarding = FastOnboardingSystem(analytics: analytics),
       _visualGuide = VisualGuideSystem(analytics: analytics),
       _motivation = MotivationSystem(analytics: analytics) {
    
    // Listen to subsystem changes
    _fastOnboarding.addListener(_onSubsystemChanged);
    _visualGuide.addListener(_onSubsystemChanged);
    _motivation.addListener(_onSubsystemChanged);
  }

  final AnalyticsService _analytics;
  final FastOnboardingSystem _fastOnboarding;
  final VisualGuideSystem _visualGuide;
  final MotivationSystem _motivation;

  bool _isInitialized = false;
  Timer? _progressTimer;

  // Getters for subsystems
  FastOnboardingSystem get fastOnboarding => _fastOnboarding;
  VisualGuideSystem get visualGuide => _visualGuide;
  MotivationSystem get motivation => _motivation;

  // Combined state getters
  bool get isOnboardingActive => _fastOnboarding.isActive;
  bool get isOnboardingCompleted => _fastOnboarding.isCompleted;
  bool get needsOnboarding => !_isInitialized || _fastOnboarding.state == OnboardingState.notStarted;

  /// Initialize the onboarding manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _analytics.trackEvent('onboarding_manager_initialized');
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Start the complete onboarding experience
  Future<void> startOnboarding({
    OnboardingPreferences? preferences,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _analytics.trackEvent('complete_onboarding_started');

    // Start the fast onboarding system
    await _fastOnboarding.startOnboarding(userPreferences: preferences);

    // Start session tracking
    _motivation.startSession();

    // Begin progress monitoring
    _startProgressMonitoring();
  }

  /// Handle user interaction during onboarding
  void handleUserInteraction({
    required String action,
    bool successful = false,
    Offset? position,
  }) {
    // Record interaction in fast onboarding
    if (_fastOnboarding.isActive) {
      _fastOnboarding.recordInteraction(action, success: successful);
    }

    // Record interaction in visual guide system
    _visualGuide.recordInteraction(action, successful: successful);

    // Show contextual guides if needed
    if (!successful && position != null) {
      _showContextualGuide(action, position);
    }
  }

  /// Handle game over event
  Future<void> handleGameOver({
    required int score,
    required int coinsCollected,
    required Duration playTime,
    required int bestScore,
  }) async {
    if (_motivation.isFirstGameOver) {
      await _motivation.handleFirstGameOver(
        score: score,
        coinsCollected: coinsCollected,
        playTime: playTime,
      );
    } else {
      await _motivation.handleGameOver(
        score: score,
        coinsCollected: coinsCollected,
        playTime: playTime,
        bestScore: bestScore,
      );
    }

    // Show progress celebration if user improved
    if (score > bestScore) {
      final progress = _calculateOverallProgress();
      await _visualGuide.showProgressCelebration(progress);
    }
  }

  /// Show contextual guide based on action and position
  Future<void> _showContextualGuide(String action, Offset position) async {
    GuideType guideType;
    String message;

    switch (action) {
      case 'jump':
        guideType = GuideType.tap;
        message = _visualGuide.getContextualHint('jump');
        break;
      case 'draw':
        guideType = GuideType.draw;
        message = _visualGuide.getContextualHint('draw');
        break;
      case 'collect':
        guideType = GuideType.highlight;
        message = _visualGuide.getContextualHint('collect');
        break;
      default:
        guideType = GuideType.tap;
        message = 'Try tapping or drawing!';
    }

    await _visualGuide.showGuide(
      type: guideType,
      position: position,
      message: message,
      duration: const Duration(seconds: 3),
    );
  }

  /// Start progress monitoring
  void _startProgressMonitoring() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkProgressMilestones();
    });
  }

  /// Check for progress milestones
  void _checkProgressMilestones() {
    final progress = _calculateOverallProgress();
    final achievements = _visualGuide.achievements;

    // Check for milestone achievements
    if (progress >= 0.25 && !achievements.contains('quarter_progress')) {
      _motivation.showProgressMilestone(
        milestone: '25% Progress',
        description: 'You\'re getting the hang of it!',
        reward: 50,
      );
    } else if (progress >= 0.5 && !achievements.contains('half_progress')) {
      _motivation.showProgressMilestone(
        milestone: '50% Progress',
        description: 'Halfway to mastery!',
        reward: 100,
      );
    } else if (progress >= 0.75 && !achievements.contains('three_quarter_progress')) {
      _motivation.showProgressMilestone(
        milestone: '75% Progress',
        description: 'You\'re almost a pro!',
        reward: 150,
      );
    } else if (progress >= 1.0 && !achievements.contains('full_progress')) {
      _motivation.showProgressMilestone(
        milestone: 'Mastery Achieved',
        description: 'You\'ve mastered the basics!',
        reward: 250,
      );
    }
  }

  /// Calculate overall progress across all systems
  double _calculateOverallProgress() {
    final visualProgress = _visualGuide.getProgressVisualization();
    final overallProgress = visualProgress['overall_progress'] as double? ?? 0.0;
    
    // Factor in onboarding completion
    double onboardingProgress = 0.0;
    if (_fastOnboarding.isCompleted) {
      onboardingProgress = 1.0;
    } else if (_fastOnboarding.isActive && _fastOnboarding.progress != null) {
      final completedSteps = _fastOnboarding.progress!.completedSteps.length;
      onboardingProgress = completedSteps / 6.0; // 6 total steps
    }

    // Weighted average: 60% visual progress, 40% onboarding progress
    return (overallProgress * 0.6) + (onboardingProgress * 0.4);
  }

  /// Show login bonus preview
  Future<void> showLoginBonusPreview({
    required int tomorrowBonus,
    required int currentStreak,
  }) async {
    await _motivation.showLoginBonusPreview(
      tomorrowBonus: tomorrowBonus,
      currentStreak: currentStreak,
    );
  }

  /// Show continuous player reward
  Future<void> showContinuousPlayerReward({
    required int daysPlayed,
    required int bonusCoins,
    String? specialItem,
  }) async {
    await _motivation.showContinuousPlayerReward(
      daysPlayed: daysPlayed,
      bonusCoins: bonusCoins,
      specialItem: specialItem,
    );
  }

  /// Get comprehensive onboarding status
  Map<String, dynamic> getOnboardingStatus() {
    return {
      'is_initialized': _isInitialized,
      'onboarding_state': _fastOnboarding.state.name,
      'overall_progress': _calculateOverallProgress(),
      'visual_guide_data': _visualGuide.getProgressVisualization(),
      'motivation_stats': _motivation.getMotivationStats(),
      'needs_onboarding': needsOnboarding,
      'is_active': isOnboardingActive,
      'is_completed': isOnboardingCompleted,
    };
  }

  /// Skip the entire onboarding process
  Future<void> skipOnboarding() async {
    await _fastOnboarding.skipOnboarding();
    _visualGuide.hideGuide();
    _motivation.hideMotivationMessage();
    
    await _analytics.trackEvent('complete_onboarding_skipped');
  }

  /// Reset all onboarding systems
  void resetOnboarding() {
    _fastOnboarding.updatePreferences(const OnboardingPreferences());
    _visualGuide.reset();
    _motivation.reset();
    _isInitialized = false;
    
    _progressTimer?.cancel();
    
    notifyListeners();
  }

  /// Handle subsystem changes
  void _onSubsystemChanged() {
    notifyListeners();
  }

  /// Update onboarding preferences
  void updatePreferences(OnboardingPreferences preferences) {
    _fastOnboarding.updatePreferences(preferences);
  }

  /// Check if user needs help
  bool get userNeedsHelp => 
      _visualGuide.isConfused || 
      (_fastOnboarding.progress?.needsHelp ?? false);

  /// Get current tutorial message
  String get currentTutorialMessage => _fastOnboarding.getTutorialMessage();

  /// Get current tutorial hint
  String get currentTutorialHint => _fastOnboarding.getTutorialHint();

  @override
  void dispose() {
    _progressTimer?.cancel();
    _fastOnboarding.removeListener(_onSubsystemChanged);
    _visualGuide.removeListener(_onSubsystemChanged);
    _motivation.removeListener(_onSubsystemChanged);
    _fastOnboarding.dispose();
    _visualGuide.dispose();
    _motivation.dispose();
    super.dispose();
  }
}