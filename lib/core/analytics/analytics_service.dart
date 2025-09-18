import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../game/models/game_models.dart';
import 'analytics_events.dart';

/// Lightweight wrapper around [FirebaseAnalytics] that exposes
/// high-level logging helpers used across the game.
class AnalyticsService {
  AnalyticsService() : _analytics = FirebaseAnalytics.instance;

  AnalyticsService.fake() : _analytics = null;

  final FirebaseAnalytics? _analytics;

  bool get isEnabled => _analytics != null;

  Future<void> logGameStart({
    required String sessionId,
    required bool tutorialActive,
    required int revivesUnlocked,
    required double inkMultiplier,
    required int totalCoins,
    required bool missionsAvailable,
  }) async {
    await _logEvent(AnalyticsEventKeys.gameStart, {
      AnalyticsParamKeys.sessionId: sessionId,
      AnalyticsParamKeys.tutorialActive: tutorialActive,
      AnalyticsParamKeys.revivesUnlocked: revivesUnlocked,
      AnalyticsParamKeys.inkMultiplier:
          double.parse(inkMultiplier.toStringAsFixed(2)),
      AnalyticsParamKeys.totalCoins: totalCoins,
      AnalyticsParamKeys.missionsAvailable: missionsAvailable,
    });
  }

  Future<void> logGameEnd({
    required String sessionId,
    required RunStats stats,
    required int revivesUsed,
    required int totalCoins,
    required int missionsCompletedDelta,
  }) async {
    await _logEvent(AnalyticsEventKeys.gameEnd, {
      AnalyticsParamKeys.sessionId: sessionId,
      AnalyticsParamKeys.score: stats.score,
      AnalyticsParamKeys.duration: double.parse(
        (stats.duration.inMilliseconds / 1000).toStringAsFixed(2),
      ),
      AnalyticsParamKeys.durationMs: stats.duration.inMilliseconds,
      AnalyticsParamKeys.coinsGained: stats.coins,
      AnalyticsParamKeys.jumps: stats.jumpsPerformed,
      AnalyticsParamKeys.drawTimeMs: stats.drawTimeMs,
      AnalyticsParamKeys.usedLine: stats.usedLine,
      AnalyticsParamKeys.accidentDeath: stats.accidentDeath,
      AnalyticsParamKeys.revivesUsed: revivesUsed,
      AnalyticsParamKeys.missionsCompletedDelta: missionsCompletedDelta,
      AnalyticsParamKeys.totalCoins: totalCoins,
      AnalyticsParamKeys.nearMisses: stats.nearMisses,
      AnalyticsParamKeys.inkEfficiency:
          double.parse(stats.inkEfficiency.toStringAsFixed(3)),
    });
  }

  Future<void> logCoinsCollected({
    required int amount,
    required int totalCoins,
    String source = 'run',
  }) async {
    await _logEvent(AnalyticsEventKeys.coinsCollected, {
      AnalyticsParamKeys.amount: amount,
      AnalyticsParamKeys.totalCoins: totalCoins,
      AnalyticsParamKeys.source: source,
    });
  }

  Future<void> logAdWatched({
    required String placement,
    required String adType,
    required bool rewardEarned,
  }) async {
    await _logEvent(AnalyticsEventKeys.adWatched, {
      AnalyticsParamKeys.source: placement,
      AnalyticsParamKeys.adType: adType,
      AnalyticsParamKeys.rewardEarned: rewardEarned,
    });
  }

  Future<void> logAdShow({
    required String trigger,
    required String adType,
    required Duration elapsedSinceLast,
    List<String> policyBlockedFlags = const <String>[],
  }) async {
    final String flags = policyBlockedFlags.isEmpty
        ? 'none'
        : policyBlockedFlags.join('|');
    await _logEvent(AnalyticsEventKeys.adShow, {
      AnalyticsParamKeys.trigger: trigger,
      AnalyticsParamKeys.adType: adType,
      AnalyticsParamKeys.elapsedSinceLast: double.parse(
        (elapsedSinceLast.inMilliseconds / 1000).toStringAsFixed(2),
      ),
      AnalyticsParamKeys.policyBlockedFlags: flags,
    });
  }

  Future<void> logObstacleHit({
    required String obstacleType,
    required int score,
    required double elapsedSeconds,
  }) async {
    await _logEvent(AnalyticsEventKeys.obstacleHit, {
      AnalyticsParamKeys.obstacleType: obstacleType,
      AnalyticsParamKeys.score: score,
      AnalyticsParamKeys.elapsedSeconds:
          double.parse(elapsedSeconds.toStringAsFixed(2)),
    });
  }

  Future<void> logMissionComplete({
    required String missionId,
    required String missionType,
    required int reward,
  }) async {
    await _logEvent(AnalyticsEventKeys.missionComplete, {
      AnalyticsParamKeys.missionId: missionId,
      AnalyticsParamKeys.missionType: missionType,
      AnalyticsParamKeys.reward: reward,
    });
  }

  Future<void> _logEvent(String name, Map<String, Object?> parameters) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }
    final filtered = <String, Object>{};
    parameters.forEach((key, value) {
      if (value != null) {
        filtered[key] = value;
      }
    });
    try {
      await analytics.logEvent(name: name, parameters: filtered);
    } catch (error, stackTrace) {
      debugPrint('Failed to log analytics event "$name": $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
