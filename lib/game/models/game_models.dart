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
    required this.nearMisses,
    required this.inkEfficiency,
  });

  final Duration duration;
  final int score;
  final int coins;
  final bool usedLine;
  final int jumpsPerformed;
  final int drawTimeMs;
  final bool accidentDeath;
  final int nearMisses;
  final double inkEfficiency;
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

  UpgradeDefinition copyWith({int? maxLevel, int? baseCost, int? costGrowth}) {
    return UpgradeDefinition(
      type: type,
      maxLevel: maxLevel ?? this.maxLevel,
      baseCost: baseCost ?? this.baseCost,
      costGrowth: costGrowth ?? this.costGrowth,
      displayName: displayName,
      descriptionBuilder: descriptionBuilder,
    );
  }
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
  const LoginRewardState({required this.streak, required this.nextClaim});

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
      interstitialCooldown: Duration(
        milliseconds: map['interstitialCooldown'] as int,
      ),
      minimumRunDuration: Duration(
        milliseconds: map['minimumRunDuration'] as int,
      ),
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
      maxSpeedMultiplier:
          (map['maxSpeedMultiplier'] as num?)?.toDouble() ?? 2.2,
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

class DifficultyTuningRemoteConfig {
  const DifficultyTuningRemoteConfig({
    required this.defaultSafeWindowPx,
    required this.emptyHistorySafeWindowPx,
    required this.minSpeedMultiplier,
    required this.maxSpeedMultiplier,
    required this.minDensityMultiplier,
    required this.maxDensityMultiplier,
    required this.minCoinMultiplier,
    required this.maxCoinMultiplier,
    required this.minSafeWindowPx,
    required this.maxSafeWindowPx,
    required this.longRunDurationSeconds,
    required this.shortRunDurationSeconds,
    required this.consistentRunDurationSeconds,
    required this.highAccidentRate,
    required this.lowAccidentRate,
    required this.highScoreThreshold,
    required this.lowScoreThreshold,
    required this.longRunSpeedDelta,
    required this.longRunDensityDelta,
    required this.longRunCoinDelta,
    required this.shortRunSpeedDelta,
    required this.shortRunDensityDelta,
    required this.shortRunCoinDelta,
    required this.highAccidentSpeedDelta,
    required this.highAccidentDensityDelta,
    required this.highAccidentSafeWindowDelta,
    required this.highAccidentCoinDelta,
    required this.lowAccidentSpeedDelta,
    required this.lowAccidentDensityDelta,
    required this.highScoreDensityDelta,
    required this.highScoreCoinDelta,
    required this.lowScoreDensityDelta,
    required this.lowScoreCoinDelta,
  });

  final double defaultSafeWindowPx;
  final double emptyHistorySafeWindowPx;
  final double minSpeedMultiplier;
  final double maxSpeedMultiplier;
  final double minDensityMultiplier;
  final double maxDensityMultiplier;
  final double minCoinMultiplier;
  final double maxCoinMultiplier;
  final double minSafeWindowPx;
  final double maxSafeWindowPx;
  final int longRunDurationSeconds;
  final int shortRunDurationSeconds;
  final int consistentRunDurationSeconds;
  final double highAccidentRate;
  final double lowAccidentRate;
  final int highScoreThreshold;
  final int lowScoreThreshold;
  final double longRunSpeedDelta;
  final double longRunDensityDelta;
  final double longRunCoinDelta;
  final double shortRunSpeedDelta;
  final double shortRunDensityDelta;
  final double shortRunCoinDelta;
  final double highAccidentSpeedDelta;
  final double highAccidentDensityDelta;
  final double highAccidentSafeWindowDelta;
  final double highAccidentCoinDelta;
  final double lowAccidentSpeedDelta;
  final double lowAccidentDensityDelta;
  final double highScoreDensityDelta;
  final double highScoreCoinDelta;
  final double lowScoreDensityDelta;
  final double lowScoreCoinDelta;

