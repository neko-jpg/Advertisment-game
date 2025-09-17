/// Continuation motivation and revisit promotion system
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/onboarding_models.dart';
import '../core/analytics/analytics_service.dart';

/// Manages motivation messages and revisit promotion for new users
class MotivationSystem extends ChangeNotifier {
  MotivationSystem({
    required AnalyticsService analytics,
  }) : _analytics = analytics;

  final AnalyticsService _analytics;
  
  MotivationMessage? _currentMessage;
  Timer? _messageTimer;
  bool _isFirstGameOver = true;
  int _gameOverCount = 0;
  int _sessionCount = 0;
  DateTime? _lastPlayTime;
  
  // Motivation state
  final List<String> _shownMessages = [];
  final Map<String, int> _messageFrequency = {};

  // Getters
  MotivationMessage? get currentMessage => _currentMessage;
  bool get isFirstGameOver => _isFirstGameOver;
  int get gameOverCount => _gameOverCount;
  int get sessionCount => _sessionCount;

  /// Handle first game over with motivational message
  Future<void> handleFirstGameOver({
    required int score,
    required int coinsCollected,
    required Duration playTime,
  }) async {
    if (!_isFirstGameOver) return;

    _isFirstGameOver = false;
    _gameOverCount = 1;

    await _analytics.trackEvent('first_game_over', parameters: {
      'score': score,
      'coins': coinsCollected,
      'play_time_seconds': playTime.inSeconds,
    });

    // Show encouraging message based on performance
    final message = _generateFirstGameOverMessage(score, coinsCollected, playTime);
    await showMotivationMessage(message);
  }

  /// Handle subsequent game overs
  Future<void> handleGameOver({
    required int score,
    required int coinsCollected,
    required Duration playTime,
    required int bestScore,
  }) async {
    _gameOverCount++;

    // Show motivation message based on performance and history
    if (_shouldShowMotivationMessage()) {
      final message = _generateGameOverMessage(score, coinsCollected, bestScore);
      await showMotivationMessage(message);
    }
  }

  /// Generate first game over motivation message
  MotivationMessage _generateFirstGameOverMessage(
    int score,
    int coinsCollected,
    Duration playTime,
  ) {
    // Positive reinforcement regardless of performance
    if (score > 100) {
      return const MotivationMessage(
        title: 'Great Start!',
        message: 'You scored over 100 on your first try! You\'re a natural!',
        type: MotivationType.encouragement,
        actionText: 'Play Again',
      );
    } else if (coinsCollected > 5) {
      return const MotivationMessage(
        title: 'Nice Collecting!',
        message: 'You collected coins like a pro! Keep it up!',
        type: MotivationType.encouragement,
        actionText: 'Collect More',
      );
    } else if (playTime.inSeconds > 30) {
      return const MotivationMessage(
        title: 'Good Effort!',
        message: 'You lasted 30+ seconds! That\'s impressive for a first try!',
        type: MotivationType.encouragement,
        actionText: 'Try Again',
      );
    } else {
      return const MotivationMessage(
        title: 'Every Expert Was Once a Beginner!',
        message: 'Don\'t worry, everyone starts somewhere. You\'ll get better!',
        type: MotivationType.encouragement,
        actionText: 'Keep Going',
      );
    }
  }

  /// Generate regular game over motivation message
  MotivationMessage _generateGameOverMessage(
    int score,
    int coinsCollected,
    int bestScore,
  ) {
    final random = math.Random();
    
    // New personal best
    if (score > bestScore) {
      return MotivationMessage(
        title: 'New Record!',
        message: 'You beat your best score by ${score - bestScore} points!',
        type: MotivationType.achievement,
        actionText: 'Beat It Again',
        reward: coinsCollected,
      );
    }
    
    // Close to personal best
    if (score > bestScore * 0.8) {
      return const MotivationMessage(
        title: 'So Close!',
        message: 'You\'re getting closer to your best score!',
        type: MotivationType.progress,
        actionText: 'One More Try',
      );
    }
    
    // Random encouragement messages
    final encouragements = [
      'Practice makes perfect!',
      'You\'re improving with each game!',
      'Don\'t give up, you\'ve got this!',
      'Every attempt makes you better!',
      'The next run could be your best!',
    ];
    
    return MotivationMessage(
      title: 'Keep Going!',
      message: encouragements[random.nextInt(encouragements.length)],
      type: MotivationType.encouragement,
      actionText: 'Play Again',
    );
  }

