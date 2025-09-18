import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/analytics/analytics_service.dart';
import '../core/env.dart';
import 'player_wallet.dart';

class AdService extends ChangeNotifier {
  AdService({
    AppEnvironment? environment,
    List<String>? keywords,
    Duration bannerRetryDelay = const Duration(seconds: 30),
    Duration interstitialRetryDelay = const Duration(seconds: 60),
    Duration rewardedRetryDelay = const Duration(seconds: 90),
    int runsBeforeInterstitial = 3,
    Duration interstitialCooldown = const Duration(seconds: 75),
    Duration minimumRunDuration = const Duration(seconds: 22),
    int minimumScoreForInterstitial = 120,
    Duration sessionGracePeriod = const Duration(seconds: 45),
    AnalyticsService? analytics,
    PlayerWallet? wallet,
  }) : _environment = environment ?? AppEnvironment.resolve(),
       _keywords =
           keywords ??
           const <String>['endless runner', 'platformer', 'arcade', 'dash'],
       _bannerRetryDelay = bannerRetryDelay,
       _interstitialRetryDelay = interstitialRetryDelay,
       _rewardedRetryDelay = rewardedRetryDelay,
       _runsBeforeInterstitial = runsBeforeInterstitial,
       _interstitialCooldown = interstitialCooldown,
       _minimumRunDuration = minimumRunDuration,
       _minimumScoreForInterstitial = minimumScoreForInterstitial,
       _sessionGracePeriod = sessionGracePeriod,
       _sessionStartedAt = DateTime.now(),
       _analytics = analytics,
       _wallet = wallet {
    _adsAllowedCache = _adsAllowed;
    _bindWallet(wallet);
  }

  final AppEnvironment _environment;
  final List<String> _keywords;
  final Duration _bannerRetryDelay;
  final Duration _interstitialRetryDelay;
  final Duration _rewardedRetryDelay;
  final int _runsBeforeInterstitial;
  final Duration _interstitialCooldown;
  final Duration _minimumRunDuration;
  final int _minimumScoreForInterstitial;
  final Duration _sessionGracePeriod;
  final AnalyticsService? _analytics;
  PlayerWallet? _wallet;
  final DateTime _sessionStartedAt;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  Timer? _bannerRetryTimer;
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;

  VoidCallback? _walletListener;
  bool _adsAllowedCache = true;

  Completer<void>? _initializationCompleter;
  bool _initializing = false;
  bool _isDisposed = false;

  int _runsSinceInterstitial = 0;
  DateTime? _lastInterstitialShownAt;

  int _bannerLoadAttempts = 0;
  int _interstitialLoadAttempts = 0;
  int _rewardedLoadAttempts = 0;

  int _sessionRuns = 0;
  Duration _sessionPlaytime = Duration.zero;
  double _rollingRunDurationSeconds = 0;
  int _highValueRunStreak = 0;

  BannerAd? get bannerAd => _adsAllowed ? _bannerAd : null;
  bool get hasRewardedAd => _rewardedAd != null;
  bool get isInitialized => !_initializing && _initializationCompleter == null;

  AppEnvironment get environment => _environment;
  int get sessionRuns => _sessionRuns;
  Duration get sessionPlaytime => _sessionPlaytime;
  Duration get averageRunDuration =>
      _rollingRunDurationSeconds <= 0
          ? Duration.zero
          : Duration(
            milliseconds:
                (_rollingRunDurationSeconds * Duration.millisecondsPerSecond)
                    .round(),
          );

  bool get adsDisabled => !_adsAllowed;
  bool get _adsAllowed =>
      _environment.adsEnabled && !(_wallet?.adsRemoved ?? false);

  bool get _canLoadAds => _adsAllowed && !_isDisposed;

