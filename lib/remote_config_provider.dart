import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'game_models.dart';

class RemoteConfigProvider with ChangeNotifier {
  RemoteConfigProvider() {
    _init();
  }

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  DifficultyRemoteConfig _difficulty = const DifficultyRemoteConfig(
    baseSpeedMultiplier: 1.0,
    speedRampIntervalScore: 380,
    speedRampIncrease: 0.35,
    maxSpeedMultiplier: 2.2,
    targetSessionSeconds: 50,
    tutorialSafeWindowMs: 30000,
    emergencyInkFloor: 14,
  );
  AdRemoteConfig _adConfig = const AdRemoteConfig(
    interstitialCooldown: Duration(seconds: 90),
    minimumRunDuration: Duration(seconds: 22),
    minimumRunsBeforeInterstitial: 2,
  );
  bool _isReady = false;

  bool get isReady => _isReady;
  DifficultyRemoteConfig get difficulty => _difficulty;
  AdRemoteConfig get adConfig => _adConfig;

  Future<void> _init() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(minutes: 30),
      ));
      await _remoteConfig.setDefaults(<String, Object>{
        'difficulty_config': json.encode(_difficulty.toJson()),
        'ad_config': json.encode(_adConfig.toJson()),
      });
      await _remoteConfig.fetchAndActivate();
      _difficulty = DifficultyRemoteConfig.fromJson(
        _remoteConfig.getString('difficulty_config'),
      );
      _adConfig = AdRemoteConfig.fromJson(
        _remoteConfig.getString('ad_config'),
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