  /// Show motivation message
  Future<void> showMotivationMessage(MotivationMessage message) async {
    _currentMessage = message;
    
    // Track message shown
    final messageKey = '${message.type.name}_${message.title}';
    _shownMessages.add(messageKey);
    _messageFrequency[messageKey] = (_messageFrequency[messageKey] ?? 0) + 1;

    await _analytics.trackEvent('motivation_message_shown', parameters: {
      'type': message.type.name,
      'title': message.title,
      'frequency': _messageFrequency[messageKey],
    });

    // Provide haptic feedback for positive messages
    if (message.type == MotivationType.achievement || 
        message.type == MotivationType.reward) {
      await HapticFeedback.mediumImpact();
    }

    // Auto-hide message after 5 seconds
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 5), () {
      hideMotivationMessage();
    });

    notifyListeners();
  }

  /// Hide current motivation message
  void hideMotivationMessage() {
    if (_currentMessage == null) return;

    _currentMessage = null;
    _messageTimer?.cancel();
    notifyListeners();
  }

  /// Check if should show motivation message
  bool _shouldShowMotivationMessage() {
    // Always show for first few game overs
    if (_gameOverCount <= 3) return true;
    
    // Show less frequently as user plays more
    if (_gameOverCount <= 10) return _gameOverCount % 2 == 0;
    
    // Show occasionally for experienced players
    return _gameOverCount % 5 == 0;
  }

  /// Start new session
  void startSession() {
    _sessionCount++;
    _lastPlayTime = DateTime.now();
    
    // Show welcome back message for returning users
    if (_sessionCount > 1) {
      _showWelcomeBackMessage();
    }
  }

  /// Show welcome back message
  Future<void> _showWelcomeBackMessage() async {
    final timeSinceLastPlay = _lastPlayTime != null 
        ? DateTime.now().difference(_lastPlayTime!).inHours 
        : 0;

    MotivationMessage message;
    
    if (timeSinceLastPlay >= 24) {
      message = const MotivationMessage(
        title: 'Welcome Back!',
        message: 'Ready to beat your high score?',
        type: MotivationType.comeback,
        actionText: 'Let\'s Go!',
      );
    } else if (timeSinceLastPlay >= 1) {
      message = const MotivationMessage(
        title: 'Good to See You!',
        message: 'Time to show off those improved skills!',
        type: MotivationType.comeback,
        actionText: 'Play Now',
      );
    } else {
      // Don't show message for very recent returns
      return;
    }

    await showMotivationMessage(message);
  }

  /// Generate login bonus preview message
  Future<void> showLoginBonusPreview({
    required int tomorrowBonus,
    required int currentStreak,
  }) async {
    final message = MotivationMessage(
      title: 'Come Back Tomorrow!',
      message: 'Day ${currentStreak + 1} bonus: $tomorrowBonus coins waiting for you!',
      type: MotivationType.reward,
      actionText: 'Set Reminder',
      reward: tomorrowBonus,
    );

    await showMotivationMessage(message);
    
    await _analytics.trackEvent('login_bonus_preview_shown', parameters: {
      'tomorrow_bonus': tomorrowBonus,
      'current_streak': currentStreak,
    });
  }

  /// Show special reward for continuous players
  Future<void> showContinuousPlayerReward({
    required int daysPlayed,
    required int bonusCoins,
    String? specialItem,
  }) async {
    final message = MotivationMessage(
      title: 'Loyalty Reward!',
      message: specialItem != null 
          ? 'You\'ve played $daysPlayed days! Here\'s $bonusCoins coins and $specialItem!'
          : 'You\'ve played $daysPlayed days! Here\'s $bonusCoins bonus coins!',
      type: MotivationType.reward,
      actionText: 'Awesome!',
      reward: bonusCoins,
    );

    await showMotivationMessage(message);
    
    await _analytics.trackEvent('continuous_player_reward', parameters: {
      'days_played': daysPlayed,
      'bonus_coins': bonusCoins,
      'special_item': specialItem,
    });
  }

  /// Show progress milestone message
  Future<void> showProgressMilestone({
    required String milestone,
    required String description,
    int? reward,
  }) async {
    final message = MotivationMessage(
      title: 'Milestone Reached!',
      message: '$milestone: $description',
      type: MotivationType.achievement,
      actionText: 'Keep Going!',
      reward: reward,
    );

    await showMotivationMessage(message);
  }

  /// Get personalized encouragement based on user history
  String getPersonalizedEncouragement() {
    if (_gameOverCount <= 3) {
      return 'You\'re just getting started! Every game makes you better!';
    } else if (_gameOverCount <= 10) {
      return 'You\'re improving! Keep up the great work!';
    } else if (_gameOverCount <= 25) {
      return 'You\'re becoming a pro! Show us what you\'ve learned!';
    } else {
      return 'You\'re a veteran player! Time to set new records!';
    }
  }

  /// Get motivation statistics
  Map<String, dynamic> getMotivationStats() {
    return {
      'game_over_count': _gameOverCount,
      'session_count': _sessionCount,
      'messages_shown': _shownMessages.length,
      'unique_messages': _messageFrequency.keys.length,
      'is_first_game_over': _isFirstGameOver,
    };
  }

  /// Reset motivation system (for testing or new user)
  void reset() {
    _currentMessage = null;
    _isFirstGameOver = true;
    _gameOverCount = 0;
    _sessionCount = 0;
    _lastPlayTime = null;
    _shownMessages.clear();
    _messageFrequency.clear();
    
    _messageTimer?.cancel();
    
    notifyListeners();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }
}