  Future<void> initialize() async {
    if (_isDisposed) {
      return;
    }
    if (!_adsAllowed) {
      _teardownAds();
      return;
    }
    final pending = _initializationCompleter;
    if (pending != null) {
      return pending.future;
    }
    final completer = Completer<void>();
    _initializationCompleter = completer;
    _initializing = true;
    try {
      await Future.wait<void>(<Future<void>>[
        _loadBanner(),
        _loadInterstitial(),
        _loadRewarded(),
      ]);
    } catch (error, stackTrace) {
      debugPrint('AdService initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initializing = false;
      if (!completer.isCompleted) {
        completer.complete();
      }
      _initializationCompleter = null;
    }
  }

  Future<void> _loadBanner() async {
    if (_isDisposed) {
      return;
    }
    if (!_canLoadAds) {
      return;
    }
    _bannerRetryTimer?.cancel();
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: _environment.adUnits.bannerAdUnitId,
      request: _adRequest,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerLoadAttempts = 0;
          _bannerAd?.dispose();
          _bannerAd = ad as BannerAd;
          _safeNotify();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _safeNotify();
          if (kDebugMode) {
            debugPrint('Banner failed to load: $error');
          }
          _scheduleBannerReload();
        },
      ),
    );
    try {
      await banner.load();
    } catch (error, stackTrace) {
      banner.dispose();
      if (kDebugMode) {
        debugPrint('Banner load threw: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _scheduleBannerReload();
    }
  }

  Future<void> _loadInterstitial() async {
    if (_isDisposed) {
      return;
    }
    if (!_canLoadAds) {
      return;
    }
    _interstitialRetryTimer?.cancel();
    await InterstitialAd.load(
      adUnitId: _environment.adUnits.interstitialAdUnitId,
      request: _adRequest,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadAttempts = 0;
          _interstitialAd?.dispose();
          ad
            ..setImmersiveMode(true)
            ..fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _lastInterstitialShownAt = DateTime.now();
              },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                _safeNotify();
                _loadInterstitial();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitialAd = null;
                _safeNotify();
                if (kDebugMode) {
                  debugPrint('Interstitial failed to show: $error');
                }
                _scheduleInterstitialReload();
              },
            );
          _interstitialAd = ad;
          _safeNotify();
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _safeNotify();
          if (kDebugMode) {
            debugPrint('Interstitial failed to load: $error');
          }
          _scheduleInterstitialReload();
        },
      ),
    );
  }

  Future<void> _loadRewarded() async {
    if (_isDisposed) {
      return;
    }
    if (!_canLoadAds) {
      return;
    }
    _rewardedRetryTimer?.cancel();
    await RewardedAd.load(
      adUnitId: _environment.adUnits.rewardedAdUnitId,
      request: _adRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoadAttempts = 0;
          _rewardedAd?.dispose();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _safeNotify();
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _safeNotify();
              if (kDebugMode) {
                debugPrint('Rewarded failed to show: $error');
              }
              _scheduleRewardedReload();
            },
          );
          _rewardedAd = ad;
          _safeNotify();
        },
        onAdFailedToLoad: (error) {
          _rewardedAd?.dispose();
          _rewardedAd = null;
          _safeNotify();
          if (kDebugMode) {
            debugPrint('Rewarded failed to load: $error');
          }
          _scheduleRewardedReload();
        },
      ),
    );
  }

  Future<void> maybeShowInterstitial({
    bool force = false,
    Duration? lastRunDuration,
    int score = 0,
    int coinsCollected = 0,
    String placement = 'run_end',
  }) async {
    if (_isDisposed) {
      return;
    }
    if (!_adsAllowed) {
      return;
    }

    if (lastRunDuration != null) {
      _sessionRuns += 1;
      _sessionPlaytime += lastRunDuration;
      final double seconds =
          lastRunDuration.inMilliseconds / Duration.millisecondsPerSecond;
      if (_rollingRunDurationSeconds == 0) {
        _rollingRunDurationSeconds = seconds;
      } else {
        _rollingRunDurationSeconds =
            _rollingRunDurationSeconds * 0.65 + seconds * 0.35;
      }
      final bool highValueRun =
          score >= _minimumScoreForInterstitial ||
          coinsCollected >= 5 ||
          lastRunDuration.inMilliseconds >=
              (_minimumRunDuration.inMilliseconds * 1.2).round();
      if (highValueRun) {
        _highValueRunStreak = math.min(_highValueRunStreak + 1, 3);
      } else {
        _highValueRunStreak = 0;
      }
    }

    if (!force) {
      if (DateTime.now().difference(_sessionStartedAt) < _sessionGracePeriod &&
          _sessionRuns < 2) {
        return;
      }
      _runsSinceInterstitial += 1;
      final bool shortRun =
          lastRunDuration != null && lastRunDuration < _minimumRunDuration;
      final bool lowScore = score < _minimumScoreForInterstitial;
      if (shortRun && lowScore && _highValueRunStreak == 0) {
        return;
      }
      final int dynamicThreshold =
          _highValueRunStreak >= 2
              ? math.max(1, _runsBeforeInterstitial - 1)
              : _runsBeforeInterstitial;
      if (_runsSinceInterstitial < dynamicThreshold) {
        return;
      }
      final DateTime? lastShown = _lastInterstitialShownAt;
      if (lastShown != null &&
          DateTime.now().difference(lastShown) < _interstitialCooldown) {
        return;
      }
    }

    final interstitial = _interstitialAd;
    if (interstitial == null) {
      return;
    }
    _runsSinceInterstitial = 0;
    _interstitialAd = null;
    _safeNotify();
    try {
      await interstitial.show();
      unawaited(
        _analytics?.logAdWatched(
          placement: placement,
          adType: 'interstitial',
          rewardEarned: false,
        ),
      );
    } catch (error, stackTrace) {
      interstitial.dispose();
      if (kDebugMode) {
        debugPrint('Interstitial show threw: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _scheduleInterstitialReload();
    }
  }

  Future<bool> showRewarded({
    required VoidCallback onReward,
    String placement = 'revive',
  }) async {
    if (_isDisposed) {
      return false;
    }
    final ad = _rewardedAd;
    if (ad == null) {
      return false;
    }
    _rewardedAd = null;
    _safeNotify();
    var rewarded = false;
    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          rewarded = true;
          onReward();
        },
      );
      unawaited(
        _analytics?.logAdWatched(
          placement: placement,
          adType: 'rewarded',
          rewardEarned: rewarded,
        ),
      );
    } catch (error, stackTrace) {
      ad.dispose();
      if (kDebugMode) {
        debugPrint('Rewarded show threw: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      _scheduleRewardedReload();
      return false;
    }
    return rewarded;
  }

  AdRequest get _adRequest {
    return AdRequest(
      keywords: _keywords,
      nonPersonalizedAds: _environment.adUnits.nonPersonalizedAds,
      contentUrl: 'https://quickdrawdash.app',
    );
  }

  void _scheduleBannerReload() {
    if (_isDisposed) {
      return;
    }
    if (!_canLoadAds) {
      return;
    }
    final delay = _retryDelay(_bannerRetryDelay, _bannerLoadAttempts);
    _bannerLoadAttempts = math.min(_bannerLoadAttempts + 1, 6);
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = Timer(delay, () {
      _bannerRetryTimer = null;
      _loadBanner();
    });
  }

  void _scheduleInterstitialReload() {
    if (_isDisposed) {
      return;
    }
    if (!_canLoadAds) {
      return;
    }
    final delay = _retryDelay(
      _interstitialRetryDelay,
      _interstitialLoadAttempts,
    );
    _interstitialLoadAttempts = math.min(_interstitialLoadAttempts + 1, 6);
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = Timer(delay, () {
      _interstitialRetryTimer = null;
      _loadInterstitial();
    });
  }

  void _scheduleRewardedReload() {
    if (_isDisposed) {
      return;
    }
    if (!_canLoadAds) {
      return;
    }
    final delay = _retryDelay(_rewardedRetryDelay, _rewardedLoadAttempts);
    _rewardedLoadAttempts = math.min(_rewardedLoadAttempts + 1, 6);
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = Timer(delay, () {
      _rewardedRetryTimer = null;
      _loadRewarded();
    });
  }

  void syncWallet(PlayerWallet? wallet) {
    _bindWallet(wallet);
  }

  void _bindWallet(PlayerWallet? wallet) {
    if (identical(wallet, _wallet)) {
      return;
    }
    if (_walletListener != null && _wallet != null) {
      _wallet!.removeListener(_walletListener!);
    }
    _wallet = wallet;
    if (wallet != null) {
      _walletListener = () {
        _handleWalletStateChange();
      };
      wallet.addListener(_walletListener!);
    } else {
      _walletListener = null;
    }
    _handleWalletStateChange();
  }

  void _handleWalletStateChange() {
    final allowed = _adsAllowed;
    if (_adsAllowedCache == allowed) {
      return;
    }
    _adsAllowedCache = allowed;
    if (!allowed) {
      _teardownAds();
    } else if (!_initializing && !_isDisposed) {
      if (_bannerAd == null) {
        unawaited(_loadBanner());
      }
      if (_interstitialAd == null) {
        unawaited(_loadInterstitial());
      }
      if (_rewardedAd == null) {
        unawaited(_loadRewarded());
      }
    }
    _safeNotify();
  }

  void _teardownAds() {
    _bannerRetryTimer?.cancel();
    _interstitialRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _interstitialRetryTimer = null;
    _rewardedRetryTimer = null;
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _bannerAd = null;
    _interstitialAd = null;
    _rewardedAd = null;
  }

  Duration _retryDelay(Duration base, int attempts) {
    final exponent = math.min(attempts, 5);
    final multiplier = 1 << exponent;
    return base * multiplier;
  }

  void _safeNotify() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (_walletListener != null && _wallet != null) {
      _wallet!.removeListener(_walletListener!);
    }
    _walletListener = null;
    _teardownAds();
    super.dispose();
  }
}
