/// Integration layer for connecting onboarding system to the main game
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'onboarding_manager.dart';
import 'models/onboarding_models.dart';
import '../core/analytics/analytics_service.dart';
import '../app/di/injector.dart';

/// Service for integrating onboarding with the main game
class OnboardingIntegration {
  static OnboardingManager? _instance;

  /// Get or create the onboarding manager instance
  static OnboardingManager getInstance() {
    if (_instance == null) {
      final analytics = serviceLocator<AnalyticsService>();
      _instance = OnboardingManager(analytics: analytics);
    }
    return _instance!;
  }

  /// Initialize onboarding for new users
  static Future<void> initializeForNewUser() async {
    final manager = getInstance();
    await manager.initialize();
    
    // Check if user needs onboarding
    if (manager.needsOnboarding) {
      await manager.startOnboarding();
    }
  }

  /// Handle game events for onboarding
  static void handleGameEvent({
    required String event,
    Map<String, dynamic>? data,
  }) {
    final manager = getInstance();
    
    switch (event) {
      case 'game_started':
        _handleGameStarted(manager, data);
        break;
      case 'game_over':
        _handleGameOver(manager, data);
        break;
      case 'user_interaction':
        _handleUserInteraction(manager, data);
        break;
      case 'level_completed':
        _handleLevelCompleted(manager, data);
        break;
    }
  }

  static void _handleGameStarted(OnboardingManager manager, Map<String, dynamic>? data) {
    // Start session tracking
    manager.motivation.startSession();
  }

  static void _handleGameOver(OnboardingManager manager, Map<String, dynamic>? data) {
    if (data == null) return;

    final score = data['score'] as int? ?? 0;
    final coins = data['coins'] as int? ?? 0;
    final playTime = data['play_time'] as Duration? ?? Duration.zero;
    final bestScore = data['best_score'] as int? ?? 0;

    manager.handleGameOver(
      score: score,
      coinsCollected: coins,
      playTime: playTime,
      bestScore: bestScore,
    );
  }

  static void _handleUserInteraction(OnboardingManager manager, Map<String, dynamic>? data) {
    if (data == null) return;

    final action = data['action'] as String? ?? '';
    final successful = data['successful'] as bool? ?? false;
    final position = data['position'] as Offset?;

    manager.handleUserInteraction(
      action: action,
      successful: successful,
      position: position,
    );
  }

  static void _handleLevelCompleted(OnboardingManager manager, Map<String, dynamic>? data) {
    // Handle level completion events
    if (data == null) return;

    final level = data['level'] as int? ?? 1;
    final score = data['score'] as int? ?? 0;

    // Show progress celebration for significant achievements
    if (level % 5 == 0) {
      manager.motivation.showProgressMilestone(
        milestone: 'Level $level Reached!',
        description: 'You\'re making great progress!',
        reward: level * 10,
      );
    }
  }

  /// Show login bonus preview
  static Future<void> showLoginBonusPreview({
    required int tomorrowBonus,
    required int currentStreak,
  }) async {
    final manager = getInstance();
    await manager.showLoginBonusPreview(
      tomorrowBonus: tomorrowBonus,
      currentStreak: currentStreak,
    );
  }

  /// Show continuous player reward
  static Future<void> showContinuousPlayerReward({
    required int daysPlayed,
    required int bonusCoins,
    String? specialItem,
  }) async {
    final manager = getInstance();
    await manager.showContinuousPlayerReward(
      daysPlayed: daysPlayed,
      bonusCoins: bonusCoins,
      specialItem: specialItem,
    );
  }

  /// Check if onboarding is active
  static bool get isOnboardingActive {
    return _instance?.isOnboardingActive ?? false;
  }

  /// Check if user needs help
  static bool get userNeedsHelp {
    return _instance?.userNeedsHelp ?? false;
  }

  /// Get current tutorial message
  static String get currentTutorialMessage {
    return _instance?.currentTutorialMessage ?? '';
  }

  /// Skip onboarding
  static Future<void> skipOnboarding() async {
    if (_instance != null) {
      await _instance!.skipOnboarding();
    }
  }

  /// Reset onboarding (for testing)
  static void resetOnboarding() {
    _instance?.resetOnboarding();
  }

  /// Dispose of the onboarding manager
  static void dispose() {
    _instance?.dispose();
    _instance = null;
  }
}

/// Provider widget for onboarding
class OnboardingProvider extends StatefulWidget {
  const OnboardingProvider({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OnboardingProvider> createState() => _OnboardingProviderState();
}

class _OnboardingProviderState extends State<OnboardingProvider> {
  late OnboardingManager _onboardingManager;

  @override
  void initState() {
    super.initState();
    _onboardingManager = OnboardingIntegration.getInstance();
    
    // Initialize onboarding for new users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OnboardingIntegration.initializeForNewUser();
    });
  }

  @override
  void dispose() {
    // Don't dispose here as it's a singleton
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OnboardingManager>.value(
      value: _onboardingManager,
      child: widget.child,
    );
  }
}

/// Mixin for widgets that need to interact with onboarding
mixin OnboardingAware<T extends StatefulWidget> on State<T> {
  OnboardingManager get onboarding => OnboardingIntegration.getInstance();

  /// Handle user interaction for onboarding
  void handleOnboardingInteraction({
    required String action,
    bool successful = false,
    Offset? position,
  }) {
    OnboardingIntegration.handleGameEvent(
      event: 'user_interaction',
      data: {
        'action': action,
        'successful': successful,
        'position': position,
      },
    );
  }

  /// Handle game over for onboarding
  void handleOnboardingGameOver({
    required int score,
    required int coins,
    required Duration playTime,
    required int bestScore,
  }) {
    OnboardingIntegration.handleGameEvent(
      event: 'game_over',
      data: {
        'score': score,
        'coins': coins,
        'play_time': playTime,
        'best_score': bestScore,
      },
    );
  }

  /// Handle game start for onboarding
  void handleOnboardingGameStart() {
    OnboardingIntegration.handleGameEvent(
      event: 'game_started',
      data: {},
    );
  }

  /// Check if should show onboarding UI
  bool get shouldShowOnboardingUI => onboarding.isOnboardingActive;

  /// Get current onboarding message
  String get onboardingMessage => onboarding.currentTutorialMessage;

  /// Get current onboarding hint
  String get onboardingHint => onboarding.currentTutorialHint;
}