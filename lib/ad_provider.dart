
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'game_models.dart';

class AdProvider with ChangeNotifier {
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdReady = false;
  int _runsCompleted = 0;
  Duration _timeSinceLastInterstitial = Duration.zero;
  DateTime? _lastInterstitialShownAt;
  AdRemoteConfig _config = const AdRemoteConfig(
    interstitialCooldown: Duration(seconds: 75),
    minimumRunDuration: Duration(seconds: 20),
    minimumRunsBeforeInterstitial: 2,
  );
  final List<String> _interstitialCandidates = [];
  int _nextInterstitialIndex = 0;
  int _mediationAttempts = 0;

  // Ad Unit IDs
  final String _rewardAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Android Test Ad
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Ad

  final String _interstitialAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712' // Android Test Ad
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS Test Ad

  bool get isRewardedAdReady => _isRewardedAdReady;

  AdProvider() {
    loadRewardAd();
    loadInterstitialAd();
  }

  void loadRewardAd() {
    RewardedAd.load(
      adUnitId: _rewardAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          notifyListeners();
        },
      ),
    );
  }

  void loadInterstitialAd() {
    _mediationAttempts = 0;
    InterstitialAd.load(
      adUnitId: _resolveInterstitialUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          if (_interstitialCandidates.isNotEmpty) {
            _nextInterstitialIndex =
                (_nextInterstitialIndex + 1) % _interstitialCandidates.length;
            if (_mediationAttempts < _interstitialCandidates.length) {
              _mediationAttempts++;
              loadInterstitialAd();
            }
          }
        },
      ),
    );
  }

  void showRewardAd({
    required VoidCallback onReward,
    VoidCallback? onAdOpened,
    VoidCallback? onAdClosed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        onAdOpened?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardAd();
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadRewardAd();
        onAdClosed?.call();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      onReward();
    });
    _rewardedAd = null;
    _isRewardedAdReady = false;
    notifyListeners();
  }

  void registerRunEnd(Duration runDuration) {
    if (runDuration <= Duration.zero) {
      return;
    }
    _runsCompleted++;
    _timeSinceLastInterstitial += runDuration;
  }

  void maybeShowInterstitial({
    required Duration lastRunDuration,
    required VoidCallback onClosed,
    VoidCallback? onAdOpened,
    VoidCallback? onAdClosed,
  }) {
    final bool skipForFirstRuns =
        _runsCompleted < _config.minimumRunsBeforeInterstitial;
    final bool wasShortRun = lastRunDuration < _config.minimumRunDuration;
    final DateTime now = DateTime.now();
    final bool elapsedSinceLastInterstitial = _lastInterstitialShownAt == null ||
        now.difference(_lastInterstitialShownAt!) >=
            _config.interstitialCooldown;
    final bool accumulatedTimeReached =
        _timeSinceLastInterstitial >= _config.interstitialCooldown;

    if (!skipForFirstRuns && !wasShortRun &&
        elapsedSinceLastInterstitial && accumulatedTimeReached &&
        _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          onAdOpened?.call();
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _lastInterstitialShownAt = DateTime.now();
          _timeSinceLastInterstitial = Duration.zero;
          loadInterstitialAd();
          onAdClosed?.call();
          onClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitialAd();
          onAdClosed?.call();
          onClosed();
        },
      );
      _interstitialAd!.show();
    } else {
      if (_interstitialAd == null) {
        loadInterstitialAd();
      }
      onAdClosed?.call();
      onClosed();
    }
  }

  void applyRemoteConfig(AdRemoteConfig config) {
    _config = config;
  }

  void configureMediationOrder(List<String> interstitialUnitIds) {
    _interstitialCandidates
      ..clear()
      ..addAll(interstitialUnitIds);
    _nextInterstitialIndex = 0;
    loadInterstitialAd();
  }

  String _resolveInterstitialUnitId() {
    if (_interstitialCandidates.isEmpty) {
      return _interstitialAdUnitId;
    }
    return _interstitialCandidates[
        _nextInterstitialIndex % _interstitialCandidates.length];
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
