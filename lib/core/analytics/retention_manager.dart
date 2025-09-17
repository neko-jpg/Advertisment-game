import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/behavior_models.dart';
import 'player_behavior_analyzer.dart';
import '../../game/models/game_models.dart';

/// Manages user retention through personalized interventions
class RetentionManager {
  RetentionManager({
    required PlayerBehaviorAnalyzer behaviorAnalyzer,
    required SharedPreferences prefs,
  }) : _behaviorAnalyzer = behaviorAnalyzer, _prefs = prefs;

  final PlayerBehaviorAnalyzer _behaviorAnalyzer;
  final SharedPreferences _prefs;

  static const String _retentionActionsKey = 'retention_actions_';
  static const String _lastInterventionKey = 'last_intervention_';

  /// Detects if user is at risk of churning
  Future<bool> detectChurnRisk(UserBehaviorData behavior) async {
    try {
      final churnRisk = await _behaviorAnalyzer.predictChurnRisk(behavior.userId);
      return churnRisk.riskLevel == ChurnRiskLevel.high || 
             churnRisk.riskLevel == ChurnRiskLevel.critical;
    } catch (error, stackTrace) {
      debugPrint('Failed to detect churn risk: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Executes personalized retention strategy for a user
  Future<void> executePersonalizedRetention(String userId, ChurnRisk risk) async {
    try {
      // Check if we've already intervened recently
      final lastIntervention = await _getLastInterventionTime(userId);
      final now = DateTime.now();
      
      if (lastIntervention != null && 
          now.difference(lastIntervention).inHours < 24) {
        debugPrint('Skipping retention intervention - too recent');
        return;
      }

      // Generate personalized retention actions
      final actions = await _generateRetentionActions(userId, risk);
      
      // Execute actions
      for (final action in actions) {
        await _executeRetentionAction(userId, action);
      }

      // Record intervention
      await _recordIntervention(userId, actions);
      
      debugPrint('Executed ${actions.length} retention actions for user $userId');
    } catch (error, stackTrace) {
      debugPrint('Failed to execute personalized retention: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Adjusts game difficulty based on player performance
  void adjustDifficultyBasedOnPerformance(UserSession session) {
    try {
      final userId = session.userId;
      final performance = _analyzeSessionPerformance(session);
      
      // Get current difficulty settings
      final currentDifficulty = _getCurrentDifficultySettings(userId);
      
      // Calculate adjustments
      final adjustments = _calculateDifficultyAdjustments(performance, currentDifficulty);
      
      // Apply adjustments
      _applyDifficultyAdjustments(userId, adjustments);
      
      debugPrint('Adjusted difficulty for user $userId: $adjustments');
    } catch (error, stackTrace) {
      debugPrint('Failed to adjust difficulty: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Generates surprise rewards based on user profile
  Future<Reward> generateSurpriseReward(UserProfile profile) async {
    try {
      final behaviorPattern = await _behaviorAnalyzer.analyzeBehaviorPattern(profile.userId);
      return _calculateOptimalReward(profile, behaviorPattern);
    } catch (error, stackTrace) {
      debugPrint('Failed to generate surprise reward: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _getDefaultReward();
    }
  }

  /// Generates personalized retention actions based on churn risk
  Future<List<RetentionAction>> _generateRetentionActions(String userId, ChurnRisk risk) async {
    final actions = <RetentionAction>[];
    final behaviorPattern = await _behaviorAnalyzer.analyzeBehaviorPattern(userId);

    // High priority actions based on risk factors
    for (final factor in risk.primaryFactors) {
      switch (factor) {
        case 'long_absence':
          actions.add(RetentionAction(
            type: RetentionActionType.comebackNotification,
            priority: RetentionPriority.high,
            message: 'We miss you! Come back and claim your comeback bonus!',
            reward: ComebackReward(coins: 500, specialItem: 'Comeback Badge'),
            scheduledTime: DateTime.now().add(const Duration(hours: 2)),
          ));
          break;
          
        case 'recent_absence':
          actions.add(RetentionAction(
            type: RetentionActionType.dailyBonus,
            priority: RetentionPriority.medium,
            message: 'Your daily bonus is waiting!',
            reward: DailyBonusReward(coins: 200, streak: behaviorPattern.retentionIndicators.daysSinceLastPlay),
            scheduledTime: DateTime.now().add(const Duration(hours: 1)),
          ));
          break;
          
        case 'irregular_play_pattern':
          actions.add(RetentionAction(
            type: RetentionActionType.onboardingImprovement,
            priority: RetentionPriority.medium,
            message: 'Let us help you get better at the game!',
            reward: TutorialReward(coins: 100, skillBoost: true),
            scheduledTime: DateTime.now().add(const Duration(minutes: 30)),
          ));
          break;
          
        case 'slow_progression':
          actions.add(RetentionAction(
            type: RetentionActionType.difficultyAdjustment,
            priority: RetentionPriority.high,
            message: 'We\'ve made the game a bit easier for you!',
            reward: ProgressionReward(difficultyReduction: 0.2, temporaryBoost: true),
            scheduledTime: DateTime.now(),
          ));
          break;
          
        case 'incomplete_tutorial':
          actions.add(RetentionAction(
            type: RetentionActionType.tutorialImprovement,
            priority: RetentionPriority.high,
            message: 'Quick tutorial - master the game in 30 seconds!',
            reward: TutorialReward(coins: 150, skillBoost: true),
            scheduledTime: DateTime.now().add(const Duration(minutes: 15)),
          ));
          break;
          
        case 'low_monetization_engagement':
          actions.add(RetentionAction(
            type: RetentionActionType.adOptimization,
            priority: RetentionPriority.low,
            message: 'Watch this quick ad for bonus coins!',
            reward: AdReward(coins: 100, multiplier: 2.0),
            scheduledTime: DateTime.now().add(const Duration(hours: 4)),
          ));
          break;
          
        case 'no_social_engagement':
          actions.add(RetentionAction(
            type: RetentionActionType.socialPromotion,
            priority: RetentionPriority.low,
            message: 'Challenge your friends and earn rewards!',
            reward: SocialReward(coins: 300, friendBonus: true),
            scheduledTime: DateTime.now().add(const Duration(hours: 6)),
          ));
          break;
      }
    }

    // Sort by priority
    actions.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    
    // Limit to top 3 actions to avoid overwhelming user
    return actions.take(3).toList();
  }

  /// Executes a specific retention action
  Future<void> _executeRetentionAction(String userId, RetentionAction action) async {
    switch (action.type) {
      case RetentionActionType.comebackNotification:
        await _scheduleNotification(userId, action);
        break;
      case RetentionActionType.dailyBonus:
        await _activateDailyBonus(userId, action);
        break;
      case RetentionActionType.difficultyAdjustment:
        await _adjustDifficulty(userId, action);
        break;
      case RetentionActionType.onboardingImprovement:
        await _improveOnboarding(userId, action);
        break;
      case RetentionActionType.tutorialImprovement:
        await _improveTutorial(userId, action);
        break;
      case RetentionActionType.adOptimization:
        await _optimizeAds(userId, action);
        break;
      case RetentionActionType.socialPromotion:
        await _promoteSocial(userId, action);
        break;
    }
  }

  /// Analyzes session performance for difficulty adjustment
  SessionPerformance _analyzeSessionPerformance(UserSession session) {
    final actions = session.actions;
    final gameEndActions = actions.where((a) => a.type == GameActionType.gameEnd).toList();
    
    if (gameEndActions.isEmpty) {
      return SessionPerformance(
        score: 0,
        survivalTime: session.duration,
        deathsByAccident: true,
        consecutiveFailures: 1,
        skillImprovement: 0.0,
      );
    }

    final gameEndAction = gameEndActions.last;
    final score = (gameEndAction.metadata['score'] as num?)?.toInt() ?? 0;
    final accidentDeath = gameEndAction.metadata['accident_death'] as bool? ?? true;
    
    // Calculate consecutive failures (simplified)
    final recentFailures = _getRecentFailures(session.userId);
    
    return SessionPerformance(
      score: score,
      survivalTime: session.duration,
      deathsByAccident: accidentDeath,
      consecutiveFailures: recentFailures,
      skillImprovement: _calculateSkillImprovement(session.userId, score),
    );
  }

  /// Gets current difficulty settings for user
  DifficultySettings _getCurrentDifficultySettings(String userId) {
    final speedMultiplier = _prefs.getDouble('difficulty_speed_$userId') ?? 1.0;
    final densityMultiplier = _prefs.getDouble('difficulty_density_$userId') ?? 1.0;
    final safeWindow = _prefs.getDouble('difficulty_safe_window_$userId') ?? 180.0;
    
    return DifficultySettings(
      speedMultiplier: speedMultiplier,
      densityMultiplier: densityMultiplier,
      safeWindowPx: safeWindow,
    );
  }

  /// Calculates difficulty adjustments based on performance
  DifficultyAdjustments _calculateDifficultyAdjustments(
    SessionPerformance performance, 
    DifficultySettings current,
  ) {
    double speedAdjustment = 0.0;
    double densityAdjustment = 0.0;
    double safeWindowAdjustment = 0.0;

    // Adjust based on consecutive failures
    if (performance.consecutiveFailures >= 3) {
      speedAdjustment = -0.2; // Reduce speed by 20%
      densityAdjustment = -0.15; // Reduce density by 15%
      safeWindowAdjustment = 40.0; // Increase safe window
    } else if (performance.consecutiveFailures >= 2) {
      speedAdjustment = -0.1;
      densityAdjustment = -0.1;
      safeWindowAdjustment = 20.0;
    }

    // Adjust based on survival time
    if (performance.survivalTime.inSeconds < 20) {
      speedAdjustment -= 0.1;
      safeWindowAdjustment += 20.0;
    }

    // Adjust based on skill improvement
    if (performance.skillImprovement > 0.2) {
      speedAdjustment += 0.05; // Increase difficulty if improving
      densityAdjustment += 0.05;
    }

    return DifficultyAdjustments(
      speedMultiplierDelta: speedAdjustment,
      densityMultiplierDelta: densityAdjustment,
      safeWindowPxDelta: safeWindowAdjustment,
    );
  }

  /// Applies difficulty adjustments
  void _applyDifficultyAdjustments(String userId, DifficultyAdjustments adjustments) {
    final current = _getCurrentDifficultySettings(userId);
    
    final newSpeed = (current.speedMultiplier + adjustments.speedMultiplierDelta)
        .clamp(0.5, 2.0);
    final newDensity = (current.densityMultiplier + adjustments.densityMultiplierDelta)
        .clamp(0.3, 2.5);
    final newSafeWindow = (current.safeWindowPx + adjustments.safeWindowPxDelta)
        .clamp(120.0, 300.0);

    _prefs.setDouble('difficulty_speed_$userId', newSpeed);
    _prefs.setDouble('difficulty_density_$userId', newDensity);
    _prefs.setDouble('difficulty_safe_window_$userId', newSafeWindow);
  }

  /// Calculates optimal reward based on user profile and behavior
  Reward _calculateOptimalReward(UserProfile profile, BehaviorPattern pattern) {
    final baseCoins = 100;
    final multiplier = _calculateRewardMultiplier(profile, pattern);
    
    return Reward(
      type: RewardType.surprise,
      coins: (baseCoins * multiplier).round(),
      specialItem: _selectSpecialItem(pattern),
      message: _generateRewardMessage(pattern),
    );
  }

  /// Calculates reward multiplier based on user engagement
  double _calculateRewardMultiplier(UserProfile profile, BehaviorPattern pattern) {
    double multiplier = 1.0;
    
    // Reward consistent players
    if (pattern.retentionIndicators.sessionConsistency > 0.7) {
      multiplier += 0.5;
    }
    
    // Reward progressing players
    if (pattern.retentionIndicators.progressionRate > 0.5) {
      multiplier += 0.3;
    }
    
    // Reward social engagement
    if (pattern.retentionIndicators.socialEngagement > 0.1) {
      multiplier += 0.2;
    }
    
    return multiplier.clamp(1.0, 3.0);
  }

  /// Selects special item based on behavior pattern
  String? _selectSpecialItem(BehaviorPattern pattern) {
    if (pattern.retentionIndicators.sessionConsistency > 0.8) {
      return 'Consistency Crown';
    } else if (pattern.retentionIndicators.progressionRate > 0.7) {
      return 'Progress Star';
    } else if (pattern.retentionIndicators.socialEngagement > 0.2) {
      return 'Social Butterfly Badge';
    }
    return null;
  }

  /// Generates personalized reward message
  String _generateRewardMessage(BehaviorPattern pattern) {
    if (pattern.retentionIndicators.sessionConsistency > 0.7) {
      return 'Amazing consistency! Here\'s a special reward for your dedication!';
    } else if (pattern.retentionIndicators.progressionRate > 0.5) {
      return 'You\'re improving so fast! Keep up the great work!';
    } else {
      return 'Thanks for playing! Here\'s a little something for you!';
    }
  }

  /// Gets default reward for error cases
  Reward _getDefaultReward() {
    return const Reward(
      type: RewardType.surprise,
      coins: 100,
      specialItem: null,
      message: 'Thanks for playing!',
    );
  }

  /// Helper methods for retention actions
  Future<void> _scheduleNotification(String userId, RetentionAction action) async {
    // In a real implementation, this would integrate with push notifications
    debugPrint('Scheduled notification for $userId: ${action.message}');
  }

  Future<void> _activateDailyBonus(String userId, RetentionAction action) async {
    // Activate daily bonus in user's account
    debugPrint('Activated daily bonus for $userId');
  }

  Future<void> _adjustDifficulty(String userId, RetentionAction action) async {
    if (action.reward is ProgressionReward) {
      final reward = action.reward as ProgressionReward;
      final current = _getCurrentDifficultySettings(userId);
      
      final newSpeed = current.speedMultiplier * (1.0 - reward.difficultyReduction);
      _prefs.setDouble('difficulty_speed_$userId', newSpeed);
    }
  }

  Future<void> _improveOnboarding(String userId, RetentionAction action) async {
    // Flag user for improved onboarding experience
    await _prefs.setBool('improved_onboarding_$userId', true);
  }

  Future<void> _improveTutorial(String userId, RetentionAction action) async {
    // Flag user for improved tutorial experience
    await _prefs.setBool('improved_tutorial_$userId', true);
  }

  Future<void> _optimizeAds(String userId, RetentionAction action) async {
    // Adjust ad frequency and placement
    await _prefs.setDouble('ad_frequency_multiplier_$userId', 0.8);
  }

  Future<void> _promoteSocial(String userId, RetentionAction action) async {
    // Flag user for social feature promotion
    await _prefs.setBool('promote_social_$userId', true);
  }

  /// Gets recent failure count for user
  int _getRecentFailures(String userId) {
    return _prefs.getInt('recent_failures_$userId') ?? 0;
  }

  /// Calculates skill improvement based on recent scores
  double _calculateSkillImprovement(String userId, int currentScore) {
    final recentScores = _getRecentScores(userId);
    if (recentScores.length < 2) return 0.0;
    
    final avgRecent = recentScores.take(recentScores.length ~/ 2)
        .fold(0.0, (sum, score) => sum + score) / (recentScores.length ~/ 2);
    final avgOlder = recentScores.skip(recentScores.length ~/ 2)
        .fold(0.0, (sum, score) => sum + score) / (recentScores.length - recentScores.length ~/ 2);
    
    return avgOlder > 0 ? (avgRecent - avgOlder) / avgOlder : 0.0;
  }

  /// Gets recent scores for user
  List<double> _getRecentScores(String userId) {
    final scoresString = _prefs.getString('recent_scores_$userId') ?? '';
    if (scoresString.isEmpty) return [];
    
    return scoresString.split(',')
        .map((s) => double.tryParse(s) ?? 0.0)
        .toList();
  }

  /// Records intervention for tracking
  Future<void> _recordIntervention(String userId, List<RetentionAction> actions) async {
    await _prefs.setString('$_lastInterventionKey$userId', DateTime.now().toIso8601String());
    
    final actionTypes = actions.map((a) => a.type.name).join(',');
    await _prefs.setString('$_retentionActionsKey$userId', actionTypes);
  }

  /// Gets last intervention time
  Future<DateTime?> _getLastInterventionTime(String userId) async {
    final timeString = _prefs.getString('$_lastInterventionKey$userId');
    return timeString != null ? DateTime.parse(timeString) : null;
  }
}

/// Represents a retention action to be taken
class RetentionAction {
  const RetentionAction({
    required this.type,
    required this.priority,
    required this.message,
    required this.reward,
    required this.scheduledTime,
  });

  final RetentionActionType type;
  final RetentionPriority priority;
  final String message;
  final dynamic reward;
  final DateTime scheduledTime;
}

enum RetentionActionType {
  comebackNotification,
  dailyBonus,
  difficultyAdjustment,
  onboardingImprovement,
  tutorialImprovement,
  adOptimization,
  socialPromotion,
}

enum RetentionPriority { low, medium, high }

/// Session performance analysis
class SessionPerformance {
  const SessionPerformance({
    required this.score,
    required this.survivalTime,
    required this.deathsByAccident,
    required this.consecutiveFailures,
    required this.skillImprovement,
  });

  final int score;
  final Duration survivalTime;
  final bool deathsByAccident;
  final int consecutiveFailures;
  final double skillImprovement;
}

/// Current difficulty settings
class DifficultySettings {
  const DifficultySettings({
    required this.speedMultiplier,
    required this.densityMultiplier,
    required this.safeWindowPx,
  });

  final double speedMultiplier;
  final double densityMultiplier;
  final double safeWindowPx;
}

/// Difficulty adjustments to apply
class DifficultyAdjustments {
  const DifficultyAdjustments({
    required this.speedMultiplierDelta,
    required this.densityMultiplierDelta,
    required this.safeWindowPxDelta,
  });

  final double speedMultiplierDelta;
  final double densityMultiplierDelta;
  final double safeWindowPxDelta;

  @override
  String toString() {
    return 'DifficultyAdjustments(speed: $speedMultiplierDelta, density: $densityMultiplierDelta, safeWindow: $safeWindowPxDelta)';
  }
}

/// User profile for retention analysis
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.firstPlayDate,
    required this.totalPlayTime,
    required this.skillLevel,
    required this.achievements,
    required this.spendingProfile,
    required this.behaviorMetrics,
    required this.retentionRisk,
  });

  final String userId;
  final DateTime firstPlayDate;
  final Duration totalPlayTime;
  final SkillLevel skillLevel;
  final List<Achievement> achievements;
  final SpendingProfile spendingProfile;
  final BehaviorMetrics behaviorMetrics;
  final RetentionRisk retentionRisk;
}

enum SkillLevel { beginner, intermediate, advanced, expert }

class Achievement {
  const Achievement({required this.id, required this.name, required this.unlockedAt});
  final String id;
  final String name;
  final DateTime unlockedAt;
}

class SpendingProfile {
  const SpendingProfile({required this.totalSpent, required this.averageTransactionValue});
  final double totalSpent;
  final double averageTransactionValue;
}

class BehaviorMetrics {
  const BehaviorMetrics({required this.averageSessionLength, required this.dailyPlayFrequency});
  final Duration averageSessionLength;
  final double dailyPlayFrequency;
}

class RetentionRisk {
  const RetentionRisk({required this.level, required this.factors});
  final ChurnRiskLevel level;
  final List<String> factors;
}

/// Reward types and implementations
class Reward {
  const Reward({
    required this.type,
    required this.coins,
    required this.specialItem,
    required this.message,
  });

  final RewardType type;
  final int coins;
  final String? specialItem;
  final String message;
}

enum RewardType { surprise, comeback, daily, progression, tutorial, ad, social }

class ComebackReward {
  const ComebackReward({required this.coins, required this.specialItem});
  final int coins;
  final String specialItem;
}

class DailyBonusReward {
  const DailyBonusReward({required this.coins, required this.streak});
  final int coins;
  final int streak;
}

class TutorialReward {
  const TutorialReward({required this.coins, required this.skillBoost});
  final int coins;
  final bool skillBoost;
}

class ProgressionReward {
  const ProgressionReward({required this.difficultyReduction, required this.temporaryBoost});
  final double difficultyReduction;
  final bool temporaryBoost;
}

class AdReward {
  const AdReward({required this.coins, required this.multiplier});
  final int coins;
  final double multiplier;
}

class SocialReward {
  const SocialReward({required this.coins, required this.friendBonus});
  final int coins;
  final bool friendBonus;
}