  Map<String, dynamic> toJson() {
    return {
      'defaultSafeWindowPx': defaultSafeWindowPx,
      'emptyHistorySafeWindowPx': emptyHistorySafeWindowPx,
      'minSpeedMultiplier': minSpeedMultiplier,
      'maxSpeedMultiplier': maxSpeedMultiplier,
      'minDensityMultiplier': minDensityMultiplier,
      'maxDensityMultiplier': maxDensityMultiplier,
      'minCoinMultiplier': minCoinMultiplier,
      'maxCoinMultiplier': maxCoinMultiplier,
      'minSafeWindowPx': minSafeWindowPx,
      'maxSafeWindowPx': maxSafeWindowPx,
      'longRunDurationSeconds': longRunDurationSeconds,
      'shortRunDurationSeconds': shortRunDurationSeconds,
      'consistentRunDurationSeconds': consistentRunDurationSeconds,
      'highAccidentRate': highAccidentRate,
      'lowAccidentRate': lowAccidentRate,
      'highScoreThreshold': highScoreThreshold,
      'lowScoreThreshold': lowScoreThreshold,
      'longRunSpeedDelta': longRunSpeedDelta,
      'longRunDensityDelta': longRunDensityDelta,
      'longRunCoinDelta': longRunCoinDelta,
      'shortRunSpeedDelta': shortRunSpeedDelta,
      'shortRunDensityDelta': shortRunDensityDelta,
      'shortRunCoinDelta': shortRunCoinDelta,
      'highAccidentSpeedDelta': highAccidentSpeedDelta,
      'highAccidentDensityDelta': highAccidentDensityDelta,
      'highAccidentSafeWindowDelta': highAccidentSafeWindowDelta,
      'highAccidentCoinDelta': highAccidentCoinDelta,
      'lowAccidentSpeedDelta': lowAccidentSpeedDelta,
      'lowAccidentDensityDelta': lowAccidentDensityDelta,
      'highScoreDensityDelta': highScoreDensityDelta,
      'highScoreCoinDelta': highScoreCoinDelta,
      'lowScoreDensityDelta': lowScoreDensityDelta,
      'lowScoreCoinDelta': lowScoreCoinDelta,
    };
  }

  static DifficultyTuningRemoteConfig fromJson(String source) {
    if (source.isEmpty) {
      return const DifficultyTuningRemoteConfig(
        defaultSafeWindowPx: 180.0,
        emptyHistorySafeWindowPx: 200.0,
        minSpeedMultiplier: 0.7,
        maxSpeedMultiplier: 1.6,
        minDensityMultiplier: 0.6,
        maxDensityMultiplier: 1.8,
        minCoinMultiplier: 0.7,
        maxCoinMultiplier: 1.8,
        minSafeWindowPx: 140.0,
        maxSafeWindowPx: 260.0,
        longRunDurationSeconds: 45,
        shortRunDurationSeconds: 20,
        consistentRunDurationSeconds: 30,
        highAccidentRate: 0.66,
        lowAccidentRate: 0.2,
        highScoreThreshold: 900,
        lowScoreThreshold: 300,
        longRunSpeedDelta: 0.18,
        longRunDensityDelta: 0.12,
        longRunCoinDelta: -0.12,
        shortRunSpeedDelta: -0.12,
        shortRunDensityDelta: -0.18,
        shortRunCoinDelta: 0.18,
        highAccidentSpeedDelta: -0.15,
        highAccidentDensityDelta: -0.18,
        highAccidentSafeWindowDelta: 60.0,
        highAccidentCoinDelta: 0.15,
        lowAccidentSpeedDelta: 0.08,
        lowAccidentDensityDelta: 0.1,
        highScoreDensityDelta: 0.08,
        highScoreCoinDelta: -0.08,
        lowScoreDensityDelta: -0.1,
        lowScoreCoinDelta: 0.12,
      );
    }
    final map = json.decode(source) as Map<String, dynamic>;
    return DifficultyTuningRemoteConfig(
      defaultSafeWindowPx:
          (map['defaultSafeWindowPx'] as num?)?.toDouble() ?? 180.0,
      emptyHistorySafeWindowPx:
          (map['emptyHistorySafeWindowPx'] as num?)?.toDouble() ?? 200.0,
      minSpeedMultiplier:
          (map['minSpeedMultiplier'] as num?)?.toDouble() ?? 0.7,
      maxSpeedMultiplier:
          (map['maxSpeedMultiplier'] as num?)?.toDouble() ?? 1.6,
      minDensityMultiplier:
          (map['minDensityMultiplier'] as num?)?.toDouble() ?? 0.6,
      maxDensityMultiplier:
          (map['maxDensityMultiplier'] as num?)?.toDouble() ?? 1.8,
      minCoinMultiplier: (map['minCoinMultiplier'] as num?)?.toDouble() ?? 0.7,
      maxCoinMultiplier: (map['maxCoinMultiplier'] as num?)?.toDouble() ?? 1.8,
      minSafeWindowPx: (map['minSafeWindowPx'] as num?)?.toDouble() ?? 140.0,
      maxSafeWindowPx: (map['maxSafeWindowPx'] as num?)?.toDouble() ?? 260.0,
      longRunDurationSeconds: map['longRunDurationSeconds'] as int? ?? 45,
      shortRunDurationSeconds: map['shortRunDurationSeconds'] as int? ?? 20,
      consistentRunDurationSeconds:
          map['consistentRunDurationSeconds'] as int? ?? 30,
      highAccidentRate: (map['highAccidentRate'] as num?)?.toDouble() ?? 0.66,
      lowAccidentRate: (map['lowAccidentRate'] as num?)?.toDouble() ?? 0.2,
      highScoreThreshold: map['highScoreThreshold'] as int? ?? 900,
      lowScoreThreshold: map['lowScoreThreshold'] as int? ?? 300,
      longRunSpeedDelta: (map['longRunSpeedDelta'] as num?)?.toDouble() ?? 0.18,
      longRunDensityDelta:
          (map['longRunDensityDelta'] as num?)?.toDouble() ?? 0.12,
      longRunCoinDelta: (map['longRunCoinDelta'] as num?)?.toDouble() ?? -0.12,
      shortRunSpeedDelta:
          (map['shortRunSpeedDelta'] as num?)?.toDouble() ?? -0.12,
      shortRunDensityDelta:
          (map['shortRunDensityDelta'] as num?)?.toDouble() ?? -0.18,
      shortRunCoinDelta: (map['shortRunCoinDelta'] as num?)?.toDouble() ?? 0.18,
      highAccidentSpeedDelta:
          (map['highAccidentSpeedDelta'] as num?)?.toDouble() ?? -0.15,
      highAccidentDensityDelta:
          (map['highAccidentDensityDelta'] as num?)?.toDouble() ?? -0.18,
      highAccidentSafeWindowDelta:
          (map['highAccidentSafeWindowDelta'] as num?)?.toDouble() ?? 60.0,
      highAccidentCoinDelta:
          (map['highAccidentCoinDelta'] as num?)?.toDouble() ?? 0.15,
      lowAccidentSpeedDelta:
          (map['lowAccidentSpeedDelta'] as num?)?.toDouble() ?? 0.08,
      lowAccidentDensityDelta:
          (map['lowAccidentDensityDelta'] as num?)?.toDouble() ?? 0.1,
      highScoreDensityDelta:
          (map['highScoreDensityDelta'] as num?)?.toDouble() ?? 0.08,
      highScoreCoinDelta:
          (map['highScoreCoinDelta'] as num?)?.toDouble() ?? -0.08,
      lowScoreDensityDelta:
          (map['lowScoreDensityDelta'] as num?)?.toDouble() ?? -0.1,
      lowScoreCoinDelta: (map['lowScoreCoinDelta'] as num?)?.toDouble() ?? 0.12,
    );
  }
}

