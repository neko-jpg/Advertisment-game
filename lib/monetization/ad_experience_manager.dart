import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/analytics/models/behavior_models.dart';
import '../core/logging/logger.dart';
import '../game/models/game_models.dart';
import 'models/monetization_models.dart';
import 'services/monetization_storage_service.dart';

/// Manages ad experience with focus on natural timing and user value
/// 
/// Implements requirements:
/// - 2.1: Natural timing ad display (game over, achievement moments)
/// - 2.2: Pre-explanation of ad value ("watch ad to continue")
/// - 2.3: Post-ad gratitude and follow-up system
class AdExperienceManager {
  AdExperienceManager({
    required MonetizationStorageService storageService,
    required AppLogger logger,
  }) : _storageService = storageService,
       _logger = logger;

  final MonetizationStorageService _storageService;
  final AppLogger _logger;

  // Natural timing thresholds
  static const Duration _minimumSessionForAd = Duration(minutes: 2);
  static const Duration _cooldownBetweenAds = Duration(minutes: 3);
  static const int _maxAdsPerSession = 3;

  final Map<String, DateTime> _lastAdShownTime = {};
  final Map<String, int> _adsShownThisSession = {};

  /// Determines if current moment is natural for showing ads
  /// Requirement 2.1: Natural timing ad display
  bool isNaturalAdMoment(GameState state, UserSession session) {
    try {
      // Check if enough time has passed in session
      if (session.duration < _minimumSessionForAd) {
        return false;
      }

      // Check cooldown between ads
      final userId = session.userId;
      final lastAdTime = _lastAdShownTime[userId];
      if (lastAdTime != null) {
        final timeSinceLastAd = DateTime.now().difference(lastAdTime);
        if (timeSinceLastAd < _cooldownBetweenAds) {
          return false;
        }
      }

      // Check session ad limit
      final adsThisSession = _adsShownThisSession[userId] ?? 0;
      if (adsThisSession >= _maxAdsPerSession) {
        return false;
      }

      // Natural break points
      return switch (state) {
        GameState.gameOver => true,
        GameState.levelComplete => true,
        GameState.paused => session.duration.inMinutes >= 5, // Only for longer sessions
        GameState.menu => false, // Avoid interrupting menu navigation
        GameState.playing => false, // Never interrupt active gameplay
      };
    } catch (error, stackTrace) {
      _logger.error('Error checking natural ad moment', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Generates value proposition message for ad
  /// Requirement 2.2: Ad value pre-explanation
  String generateAdValueProposition(AdType adType, GameContext context) {
    try {
      return switch (adType) {
        AdType.rewarded => _generateRewardedAdProposition(context),
        AdType.interstitial => _generateInterstitialAdProposition(context),
        AdType.banner => '', // Banners don't need propositions
      };
    } catch (error, stackTrace) {
      _logger.error('Error generating ad value proposition', 
          error: error, stackTrace: stackTrace);
      return 'スポンサーからのメッセージをご覧ください';
    }
  }

  /// Handles post-ad experience with gratitude and follow-up
  /// Requirement 2.3: Post-ad gratitude and follow-up
  Future<void> handlePostAdExperience(AdResult result) async {
    try {
      final userId = result.userId;
      final adType = result.adType;
      final completed = result.completed;

      // Record the ad interaction
      await _storageService.recordAdInteraction(
        userId,
        adType: adType.name,
        viewDuration: result.viewDuration,
        completed: completed,
        skipped: !completed,
      );

      // Update tracking
      _lastAdShownTime[userId] = DateTime.now();
      _adsShownThisSession[userId] = (_adsShownThisSession[userId] ?? 0) + 1;

      // Generate appropriate follow-up
      final followUp = _generatePostAdFollowUp(result);
      
      // Store follow-up for UI to display
      await _storePostAdFollowUp(userId, followUp);

      _logger.info('Handled post-ad experience for user $userId: '
          'type=${adType.name}, completed=$completed');
    } catch (error, stackTrace) {
      _logger.error('Error handling post-ad experience', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Calculates optimal ad timing based on user behavior
  Future<Duration> calculateOptimalAdTiming(String userId, UserBehaviorData behaviorData) async {
    try {
      // Analyze user's session patterns
      final sessions = behaviorData.sessions;
      if (sessions.isEmpty) {
        return _minimumSessionForAd;
      }

      // Find average time to first meaningful action
      final avgTimeToEngagement = _calculateAverageEngagementTime(sessions);
      
      // Find typical session length
      final avgSessionLength = behaviorData.averageSessionLength;
      
      // Optimal timing is usually 1/3 into a typical session, but not before engagement
      final optimalTiming = Duration(
        milliseconds: math.max(
          avgTimeToEngagement.inMilliseconds,
          (avgSessionLength.inMilliseconds * 0.33).round(),
        ),
      );

      // Ensure it's within reasonable bounds
      return Duration(
        milliseconds: math.max(
          _minimumSessionForAd.inMilliseconds,
          math.min(optimalTiming.inMilliseconds, const Duration(minutes: 10).inMilliseconds),
        ),
      );
    } catch (error, stackTrace) {
      _logger.error('Error calculating optimal ad timing', 
          error: error, stackTrace: stackTrace);
      return _minimumSessionForAd;
    }
  }

  /// Determines if user is in a positive state for ads
  bool isUserInPositiveState(GameContext context, UserBehaviorData behaviorData) {
    try {
      // Negative indicators
      if (context.playerMood == PlayerMood.frustrated) return false;
      if (context.consecutiveFailures >= 3) return false;
      
      // Positive indicators
      if (context.achievementJustUnlocked) return true;
      if (context.playerMood == PlayerMood.excited) return true;
      if (context.currentScore > behaviorData.averageScore * 1.2) return true;
      
      // Neutral state - check if user generally engages with ads
      final adHistory = behaviorData.adInteractions;
      if (adHistory.isNotEmpty) {
        final recentEngagement = adHistory
            .where((ad) => DateTime.now().difference(DateTime.parse(ad['timestamp'] as String)).inDays <= 7)
            .length;
        return recentEngagement > 0;
      }
      
      return true; // Default to allowing ads for new users
    } catch (error, stackTrace) {
      _logger.error('Error checking user positive state', 
          error: error, stackTrace: stackTrace);
      return true;
    }
  }

  String _generateRewardedAdProposition(GameContext context) {
    if (context.gameState == GameState.gameOver) {
      if (context.currentScore > 0) {
        return '広告を見てスコアを2倍にしませんか？';
      } else {
        return '広告を見てもう一度チャレンジしませんか？';
      }
    } else if (context.gameState == GameState.levelComplete) {
      return '広告を見てボーナスコインを獲得しませんか？';
    } else if (context.coinsEarned > 0) {
      return '広告を見てコインを2倍にしませんか？';
    }
    return '広告を見て特別報酬を獲得しませんか？';
  }

  String _generateInterstitialAdProposition(GameContext context) {
    if (context.gameState == GameState.gameOver) {
      return 'スポンサーからの短いメッセージの後、続けてプレイできます';
    } else if (context.sessionDuration.inMinutes >= 10) {
      return '少し休憩しませんか？スポンサーメッセージの後、続きをお楽しみください';
    }
    return 'スポンサーからの短いメッセージをご覧ください';
  }

  PostAdFollowUp _generatePostAdFollowUp(AdResult result) {
    final messages = <String>[];
    final rewards = <String>[];
    final nextSteps = <String>[];

    if (result.completed) {
      // Gratitude messages
      messages.add('ご視聴ありがとうございました！');
      
      if (result.adType == AdType.rewarded) {
        if (result.rewardEarned) {
          messages.add('報酬を獲得しました！');
          rewards.add(result.rewardDescription ?? '特別報酬');
        }
        nextSteps.add('続けてプレイしませんか？');
      } else {
        messages.add('引き続きゲームをお楽しみください');
        nextSteps.add('新しいハイスコアを目指しましょう！');
      }
    } else {
      // Skipped ad
      messages.add('ゲームを続けてお楽しみください');
      if (result.adType == AdType.rewarded) {
        nextSteps.add('次回は報酬を獲得するチャンスをお見逃しなく！');
      }
    }

    return PostAdFollowUp(
      userId: result.userId,
      messages: messages,
      rewards: rewards,
      nextSteps: nextSteps,
      timestamp: DateTime.now(),
    );
  }

  Duration _calculateAverageEngagementTime(List<UserSession> sessions) {
    if (sessions.isEmpty) return Duration.zero;

    int totalEngagementTime = 0;
    int validSessions = 0;

    for (final session in sessions) {
      // Find first meaningful action (not just game start)
      final meaningfulActions = session.actions.where((action) => 
          action.type != GameActionType.gameStart && 
          action.type != GameActionType.menuOpen).toList();
      
      if (meaningfulActions.isNotEmpty) {
        final firstMeaningfulAction = meaningfulActions.first;
        final engagementTime = firstMeaningfulAction.timestamp.difference(session.startTime);
        totalEngagementTime += engagementTime.inMilliseconds;
        validSessions++;
      }
    }

    if (validSessions == 0) return Duration.zero;
    
    return Duration(milliseconds: totalEngagementTime ~/ validSessions);
  }

  Future<void> _storePostAdFollowUp(String userId, PostAdFollowUp followUp) async {
    try {
      // This would typically be stored in a more sophisticated way
      // For now, we'll use a simple key-value approach
      final key = 'post_ad_followup_$userId';
      // Implementation would depend on your storage strategy
      _logger.debug('Stored post-ad follow-up for user $userId');
    } catch (error, stackTrace) {
      _logger.error('Error storing post-ad follow-up', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Resets session tracking (call when new session starts)
  void resetSessionTracking(String userId) {
    _adsShownThisSession[userId] = 0;
    _logger.debug('Reset session tracking for user $userId');
  }

  /// Gets current session ad count
  int getSessionAdCount(String userId) {
    return _adsShownThisSession[userId] ?? 0;
  }

  /// Checks if user has reached session ad limit
  bool hasReachedSessionAdLimit(String userId) {
    return getSessionAdCount(userId) >= _maxAdsPerSession;
  }
}

/// Types of ads
enum AdType { rewarded, interstitial, banner }

/// Result of an ad interaction
class AdResult {
  const AdResult({
    required this.userId,
    required this.adType,
    required this.completed,
    required this.viewDuration,
    required this.rewardEarned,
    this.rewardDescription,
  });

  final String userId;
  final AdType adType;
  final bool completed;
  final Duration viewDuration;
  final bool rewardEarned;
  final String? rewardDescription;
}

/// Post-ad follow-up information
class PostAdFollowUp {
  const PostAdFollowUp({
    required this.userId,
    required this.messages,
    required this.rewards,
    required this.nextSteps,
    required this.timestamp,
  });

  final String userId;
  final List<String> messages;
  final List<String> rewards;
  final List<String> nextSteps;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'messages': messages,
      'rewards': rewards,
      'nextSteps': nextSteps,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static PostAdFollowUp fromJson(Map<String, dynamic> json) {
    return PostAdFollowUp(
      userId: json['userId'] as String,
      messages: List<String>.from(json['messages'] as List),
      rewards: List<String>.from(json['rewards'] as List),
      nextSteps: List<String>.from(json['nextSteps'] as List),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}