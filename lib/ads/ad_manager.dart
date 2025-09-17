import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/analytics/analytics_service.dart';
import '../core/config/remote_config_service.dart';
import '../core/env.dart';
import '../core/logging/logger.dart';
import '../game/models/game_models.dart';
import 'consent_manager.dart';
import 'frequency_policies.dart';

class AdManager extends ChangeNotifier {
  AdManager({
    required AnalyticsService analytics,
    required AppEnvironment environment,
    required ConsentManager consentManager,
    required RemoteConfigService remoteConfig,
    required AppLogger logger,
  })  : _analytics = analytics,
        _environment = environment,
        _consentManager = consentManager,
        _remoteConfig = remoteConfig,
        _logger = logger {
    _applyRemoteConfig(remoteConfig.adConfig);
    _remoteConfig.addListener(_handleRemoteConfigChanged);
  }

  final AnalyticsService _analytics;
  final AppEnvironment _environment;
  final ConsentManager _consentManager;
  final RemoteConfigService _remoteConfig;
  final AppLogger _logger;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;
  bool _rewardedReady = false;
  bool _initialized = false;
  bool _requestInProgress = false;
  int _rewardedLoadAttempts = 0;
  int _interstitialLoadAttempts = 0;
  int _bannerLoadAttempts = 0;
  DateTime _sessionStart = DateTime.now();
  DateTime? _lastInterstitialShownAt;
  DateTime? _lastGameOverAt;
  int _gameOverCount = 0;
  int _gameOversSinceLastAd = 0;
  AdFrequencyController _frequencyController =
      const AdFrequencyController(<AdFrequencyPolicy>[]);
  AdRemoteConfig _activeConfig = const AdRemoteConfig(
    interstitialCooldown: Duration(seconds: 90),
    minimumRunDuration: Duration(seconds: 22),
    minimumRunsBeforeInterstitial: 2,
  );

  final ValueNotifier<BannerAd?> _bannerNotifier =
      ValueNotifier<BannerAd?>(null);

  bool get isRewardedAdReady => _rewardedReady;
  bool get isInitialized => _initialized;
  ValueListenable<BannerAd?> get bannerAdListenable => _bannerNotifier;

  Future<void> initialize() async {
    if (_initialized || !_environment.adsEnabled) {
      _initialized = true;
      return;
    }
    if (_requestInProgress) {
      return;
    }
    _requestInProgress = true;
    _sessionStart = DateTime.now();
    _lastInterstitialShownAt = null;
    _gameOverCount = 0;
    _gameOversSinceLastAd = 0;

    try {
      await _updateRequestConfiguration();
      if (!_consentManager.initialized) {
        await _consentManager.initialize();
      } else if (_consentManager.requiresConsent &&
          !_consentManager.consentGathered) {
        await _consentManager.showFormIfRequired();
      }
      _loadRewardedAd();
      _loadInterstitialAd();
      await ensureBannerAd();
    } finally {
      _initialized = true;
      _requestInProgress = false;
    }
  }

