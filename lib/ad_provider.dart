
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdProvider with ChangeNotifier {
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _isRewardedAdReady = false;
  int _gamesUntilAd = 3;

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

  void showInterstitialAdIfNeeded() {
    _gamesUntilAd--;
    if (_gamesUntilAd <= 0) {
      if (_interstitialAd != null) {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            loadInterstitialAd(); // Pre-load the next one
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            loadInterstitialAd();
          },
        );
        _interstitialAd!.show();
        _gamesUntilAd = 3; // Reset counter
      } else {
        loadInterstitialAd(); // If it wasn't ready, try loading again
      }
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
