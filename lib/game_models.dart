import 'dart:convert';

import 'package:flutter/material.dart';

/// Lightweight stats captured at the end of each run. Used for
/// dynamic difficulty adjustment, analytics and meta progression.
class RunStats {
  const RunStats({
    required this.duration,
    required this.score,
    required this.coins,
    required this.usedLine,
    required this.jumpsPerformed,
    required this.drawTimeMs,
    required this.accidentDeath,
  });

  final Duration duration;
  final int score;
  final int coins;
  final bool usedLine;
  final int jumpsPerformed;
  final int drawTimeMs;
  final bool accidentDeath;
}

/// Types of upgrades that can be permanently purchased with coins.
enum UpgradeType { inkRegen, revive, coyote }

class UpgradeDefinition {
  const UpgradeDefinition({
    required this.type,
    required this.maxLevel,
    required this.baseCost,
    required this.costGrowth,
    required this.displayName,
    required this.descriptionBuilder,
  });

  final UpgradeType type;
  final int maxLevel;
  final int baseCost;
  final int costGrowth;
  final String displayName;
  final String Function(int level) descriptionBuilder;
}

enum MissionType { collectCoins, surviveTime, drawTime, jumpCount }

class DailyMission {
  DailyMission({
    required this.id,
    required this.type,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.completed = false,
    this.claimed = false,
  });

  final String id;
  final MissionType type;
  final int target;
  final int reward;
  int progress;
  bool completed;
  bool claimed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'target': target,
      'reward': reward,
      'progress': progress,
      'completed': completed,
      'claimed': claimed,
    };
  }

  static DailyMission fromJson(Map<String, dynamic> json) {
    return DailyMission(
      id: json['id'] as String,
      type: MissionType.values[json['type'] as int],
      target: json['target'] as int,
      reward: json['reward'] as int,
      progress: json['progress'] as int,
      completed: json['completed'] as bool,
      claimed: json['claimed'] as bool? ?? false,
    );
  }
}

class LoginRewardState {
  const LoginRewardState({
    required this.streak,
    required this.nextClaim,
  });

  final int streak;
  final DateTime nextClaim;
}

class GachaResult {
  const GachaResult({
    required this.rewardId,
    required this.displayName,
    required this.wasGuaranteed,
  });

  final String rewardId;
  final String displayName;
  final bool wasGuaranteed;
}

class AdRemoteConfig {
  const AdRemoteConfig({
    required this.interstitialCooldown,
    required this.minimumRunDuration,
    required this.minimumRunsBeforeInterstitial,
  });

  final Duration interstitialCooldown;
  final Duration minimumRunDuration;
  final int minimumRunsBeforeInterstitial;

  Map<String, dynamic> toJson() {
    return {
      'interstitialCooldown': interstitialCooldown.inMilliseconds,
      'minimumRunDuration': minimumRunDuration.inMilliseconds,
      'minimumRunsBeforeInterstitial': minimumRunsBeforeInterstitial,
    };
  }

  static AdRemoteConfig fromJson(String source) {
    final map = json.decode(source) as Map<String, dynamic>;
    return AdRemoteConfig(
      interstitialCooldown:
          Duration(milliseconds: map['interstitialCooldown'] as int),
      minimumRunDuration:
          Duration(milliseconds: map['minimumRunDuration'] as int),
      minimumRunsBeforeInterstitial:
          map['minimumRunsBeforeInterstitial'] as int,
    );
  }
}

@immutable
class UpgradeSnapshot {
  const UpgradeSnapshot({
    required this.inkRegenMultiplier,
    required this.maxRevives,
    required this.coyoteBonusMs,
  });

  final double inkRegenMultiplier;
  final int maxRevives;
  final double coyoteBonusMs;
}

class DifficultyRemoteConfig {
  const DifficultyRemoteConfig({
    required this.baseSpeedMultiplier,
    required this.speedRampIntervalScore,
    required this.speedRampIncrease,
    required this.maxSpeedMultiplier,
    required this.targetSessionSeconds,
    required this.tutorialSafeWindowMs,
    required this.emergencyInkFloor,
  });

  final double baseSpeedMultiplier;
  final int speedRampIntervalScore;
  final double speedRampIncrease;
  final double maxSpeedMultiplier;
  final int targetSessionSeconds;
  final int tutorialSafeWindowMs;
  final double emergencyInkFloor;

  Map<String, dynamic> toJson() {
    return {
      'baseSpeedMultiplier': baseSpeedMultiplier,
      'speedRampIntervalScore': speedRampIntervalScore,
      'speedRampIncrease': speedRampIncrease,
      'maxSpeedMultiplier': maxSpeedMultiplier,
      'targetSessionSeconds': targetSessionSeconds,
      'tutorialSafeWindowMs': tutorialSafeWindowMs,
      'emergencyInkFloor': emergencyInkFloor,
    };
  }

  static DifficultyRemoteConfig fromJson(String source) {
    if (source.isEmpty) {
      return const DifficultyRemoteConfig(
        baseSpeedMultiplier: 1.0,
        speedRampIntervalScore: 380,
        speedRampIncrease: 0.35,
        maxSpeedMultiplier: 2.2,
        targetSessionSeconds: 50,
        tutorialSafeWindowMs: 30000,
        emergencyInkFloor: 14,
      );
    }
    final map = json.decode(source) as Map<String, dynamic>;
    return DifficultyRemoteConfig(
      baseSpeedMultiplier:
          (map['baseSpeedMultiplier'] as num?)?.toDouble() ?? 1.0,
      speedRampIntervalScore: map['speedRampIntervalScore'] as int? ?? 380,
      speedRampIncrease: (map['speedRampIncrease'] as num?)?.toDouble() ?? 0.35,
      maxSpeedMultiplier: (map['maxSpeedMultiplier'] as num?)?.toDouble() ?? 2.2,
      targetSessionSeconds: map['targetSessionSeconds'] as int? ?? 50,
      tutorialSafeWindowMs: map['tutorialSafeWindowMs'] as int? ?? 30000,
      emergencyInkFloor: (map['emergencyInkFloor'] as num?)?.toDouble() ?? 14,
    );
  }
}

class GameToast {
  const GameToast({
    required this.message,
    required this.icon,
    required this.color,
    this.duration = const Duration(seconds: 2),
  });

  final String message;
  final IconData icon;
  final Color color;
  final Duration duration;
}

class RunBoost {
  const RunBoost({
    required this.coinMultiplier,
    required this.inkRegenMultiplier,
    required this.duration,
  });

  final double coinMultiplier;
  final double inkRegenMultiplier;
  final Duration duration;
}