  Future<void> ensureBannerAd() async {
    if (!_environment.adsEnabled) {
      return;
    }
    final existing = _bannerAd;
    if (existing != null) {
      return;
    }
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: _resolveBannerUnitId(),
      request: _consentManager.buildAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerAd = ad as BannerAd;
          _bannerNotifier.value = _bannerAd;
          _bannerLoadAttempts = 0;
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _bannerNotifier.value = null;
          _scheduleBannerReload();
          _logger.warn('Banner failed to load: $error');
        },
      ),
    );
    try {
      await banner.load();
    } catch (error, stackTrace) {
      _logger.warn('Banner load threw exception', error: error);
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void registerGameOver(Duration runDuration) {
    if (!_environment.adsEnabled) {
      return;
    }
    if (runDuration <= Duration.zero) {
      return;
    }
    _gameOverCount++;
    _gameOversSinceLastAd++;
    _lastGameOverAt = DateTime.now();
  }

  Future<void> maybeShowInterstitial({
    required Duration lastRunDuration,
    required VoidCallback onFinished,
    VoidCallback? onAdOpened,
    VoidCallback? onAdClosed,
    String placement = 'run_end',
  }) async {
    if (!_environment.adsEnabled) {
      onFinished();
      return;
    }
    final now = DateTime.now();
    final context = AdRequestContext(
      trigger: AdTrigger.gameOver,
      elapsedSinceSessionStart: now.difference(_sessionStart),
      elapsedSinceLastInterstitial:
          _lastInterstitialShownAt == null
              ? const Duration(days: 365)
              : now.difference(_lastInterstitialShownAt!),
      gameOversSinceLastAd: _gameOversSinceLastAd,
      totalGameOvers: _gameOverCount,
      timeSinceLastGameOver: _lastGameOverAt == null
          ? Duration.zero
          : now.difference(_lastGameOverAt!),
    );

    final shouldShow = _frequencyController.canShow(context) &&
        lastRunDuration >= _activeConfig.minimumRunDuration;

    final interstitial = _interstitialAd;
    if (!shouldShow || interstitial == null) {
      if (interstitial == null) {
        _loadInterstitialAd();
      }
      onAdClosed?.call();
      onFinished();
      return;
    }

    interstitial.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        onAdOpened?.call();
        _analytics.logAdWatched(
          placement: placement,
          adType: 'interstitial',
          rewardEarned: false,
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShownAt = DateTime.now();
        _gameOversSinceLastAd = 0;
        _loadInterstitialAd();
        onAdClosed?.call();
        onFinished();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        _logger.warn('Interstitial failed to show', error: error);
        onAdClosed?.call();
        onFinished();
      },
    );

    interstitial.show();
  }

  Future<void> showInterstitialDirect({
    VoidCallback? onAdOpened,
    VoidCallback? onAdClosed,
    String placement = 'manual',
  }) async {
    await maybeShowInterstitial(
      lastRunDuration: _activeConfig.minimumRunDuration,
      onFinished: () {},
      onAdOpened: onAdOpened,
      onAdClosed: onAdClosed,
      placement: placement,
    );
  }

  Future<void> showRewardedAd({
    required String placement,
    required VoidCallback onUserEarnedReward,
    VoidCallback? onAdOpened,
    VoidCallback? onAdClosed,
    VoidCallback? onFallback,
  }) async {
    if (!_environment.adsEnabled) {
      onFallback?.call();
      return;
    }
    final ad = _rewardedAd;
    if (ad == null) {
      _logger.warn('Rewarded ad requested but not ready');
      onFallback?.call();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        onAdOpened?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedReady = false;
        notifyListeners();
        _loadRewardedAd();
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _rewardedReady = false;
        notifyListeners();
        _loadRewardedAd();
        _logger.warn('Rewarded ad failed to show', error: error);
        onFallback?.call();
        onAdClosed?.call();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      _analytics.logAdWatched(
        placement: placement,
        adType: 'rewarded',
        rewardEarned: true,
      );
      onUserEarnedReward();
    });

    _rewardedAd = null;
    _rewardedReady = false;
    notifyListeners();
  }

  void applyRemoteConfig(AdRemoteConfig config) {
    _applyRemoteConfig(config);
  }

  void _handleRemoteConfigChanged() {
    _applyRemoteConfig(_remoteConfig.adConfig);
  }

  void _applyRemoteConfig(AdRemoteConfig config) {
    _activeConfig = config;
    _frequencyController = AdFrequencyController(
      <AdFrequencyPolicy>[
        GameOverIntervalPolicy(
          minimumGameOvers: config.minimumRunsBeforeInterstitial,
        ),
        CooldownPolicy(cooldown: config.interstitialCooldown),
        TimeSinceGameOverPolicy(minimumDuration: config.minimumRunDuration),
        SessionDelayPolicy(delay: config.minimumRunDuration),
      ],
    );
  }

  void _loadRewardedAd() {
    if (!_environment.adsEnabled) {
      return;
    }
    _rewardedLoadAttempts++;
    RewardedAd.load(
      adUnitId: _resolveRewardedUnitId(),
      request: _consentManager.buildAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoadAttempts = 0;
          _rewardedAd = ad;
          _rewardedReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _rewardedReady = false;
          _rewardedAd = null;
          notifyListeners();
          _logger.warn('Rewarded ad failed to load', error: error);
          _scheduleRewardedReload();
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    if (!_environment.adsEnabled) {
      return;
    }
    _interstitialLoadAttempts++;
    InterstitialAd.load(
      adUnitId: _resolveInterstitialUnitId(),
      request: _consentManager.buildAdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadAttempts = 0;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _logger.warn('Interstitial failed to load', error: error);
          _scheduleInterstitialReload();
        },
      ),
    );
  }

  Future<void> _updateRequestConfiguration() async {
    try {
      final configuration = RequestConfiguration(
        testDeviceIds: _environment.isTestBuild ? const <String>[] : null,
      );
      await MobileAds.instance.updateRequestConfiguration(configuration);
    } catch (error, stackTrace) {
      _logger.warn('Failed to update ad request configuration', error: error);
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _scheduleRewardedReload() {
    final delay = _retryDelay(_rewardedLoadAttempts);
    Future<void>.delayed(delay, _loadRewardedAd);
  }

  void _scheduleInterstitialReload() {
    final delay = _retryDelay(_interstitialLoadAttempts);
    Future<void>.delayed(delay, _loadInterstitialAd);
  }

  void _scheduleBannerReload() {
    _bannerLoadAttempts++;
    final delay = _retryDelay(_bannerLoadAttempts);
    Future<void>.delayed(delay, ensureBannerAd);
  }

  Duration _retryDelay(int attempt) {
    final clamped = math.min(6, attempt);
    final seconds = math.min(60, 1 << (clamped - 1));
    return Duration(seconds: seconds);
  }

  String _resolveRewardedUnitId() {
    final configured = _environment.adUnits.rewardedAdUnitId;
    if (configured.isNotEmpty) {
      return configured;
    }
    if (Platform.isIOS) {
      return AdUnitIds.rewardedIosTest;
    }
    return AdUnitIds.rewardedAndroidTest;
  }

  String _resolveInterstitialUnitId() {
    final configured = _environment.adUnits.interstitialAdUnitId;
    if (configured.isNotEmpty) {
      return configured;
    }
    if (Platform.isIOS) {
      return AdUnitIds.interstitialIosTest;
    }
    return AdUnitIds.interstitialAndroidTest;
  }

  String _resolveBannerUnitId() {
    final configured = _environment.adUnits.bannerAdUnitId;
    if (configured.isNotEmpty) {
      return configured;
    }
    if (Platform.isIOS) {
      return AdUnitIds.bannerIosTest;
    }
    return AdUnitIds.bannerAndroidTest;
  }

  @override
  void dispose() {
    _remoteConfig.removeListener(_handleRemoteConfigChanged);
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    _bannerNotifier.dispose();
    super.dispose();
  }
}
