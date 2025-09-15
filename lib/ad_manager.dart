
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdManager {
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/5224354917";
    }
    if (Platform.isIOS) {
      return "ca-app-pub-3940256099942544/1712485313";
    }
    return ""; // Or handle other platforms
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/1033173712";
    }
    if (Platform.isIOS) {
      return "ca-app-pub-3940256099942544/4411468910";
    }
    return ""; // Or handle other platforms
  }

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void showRewardedAd(Function onAdRewarded) {
    if (_rewardedAd == null) {
      // Rewarded ad is not ready yet.
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd(); // Pre-load the next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onAdRewarded();
    });
  }

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _interstitialLoadAttempts++;
          if (_interstitialLoadAttempts <= 3) {
            loadInterstitialAd();
          }
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd == null) {
      loadInterstitialAd(); // Try to load again
      return;
    }
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
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
