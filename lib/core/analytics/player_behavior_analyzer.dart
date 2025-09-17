import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/behavior_models.dart';
import '../../game/models/game_models.dart';

/// Analyzes player behavior patterns and predicts churn risk
class PlayerBehaviorAnalyzer {
  PlayerBehaviorAnalyzer({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  final SharedPreferences _prefs;
  final Map<String, UserBehaviorData> _behaviorCache = {};
  final Map<String, BehaviorPattern> _patternCache = {};

  static const String _behaviorDataKey = 'behavior_data_';
  static const String _patternDataKey = 'pattern_data_';
  static const String _currentSessionKey = 'current_session_';

  /// Records a game action for behavior analysis
  Future<void> recordAction(GameAction action) async {
    try {
      final behaviorData = await _getUserBehaviorData(action.sessionId.split('_').first);
      
      // Add action to current session
      final currentSession = await _getCurrentSession(action.sessionId);
      if (currentSession != null) {
        final updatedSession = UserSession(
          sessionId: currentSession.sessionId,
          userId: currentSession.userId,
          startTime: currentSession.startTime,
          endTime: currentSession.endTime,
          actions: [...currentSession.actions, action],
          deviceInfo: currentSession.deviceInfo,
          crashOccurred: currentSession.crashOccurred,
        );
        await _saveCurrentSession(updatedSession);
      }

      // Update behavior data cache
      _behaviorCache[behaviorData.userId] = behaviorData;
      
    } catch (error, stackTrace) {
      debugPrint('Failed to record action: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Starts a new user session
  Future<UserSession> startSession(String userId, DeviceInfo deviceInfo) async {
    final sessionId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final session = UserSession(
      sessionId: sessionId,
      userId: userId,
      startTime: DateTime.now(),
      endTime: null,
      actions: [],
      deviceInfo: deviceInfo,
    );

    await _saveCurrentSession(session);
    return session;
  }

  /// Ends the current user session
  Future<void> endSession(String sessionId) async {
    try {
      final session = await _getCurrentSession(sessionId);
      if (session != null) {
        final endedSession = UserSession(
          sessionId: session.sessionId,
          userId: session.userId,
          startTime: session.startTime,
          endTime: DateTime.now(),
          actions: session.actions,
          deviceInfo: session.deviceInfo,
          crashOccurred: session.crashOccurred,
        );

        // Save completed session to behavior data
        await _addSessionToBehaviorData(endedSession);
        
        // Clear current session
        await _prefs.remove('$_currentSessionKey$sessionId');
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to end session: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Analyzes behavior pattern for a user
  Future<BehaviorPattern> analyzeBehaviorPattern(String userId) async {
    try {
      // Check cache first
      if (_patternCache.containsKey(userId)) {
        final cached = _patternCache[userId]!;
        if (DateTime.now().difference(cached.lastUpdated).inHours < 1) {
          return cached;
        }
      }

      final behaviorData = await _getUserBehaviorData(userId);
      final pattern = await _calculateBehaviorPattern(behaviorData);
      
      // Cache and save pattern
      _patternCache[userId] = pattern;
      await _saveBehaviorPattern(pattern);
      
      return pattern;
    } catch (error, stackTrace) {
      debugPrint('Failed to analyze behavior pattern: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _getDefaultBehaviorPattern(userId);
    }
  }

  /// Predicts churn probability for a user
  Future<ChurnRisk> predictChurnRisk(String userId) async {
    try {
      final pattern = await analyzeBehaviorPattern(userId);
      return _calculateChurnRisk(pattern);
    } catch (error, stackTrace) {
      debugPrint('Failed to predict churn risk: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const ChurnRisk(
        riskLevel: ChurnRiskLevel.low,
        probability: 0.1,
        primaryFactors: ['insufficient_data'],
        recommendedActions: ['collect_more_data'],
      );
    }
  }

  /// Detects if user is at risk of churning
  Future<bool> detectChurnRisk(UserBehaviorData behavior) async {
    final churnRisk = await predictChurnRisk(behavior.userId);
    return churnRisk.riskLevel == ChurnRiskLevel.high || 
           churnRisk.riskLevel == ChurnRiskLevel.critical;
  }

  /// Gets user behavior data
  Future<UserBehaviorData> _getUserBehaviorData(String userId) async {
    if (_behaviorCache.containsKey(userId)) {
      return _behaviorCache[userId]!;
    }

    final dataJson = _prefs.getString('$_behaviorDataKey$userId');
    if (dataJson != null) {
      final data = UserBehaviorData.fromJson(json.decode(dataJson) as Map<String, dynamic>);
      _behaviorCache[userId] = data;
      return data;
    }

    // Create new behavior data
    final newData = UserBehaviorData(
      userId: userId,
      sessions: [],
      totalPlayTime: Duration.zero,
      averageScore: 0.0,
      purchaseHistory: [],
      adInteractions: [],
      socialActions: [],
      lastActiveDate: DateTime.now(),
    );
    
    _behaviorCache[userId] = newData;
    return newData;
  }

  /// Gets current session
  Future<UserSession?> _getCurrentSession(String sessionId) async {
    final sessionJson = _prefs.getString('$_currentSessionKey$sessionId');
    if (sessionJson != null) {
      return UserSession.fromJson(json.decode(sessionJson) as Map<String, dynamic>);
    }
    return null;
  }

  /// Saves current session
  Future<void> _saveCurrentSession(UserSession session) async {
    await _prefs.setString(
      '$_currentSessionKey${session.sessionId}',
      json.encode(session.toJson()),
    );
  }

  /// Adds completed session to behavior data
  Future<void> _addSessionToBehaviorData(UserSession session) async {
    final behaviorData = await _getUserBehaviorData(session.userId);
    
    final updatedData = UserBehaviorData(
      userId: behaviorData.userId,
      sessions: [...behaviorData.sessions, session],
      totalPlayTime: behaviorData.totalPlayTime + session.duration,
      averageScore: _calculateAverageScore([...behaviorData.sessions, session]),
      purchaseHistory: behaviorData.purchaseHistory,
      adInteractions: behaviorData.adInteractions,
      socialActions: behaviorData.socialActions,
      lastActiveDate: session.endTime ?? DateTime.now(),
    );

    _behaviorCache[session.userId] = updatedData;
    await _prefs.setString(
      '$_behaviorDataKey${session.userId}',
      json.encode(updatedData.toJson()),
    );
  }

  /// Calculates behavior pattern from behavior data
  Future<BehaviorPattern> _calculateBehaviorPattern(UserBehaviorData data) async {
    final sessions = data.sessions;
    if (sessions.isEmpty) {
      return _getDefaultBehaviorPattern(data.userId);
    }

    // Calculate average session length
    final avgSessionLength = data.averageSessionLength;

    // Calculate daily play frequency
    final daysSinceFirst = DateTime.now().difference(sessions.first.startTime).inDays;
    final dailyFrequency = daysSinceFirst > 0 ? sessions.length / daysSinceFirst : 1.0;

    // Analyze common actions
    final actionCounts = <GameActionType, int>{};
    for (final session in sessions) {
      for (final action in session.actions) {
        actionCounts[action.type] = (actionCounts[action.type] ?? 0) + 1;
      }
    }

    // Calculate feature usage rates
    final featureUsage = <String, double>{};
    final totalActions = actionCounts.values.fold(0, (sum, count) => sum + count);
    if (totalActions > 0) {
      featureUsage['drawing'] = (actionCounts[GameActionType.draw] ?? 0) / totalActions;
      featureUsage['jumping'] = (actionCounts[GameActionType.jump] ?? 0) / totalActions;
      featureUsage['ads'] = (actionCounts[GameActionType.adView] ?? 0) / totalActions;
      featureUsage['purchases'] = (actionCounts[GameActionType.purchase] ?? 0) / totalActions;
      featureUsage['social'] = (actionCounts[GameActionType.socialShare] ?? 0) / totalActions;
    }

    // Calculate play time distribution
    final playTimeDistribution = <int, double>{};
    for (final session in sessions) {
      final hour = session.startTime.hour;
      playTimeDistribution[hour] = (playTimeDistribution[hour] ?? 0) + 1;
    }
    
    // Normalize distribution
    final totalSessions = sessions.length.toDouble();
    playTimeDistribution.updateAll((key, value) => value / totalSessions);

    // Calculate retention indicators
    final retentionIndicators = _calculateRetentionIndicators(data);

    return BehaviorPattern(
      userId: data.userId,
      averageSessionLength: avgSessionLength,
      dailyPlayFrequency: dailyFrequency,
      commonActions: actionCounts,
      featureUsageRates: featureUsage,
      playTimeDistribution: playTimeDistribution,
      retentionIndicators: retentionIndicators,
      lastUpdated: DateTime.now(),
    );
  }

  /// Calculates retention indicators
  RetentionIndicators _calculateRetentionIndicators(UserBehaviorData data) {
    final sessions = data.sessions;
    if (sessions.isEmpty) {
      return const RetentionIndicators(
        sessionConsistency: 0.0,
        progressionRate: 0.0,
        socialEngagement: 0.0,
        monetizationEngagement: 0.0,
        tutorialCompletion: 0.0,
        daysSinceLastPlay: 999,
      );
    }

    // Session consistency (how regular are play sessions)
    final sessionGaps = <int>[];
    for (int i = 1; i < sessions.length; i++) {
      final gap = sessions[i].startTime.difference(sessions[i-1].startTime).inDays;
      sessionGaps.add(gap);
    }
    
    final avgGap = sessionGaps.isNotEmpty 
        ? sessionGaps.reduce((a, b) => a + b) / sessionGaps.length 
        : 1.0;
    final sessionConsistency = max(0.0, 1.0 - (avgGap - 1.0) / 7.0); // Normalize to 0-1

    // Progression rate (improvement in scores over time)
    final scores = sessions.map((s) => s.actions
        .where((a) => a.type == GameActionType.gameEnd)
        .map((a) => (a.metadata['score'] as num?)?.toDouble() ?? 0.0)
        .fold(0.0, max)).toList();
    
    double progressionRate = 0.5; // Default
    if (scores.length >= 2) {
      final firstHalf = scores.take(scores.length ~/ 2).fold(0.0, (a, b) => a + b) / (scores.length ~/ 2);
      final secondHalf = scores.skip(scores.length ~/ 2).fold(0.0, (a, b) => a + b) / (scores.length - scores.length ~/ 2);
      progressionRate = secondHalf > firstHalf ? min(1.0, (secondHalf - firstHalf) / firstHalf) : 0.0;
    }

    // Social engagement
    final totalActions = sessions.fold(0, (sum, s) => sum + s.actions.length);
    final socialActions = sessions.fold(0, (sum, s) => 
        sum + s.actions.where((a) => a.type == GameActionType.socialShare).length);
    final socialEngagement = totalActions > 0 ? socialActions / totalActions : 0.0;

    // Monetization engagement
    final adActions = sessions.fold(0, (sum, s) => 
        sum + s.actions.where((a) => a.type == GameActionType.adView).length);
    final purchaseActions = sessions.fold(0, (sum, s) => 
        sum + s.actions.where((a) => a.type == GameActionType.purchase).length);
    final monetizationEngagement = totalActions > 0 
        ? (adActions + purchaseActions * 5) / totalActions // Weight purchases higher
        : 0.0;

    // Tutorial completion
    final tutorialActions = sessions.fold(0, (sum, s) => 
        sum + s.actions.where((a) => a.type == GameActionType.tutorialStep).length);
    final tutorialCompletion = min(1.0, tutorialActions / 5.0); // Assume 5 tutorial steps

    return RetentionIndicators(
      sessionConsistency: sessionConsistency,
      progressionRate: progressionRate,
      socialEngagement: socialEngagement,
      monetizationEngagement: monetizationEngagement,
      tutorialCompletion: tutorialCompletion,
      daysSinceLastPlay: data.daysSinceLastActive,
    );
  }

  /// Calculates churn risk based on behavior pattern
  ChurnRisk _calculateChurnRisk(BehaviorPattern pattern) {
    final indicators = pattern.retentionIndicators;
    final factors = <String>[];
    final actions = <String>[];
    
    // Calculate risk score (0-1)
    double riskScore = 0.0;
    
    // Days since last play (high weight)
    if (indicators.daysSinceLastPlay > 7) {
      riskScore += 0.4;
      factors.add('long_absence');
      actions.add('send_comeback_notification');
    } else if (indicators.daysSinceLastPlay > 3) {
      riskScore += 0.2;
      factors.add('recent_absence');
      actions.add('offer_daily_bonus');
    }
    
    // Session consistency
    if (indicators.sessionConsistency < 0.3) {
      riskScore += 0.2;
      factors.add('irregular_play_pattern');
      actions.add('improve_onboarding');
    }
    
    // Progression rate
    if (indicators.progressionRate < 0.2) {
      riskScore += 0.15;
      factors.add('slow_progression');
      actions.add('adjust_difficulty');
    }
    
    // Tutorial completion
    if (indicators.tutorialCompletion < 0.8) {
      riskScore += 0.1;
      factors.add('incomplete_tutorial');
      actions.add('improve_tutorial_flow');
    }
    
    // Monetization engagement
    if (indicators.monetizationEngagement < 0.1) {
      riskScore += 0.1;
      factors.add('low_monetization_engagement');
      actions.add('optimize_ad_placement');
    }
    
    // Social engagement
    if (indicators.socialEngagement < 0.05) {
      riskScore += 0.05;
      factors.add('no_social_engagement');
      actions.add('promote_social_features');
    }

    // Determine risk level
    ChurnRiskLevel riskLevel;
    if (riskScore >= 0.7) {
      riskLevel = ChurnRiskLevel.critical;
    } else if (riskScore >= 0.5) {
      riskLevel = ChurnRiskLevel.high;
    } else if (riskScore >= 0.3) {
      riskLevel = ChurnRiskLevel.medium;
    } else {
      riskLevel = ChurnRiskLevel.low;
    }

    return ChurnRisk(
      riskLevel: riskLevel,
      probability: riskScore,
      primaryFactors: factors,
      recommendedActions: actions,
    );
  }

  /// Calculates average score from sessions
  double _calculateAverageScore(List<UserSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    
    final scores = <double>[];
    for (final session in sessions) {
      for (final action in session.actions) {
        if (action.type == GameActionType.gameEnd) {
          final score = (action.metadata['score'] as num?)?.toDouble() ?? 0.0;
          if (score > 0) scores.add(score);
        }
      }
    }
    
    return scores.isNotEmpty 
        ? scores.reduce((a, b) => a + b) / scores.length 
        : 0.0;
  }

  /// Gets default behavior pattern for new users
  BehaviorPattern _getDefaultBehaviorPattern(String userId) {
    return BehaviorPattern(
      userId: userId,
      averageSessionLength: const Duration(minutes: 2),
      dailyPlayFrequency: 0.5,
      commonActions: const {},
      featureUsageRates: const {},
      playTimeDistribution: const {},
      retentionIndicators: const RetentionIndicators(
        sessionConsistency: 0.5,
        progressionRate: 0.5,
        socialEngagement: 0.0,
        monetizationEngagement: 0.0,
        tutorialCompletion: 0.0,
        daysSinceLastPlay: 0,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  /// Saves behavior pattern to storage
  Future<void> _saveBehaviorPattern(BehaviorPattern pattern) async {
    await _prefs.setString(
      '$_patternDataKey${pattern.userId}',
      json.encode(pattern.toJson()),
    );
  }

  /// Clears old data to prevent storage bloat
  Future<void> cleanupOldData() async {
    try {
      final keys = _prefs.getKeys();
      final now = DateTime.now();
      
      for (final key in keys) {
        if (key.startsWith(_behaviorDataKey) || key.startsWith(_patternDataKey)) {
          final dataJson = _prefs.getString(key);
          if (dataJson != null) {
            final data = json.decode(dataJson) as Map<String, dynamic>;
            final lastUpdated = DateTime.parse(data['lastUpdated'] as String? ?? data['lastActiveDate'] as String);
            
            // Remove data older than 90 days
            if (now.difference(lastUpdated).inDays > 90) {
              await _prefs.remove(key);
            }
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to cleanup old data: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}