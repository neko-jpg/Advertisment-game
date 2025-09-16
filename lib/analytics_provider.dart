import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'game_models.dart';

/// Lightweight wrapper around [FirebaseAnalytics] that exposes
/// high-level logging helpers used across the game.
class AnalyticsProvider {
  AnalyticsProvider() : _analytics = FirebaseAnalytics.instance;

  AnalyticsProvider.fake() : _analytics = null;

  final FirebaseAnalytics? _analytics;

  bool get isEnabled => _analytics != null;

  Future<void> logGameStart({
    required bool tutorialActive,
    required int revivesUnlocked,
    required double inkMultiplier,
    required int totalCoins,
    required bool missionsAvailable,
  }) async {
    await _logEvent('game_start', {
      'tutorial_active': tutorialActive,
      'revives_unlocked': revivesUnlocked,
      'ink_multiplier': double.parse(inkMultiplier.toStringAsFixed(2)),
      'total_coins': totalCoins,
      'missions_available': missionsAvailable,
    });
  }

  Future<void> logGameEnd({
    required RunStats stats,
    required int revivesUsed,
    required int totalCoins,
    required int missionsCompletedDelta,
  }) async {
    await _logEvent('game_end', {
      'score': stats.score,
      'duration_ms': stats.duration.inMilliseconds,
      'coins_gained': stats.coins,
      'jumps': stats.jumpsPerformed,
      'draw_time_ms': stats.drawTimeMs,
      'used_line': stats.usedLine,
      'accident_death': stats.accidentDeath,
      'revives_used': revivesUsed,
      'missions_completed_delta': missionsCompletedDelta,
      'total_coins': totalCoins,
    });
  }

  Future<void> logCoinsCollected({
    required int amount,
    required int totalCoins,
    String source = 'run',
  }) async {
    await _logEvent('coins_collected', {
      'amount': amount,
      'total_coins': totalCoins,
      'source': source,
    });
  }

  Future<void> logAdWatched({
    required String placement,
    required String adType,
    required bool rewardEarned,
  }) async {
    await _logEvent('ad_watched', {
      'placement': placement,
      'ad_type': adType,
      'reward_earned': rewardEarned,
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