class UpgradeCostOverride {
  const UpgradeCostOverride({
    required this.type,
    this.maxLevel,
    this.baseCost,
    this.costGrowth,
  });

  final UpgradeType type;
  final int? maxLevel;
  final int? baseCost;
  final int? costGrowth;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (maxLevel != null) 'maxLevel': maxLevel,
      if (baseCost != null) 'baseCost': baseCost,
      if (costGrowth != null) 'costGrowth': costGrowth,
    };
  }

  static UpgradeCostOverride fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? UpgradeType.inkRegen.name;
    return UpgradeCostOverride(
      type: UpgradeType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => UpgradeType.inkRegen,
      ),
      maxLevel: map['maxLevel'] as int?,
      baseCost: map['baseCost'] as int?,
      costGrowth: map['costGrowth'] as int?,
    );
  }
}

class MetaRemoteConfig {
  const MetaRemoteConfig({required this.upgradeOverrides});

  final List<UpgradeCostOverride> upgradeOverrides;

  Map<String, dynamic> toJson() {
    return {
      'upgradeOverrides': upgradeOverrides.map((e) => e.toJson()).toList(),
    };
  }

  static MetaRemoteConfig fromJson(String source) {
    if (source.isEmpty) {
      return const MetaRemoteConfig(upgradeOverrides: []);
    }
    final map = json.decode(source) as Map<String, dynamic>;
    final overrides =
        (map['upgradeOverrides'] as List<dynamic>? ?? [])
            .map(
              (item) =>
                  UpgradeCostOverride.fromMap(item as Map<String, dynamic>),
            )
            .toList();
    return MetaRemoteConfig(upgradeOverrides: overrides);
  }
}
