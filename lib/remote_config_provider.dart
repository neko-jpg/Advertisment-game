import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'game_models.dart';

class RemoteConfigProvider with ChangeNotifier {
  RemoteConfigProvider({bool initialize = true}) {
    if (initialize) {
      _remoteConfig = FirebaseRemoteConfig.instance;
      _init();
    } else {
      _remoteConfig = null;
      _isReady = true;
    }
  }

  FirebaseRemoteConfig? _remoteConfig;

  DifficultyRemoteConfig _difficulty = const DifficultyRemoteConfig(
    baseSpeedMultiplier: 1.0,
    speedRampIntervalScore: 380,
    speedRampIncrease: 0.35,
    maxSpeedMultiplier: 2.2,
    targetSessionSeconds: 50,
    tutorialSafeWindowMs: 30000,
    emergencyInkFloor: 14,
  );
  DifficultyTuningRemoteConfig _difficultyTuning =
      const DifficultyTuningRemoteConfig(
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
  AdRemoteConfig _adConfig = const AdRemoteConfig(
    interstitialCooldown: Duration(seconds: 90),
    minimumRunDuration: Duration(seconds: 22),
    minimumRunsBeforeInterstitial: 2,
  );
  MetaRemoteConfig _metaConfig = const MetaRemoteConfig(upgradeOverrides: []);
  bool _isReady = false;

  bool get isReady => _isReady;
  DifficultyRemoteConfig get difficulty => _difficulty;
  DifficultyTuningRemoteConfig get difficultyTuning => _difficultyTuning;
  AdRemoteConfig get adConfig => _adConfig;
  MetaRemoteConfig get metaConfig => _metaConfig;

  @visibleForTesting
  void setDifficultyForTesting(DifficultyRemoteConfig config) {
    _difficulty = config;
  }

  @visibleForTesting
  void setDifficultyTuningForTesting(DifficultyTuningRemoteConfig tuning) {
    _difficultyTuning = tuning;
  }

  @visibleForTesting
  void setMetaConfigForTesting(MetaRemoteConfig config) {
    _metaConfig = config;
  }

  @visibleForTesting
  void markReadyForTesting() {
    _isReady = true;
  }

  Future<void> _init() async {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      return;
    }
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: const Duration(minutes: 30),
        ),
      );
      await remoteConfig.setDefaults(<String, Object>{
        'difficulty_config': json.encode(_difficulty.toJson()),
        'difficulty_tuning': json.encode(_difficultyTuning.toJson()),
        'ad_config': json.encode(_adConfig.toJson()),
        'meta_config': json.encode(_metaConfig.toJson()),
      });
      await remoteConfig.fetchAndActivate();
      _difficulty = DifficultyRemoteConfig.fromJson(
        remoteConfig.getString('difficulty_config'),
      );
      _difficultyTuning = DifficultyTuningRemoteConfig.fromJson(
        remoteConfig.getString('difficulty_tuning'),
      );
      _adConfig = AdRemoteConfig.fromJson(remoteConfig.getString('ad_config'));
      _metaConfig = MetaRemoteConfig.fromJson(
        remoteConfig.getString('meta_config'),
      );
      _isReady = true;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Remote config fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _isReady = true;
      notifyListeners();
    }
  }
}
