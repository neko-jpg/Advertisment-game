import 'package:flutter/foundation.dart';

import 'constants/ad_constants.dart';

class AdUnitConfiguration {
  const AdUnitConfiguration({
    required this.bannerAdUnitId,
    required this.interstitialAdUnitId,
    required this.rewardedAdUnitId,
    required this.appId,
    this.nonPersonalizedAds = false,
  });

  final String bannerAdUnitId;
  final String interstitialAdUnitId;
  final String rewardedAdUnitId;
  final String appId;
  final bool nonPersonalizedAds;

  AdUnitConfiguration copyWith({
    String? bannerAdUnitId,
    String? interstitialAdUnitId,
    String? rewardedAdUnitId,
    String? appId,
    bool? nonPersonalizedAds,
  }) {
    return AdUnitConfiguration(
      bannerAdUnitId: bannerAdUnitId ?? this.bannerAdUnitId,
      interstitialAdUnitId: interstitialAdUnitId ?? this.interstitialAdUnitId,
      rewardedAdUnitId: rewardedAdUnitId ?? this.rewardedAdUnitId,
      appId: appId ?? this.appId,
      nonPersonalizedAds: nonPersonalizedAds ?? this.nonPersonalizedAds,
    );
  }
}

class AppEnvironment {
  AppEnvironment({
    required this.name,
    required this.isTestBuild,
    required this.analyticsEnabled,
    required this.adsEnabled,
    required this.adUnits,
  });

  factory AppEnvironment.resolve() {
    final flavor =
        const String.fromEnvironment('APP_ENV', defaultValue: 'production');
    final overrideTest =
        const bool.fromEnvironment('TEST_MODE', defaultValue: false);
    final bool isTest = !kReleaseMode || overrideTest;
    final bannerId = const String.fromEnvironment('BANNER_AD_UNIT_ID');
    final interstitialId =
        const String.fromEnvironment('INTERSTITIAL_AD_UNIT_ID');
    final rewardedId = const String.fromEnvironment('REWARDED_AD_UNIT_ID');
    final appId = const String.fromEnvironment('ADMOB_APP_ID');

    final adUnits = AdUnitConfiguration(
      bannerAdUnitId: _resolveUnit(
        candidate: bannerId,
        androidFallback: AdUnitIds.bannerAndroidTest,
        iosFallback: AdUnitIds.bannerIosTest,
      ),
      interstitialAdUnitId: _resolveUnit(
        candidate: interstitialId,
        androidFallback: AdUnitIds.interstitialAndroidTest,
        iosFallback: AdUnitIds.interstitialIosTest,
      ),
      rewardedAdUnitId: _resolveUnit(
        candidate: rewardedId,
        androidFallback: AdUnitIds.rewardedAndroidTest,
        iosFallback: AdUnitIds.rewardedIosTest,
      ),
      appId: appId.isNotEmpty ? appId : _defaultAppId(),
      nonPersonalizedAds: const bool.fromEnvironment(
        'FORCE_NON_PERSONALIZED_ADS',
        defaultValue: false,
      ),
    );

    final analyticsFlag = const bool.fromEnvironment(
      'ENABLE_ANALYTICS',
      defaultValue: true,
    );
    final adsFlag = const bool.fromEnvironment('ENABLE_ADS', defaultValue: true);

    return AppEnvironment(
      name: flavor,
      isTestBuild: isTest,
      analyticsEnabled: analyticsFlag && !overrideTest,
      adsEnabled: adsFlag,
      adUnits: adUnits,
    );
  }

  final String name;
  final bool isTestBuild;
  final bool analyticsEnabled;
  final bool adsEnabled;
  final AdUnitConfiguration adUnits;

  static String _resolveUnit({
    required String candidate,
    required String androidFallback,
    required String iosFallback,
  }) {
    if (candidate.isNotEmpty) {
      return candidate;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosFallback;
    }
    return androidFallback;
  }

  static String _defaultAppId() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544~1458002511';
    }
    return 'ca-app-pub-3940256099942544~3347511713';
  }

  AppEnvironment copyWith({
    bool? analyticsEnabled,
    bool? adsEnabled,
    AdUnitConfiguration? adUnits,
  }) {
    return AppEnvironment(
      name: name,
      isTestBuild: isTestBuild,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      adsEnabled: adsEnabled ?? this.adsEnabled,
      adUnits: adUnits ?? this.adUnits,
    );
  }
}
