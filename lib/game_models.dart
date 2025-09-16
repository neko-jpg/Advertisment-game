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
