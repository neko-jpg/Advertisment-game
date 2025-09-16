
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdProvider with ChangeNotifier {
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdReady = false;
  int _runsCompleted = 0;
  Duration _timeSinceLastInterstitial = Duration.zero;
  DateTime? _lastInterstitialShownAt;

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
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void showRewardAd({required VoidCallback onReward}) {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadRewardAd();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
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
  }) {
    final bool skipForFirstRuns = _runsCompleted <= 2;
    final bool wasShortRun = lastRunDuration.inSeconds < 20;
    final DateTime now = DateTime.now();
    final bool elapsedSinceLastInterstitial = _lastInterstitialShownAt == null ||
        now.difference(_lastInterstitialShownAt!) >= const Duration(seconds: 60);
    final bool accumulatedTimeReached =
        _timeSinceLastInterstitial >= const Duration(seconds: 60);

    if (!skipForFirstRuns && !wasShortRun &&
        elapsedSinceLastInterstitial && accumulatedTimeReached &&
        _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _lastInterstitialShownAt = DateTime.now();
          _timeSinceLastInterstitial = Duration.zero;
          loadInterstitialAd();
          onClosed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitialAd();
          onClosed();
        },
      );
      _interstitialAd!.show();
    } else {
      if (_interstitialAd == null) {
        loadInterstitialAd();
      }
      onClosed();
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
