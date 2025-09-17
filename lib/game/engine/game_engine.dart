import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../ads/ad_manager.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/constants/game_constants.dart';
import '../audio/sound_controller.dart';
import '../models/game_models.dart';
import '../state/coin_manager.dart';
import '../state/line_manager.dart';
import '../state/meta_state.dart';
import '../state/obstacle_manager.dart';

enum GameState { ready, running, dead, result }

class _DifficultyTuning {
  const _DifficultyTuning({
    required this.speedMultiplier,
    required this.densityMultiplier,
    required this.coinMultiplier,
    required this.safeWindowPx,
  });

  final double speedMultiplier;
  final double densityMultiplier;
  final double coinMultiplier;
  final double safeWindowPx;
}

class GameProvider with ChangeNotifier {
  GameState _gameState = GameState.ready;
  final double _playerX = GameConstants.playerStartX;
  double _playerY = GameConstants.playerStartY;
  double _playerYSpeed = 0.0;
  int _score = 0;
  Ticker? _ticker;
  Size _screenSize = Size.zero;
  double _baseCoyoteDurationMs = GameConstants.baseCoyoteDurationMs;
  static const double _jumpBufferDurationMs =
      GameConstants.jumpBufferDurationMs;
  double _coyoteTimerMs = 0.0;
  double _jumpBufferTimerMs = 0.0;
  DateTime? _lastFrameTimestamp;
  DateTime? _runStartTime;
  double _elapsedRunMs = 0.0;
  double _restTimerMs = 0.0;
  double _restWindowElapsedMs = 0.0;
  bool _restWindowActive = false;
  bool _didJumpThisRun = false;
  bool _didDrawLineThisRun = false;
  bool _hasCompletedTutorial = false;
  bool _hasBankedRewards = false;
  Duration _lastRunDuration = Duration.zero;
  bool _lastRunAccident = false;
  int _jumpsThisRun = 0;
  int _drawTimeMsThisRun = 0;
  bool _wasDrawingLastFrame = false;
  int _revivesUsedThisRun = 0;
  double _invulnerabilityMs = 0.0;
  bool _invulnerabilityWarningShown = false;
  final List<RunStats> _recentRuns = [];
  int _accidentStreak = 0;
  Duration _nextRunGrace = Duration.zero;
  double _scoreAccumulator = 0.0;
  _DifficultyTuning _activeDifficulty = const _DifficultyTuning(
    speedMultiplier: 1.0,
    densityMultiplier: 1.0,
    coinMultiplier: 1.0,
    safeWindowPx: 180,
  );
  UpgradeSnapshot _activeUpgrades = const UpgradeSnapshot(
    inkRegenMultiplier: 1,
    maxRevives: 1,
    coyoteBonusMs: 0,
  );
  final ValueNotifier<int> _worldTick = ValueNotifier<int>(0);
  final ValueNotifier<int> _hudTick = ValueNotifier<int>(0);
  final ValueNotifier<GameToast?> _toastNotifier = ValueNotifier<GameToast?>(
    null,
  );
  Timer? _toastTimer;
  DifficultyRemoteConfig _remoteDifficulty = const DifficultyRemoteConfig(
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
  int _nextSpeedRampScore = 380;
  double _currentSpeedMultiplier = 1.0;
  double _speedRampIncrease = 0.35;
  double _maxSpeedMultiplier = 2.2;
  bool _emergencyInkAvailable = false;
  int _lastRunBonusCoins = 0;
  int _nextBonusScore = GameConstants.scoreBonusStep;
  int _nextBonusReward = GameConstants.baseBonusReward;
  double _lastRestProgressNotified = 0.0;
  RunBoost? _activeRunBoost;
  double _boostRemainingMs = 0.0;

  // Providers
  final AnalyticsService analytics;
  AdManager adManager;
  LineProvider lineProvider;
  ObstacleProvider obstacleProvider;
  CoinProvider coinProvider;
  MetaProvider metaProvider;
  RemoteConfigService remoteConfigProvider;
  SoundController soundProvider;

  GameProvider({
    required this.analytics,
    required this.adManager,
    required this.lineProvider,
    required this.obstacleProvider,
    required this.coinProvider,
    required this.metaProvider,
    required this.remoteConfigProvider,
    required this.soundProvider,
    required TickerProvider vsync,
  }) {
    _ticker = vsync.createTicker(_gameLoop);
    _applyRemoteDifficulty(remoteConfigProvider.difficulty);
    _difficultyTuning = remoteConfigProvider.difficultyTuning;
  }

  // Getters
  GameState get gameState => _gameState;
  double get playerX => _playerX;
  double get playerY => _playerY;
  int get score => _score;
  int get coinsCollected => coinProvider.coinsCollected;
  Size get screenSize => _screenSize;
  double get elapsedRunMs => _elapsedRunMs;
  Duration get lastRunDuration => _lastRunDuration;
  bool get isTutorialActive => !_hasCompletedTutorial;
  bool get showJumpHint =>
      isTutorialActive && !_didJumpThisRun && _elapsedRunMs <= 8000;
  bool get showDrawHint =>
      isTutorialActive &&
      !_didDrawLineThisRun &&
      _elapsedRunMs >= 5000 &&
      _elapsedRunMs <= 18000;
  bool get isRestWindow => _restWindowActive;
  double get restWindowProgress =>
      _restWindowActive
          ? (_restWindowElapsedMs / _restDurationMs).clamp(0.0, 1.0)
          : 0.0;
  bool get canRevive => _revivesUsedThisRun < _activeUpgrades.maxRevives;
  ValueListenable<int> get worldListenable => _worldTick;
  ValueListenable<int> get hudListenable => _hudTick;
  ValueListenable<GameToast?> get toastListenable => _toastNotifier;
  int get lastRunBonusCoins => _lastRunBonusCoins;
  int get nextScoreBonusTarget => _nextBonusScore;
  int get nextScoreBonusReward => _nextBonusReward;
  int get worldFrame => _worldTick.value;
  bool get isBoostActive => _activeRunBoost != null && _boostRemainingMs > 0;
  double get boostRemainingSeconds =>
      (_boostRemainingMs / 1000).clamp(0.0, 999.0);
  double get boostCoinMultiplier => _activeRunBoost?.coinMultiplier ?? 1.0;
  double get boostInkMultiplier => _activeRunBoost?.inkRegenMultiplier ?? 1.0;

  static const double _restIntervalMs = GameConstants.restIntervalMs;
  static const double _restDurationMs = GameConstants.restDurationMs;

  void _applyRemoteDifficulty(DifficultyRemoteConfig config) {
    _remoteDifficulty = config;
    _speedRampIncrease = config.speedRampIncrease;
    _maxSpeedMultiplier = config.maxSpeedMultiplier;
    _nextSpeedRampScore = config.speedRampIntervalScore;
    _currentSpeedMultiplier = (_activeDifficulty.speedMultiplier *
            config.baseSpeedMultiplier)
        .clamp(GameConstants.absoluteMinSpeedMultiplier, _maxSpeedMultiplier);
    _nextBonusScore =
        ((score ~/ GameConstants.scoreBonusStep) + 1) *
        GameConstants.scoreBonusStep;
    _nextBonusReward = _predictBonusForScore(_nextBonusScore);
  }

  void _markWorldDirty() {
    _worldTick.value++;
  }

  void _markHudDirty() {
    _hudTick.value++;
  }

  void _pushToast(GameToast toast) {
    _toastTimer?.cancel();
    _toastNotifier.value = toast;
    _toastTimer = Timer(toast.duration, () {
      if (_toastNotifier.value == toast) {
        _toastNotifier.value = null;
      }
    });
  }

  int _bonusRewardForTier(int tier) {
    if (tier <= 0) {
      return 0;
    }
    return GameConstants.baseBonusReward +
        (tier - 1) * GameConstants.bonusRewardIncrement;
  }

  int _resolveScoreBonus(int score) {
    final tier = score ~/ GameConstants.scoreBonusStep;
    if (tier <= 0) {
      return 0;
    }
    return _bonusRewardForTier(tier);
  }

  int _predictBonusForScore(int score) {
    final tier = (score / GameConstants.scoreBonusStep).ceil();
    return _bonusRewardForTier(tier);
  }

  void _updateNextBonusTarget(int score) {
    final nextTier = (score ~/ GameConstants.scoreBonusStep) + 1;
    _nextBonusScore = nextTier * GameConstants.scoreBonusStep;
    _nextBonusReward = _predictBonusForScore(_nextBonusScore);
  }

  void setScreenSize(Size size) {
    if (_screenSize == size) {
      return;
    }
    _screenSize = size;
  }

  void startGame() {
    if (_gameState == GameState.running) return;

    _gameState = GameState.running;
    _score = 0;
    _playerY = GameConstants.playerStartY;
    _playerYSpeed = 0.0;
    _jumpBufferTimerMs = 0.0;
    _activeUpgrades = metaProvider.upgradeSnapshot;
    _baseCoyoteDurationMs =
        GameConstants.baseCoyoteDurationMs + _activeUpgrades.coyoteBonusMs;
    _coyoteTimerMs = _baseCoyoteDurationMs;
    _lastFrameTimestamp = null;
    _runStartTime = DateTime.now();
    _elapsedRunMs = 0.0;
    _restTimerMs = 0.0;
    _restWindowElapsedMs = 0.0;
    _restWindowActive = false;
    obstacleProvider.setRestMode(false);
    _lastRestProgressNotified = 0.0;
    _didJumpThisRun = false;
    _didDrawLineThisRun = false;
    _hasBankedRewards = false;
    _lastRunDuration = Duration.zero;
    _lastRunAccident = false;
    _jumpsThisRun = 0;
    _drawTimeMsThisRun = 0;
    _wasDrawingLastFrame = false;
    _revivesUsedThisRun = 0;
    _invulnerabilityWarningShown = false;
    _invulnerabilityMs = isTutorialActive ? 3500.0 : 1500.0;
    _scoreAccumulator = 0.0;
    _lastRunBonusCoins = 0;
    _emergencyInkAvailable = true;

    metaProvider.refreshDailyMissionsIfNeeded();
    final RunBoost? boost = metaProvider.consumeQueuedBoost();
    _activeRunBoost = boost;
    _boostRemainingMs = boost?.duration.inMilliseconds.toDouble() ?? 0.0;

    lineProvider
      ..configureUpgrades(
        regenMultiplier:
            _activeUpgrades.inkRegenMultiplier *
            (boost?.inkRegenMultiplier ?? 1.0),
      )
      ..clearAllLines();
    obstacleProvider.reset();
    coinProvider
      ..reset()
      ..configureSpawn(multiplier: 1.0);

    _activeDifficulty = _evaluateDifficulty();
    _applyRemoteDifficulty(_remoteDifficulty);
    _currentSpeedMultiplier = (_activeDifficulty.speedMultiplier *
            _remoteDifficulty.baseSpeedMultiplier)
        .clamp(GameConstants.absoluteMinSpeedMultiplier, _maxSpeedMultiplier);
    if (isTutorialActive) {
      _currentSpeedMultiplier = _currentSpeedMultiplier.clamp(
        GameConstants.absoluteMinSpeedMultiplier,
        GameConstants.tutorialMaxSpeedMultiplier,
      );
    }
    _nextSpeedRampScore = _remoteDifficulty.speedRampIntervalScore;
    final startGrace = _nextRunGrace;
    _nextRunGrace = Duration.zero;

    obstacleProvider.configureDifficulty(
      speedMultiplier: _currentSpeedMultiplier,
      densityMultiplier: _activeDifficulty.densityMultiplier,
      safeWindow: _activeDifficulty.safeWindowPx,
      startGrace: startGrace,
    );
    obstacleProvider.configureTutorialWindow(
      durationMs: _remoteDifficulty.tutorialSafeWindowMs.toDouble(),
    );
    coinProvider.configureSpawn(multiplier: _activeDifficulty.coinMultiplier);
    if (boost != null) {
      coinProvider.configureSpawn(
        multiplier: _activeDifficulty.coinMultiplier * boost.coinMultiplier,
      );
    }
    coinProvider.setRestWindowActive(false);

    obstacleProvider.start(
      screenWidth: _screenSize.width,
      tutorialMode: isTutorialActive,
    );
    soundProvider.startBgm();

    unawaited(adManager.ensureBannerAd());

    unawaited(
      analytics.logGameStart(
        tutorialActive: isTutorialActive,
        revivesUnlocked: _activeUpgrades.maxRevives,
        inkMultiplier: _activeUpgrades.inkRegenMultiplier,
        totalCoins: metaProvider.totalCoins,
        missionsAvailable: metaProvider.hasDailyMissions,
      ),
    );

    _ticker!.start();

    notifyListeners();
    _markHudDirty();
  }

  void _gameLoop(Duration elapsed) {
    if (_gameState != GameState.running) {
      _ticker?.stop();
      return;
    }

    const maxDeltaMs = 1000.0 / 30.0;
    final now = DateTime.now();
    final double deltaMs;
    if (_lastFrameTimestamp == null) {
      deltaMs = 16.0;
    } else {
      final elapsedMs =
          now.difference(_lastFrameTimestamp!).inMilliseconds.toDouble();
      deltaMs = math.min(maxDeltaMs, math.max(0.0, elapsedMs));
    }
    _lastFrameTimestamp = now;
    final double dt = deltaMs / 16.0;

    _jumpBufferTimerMs = math.max(0.0, _jumpBufferTimerMs - deltaMs);
    _coyoteTimerMs = math.max(0.0, _coyoteTimerMs - deltaMs);
    _invulnerabilityMs = math.max(0.0, _invulnerabilityMs - deltaMs);

    final restBefore = _restWindowActive;
    if (_restWindowActive) {
      _restWindowElapsedMs += deltaMs;
      if (_restWindowElapsedMs >= _restDurationMs) {
        _restWindowActive = false;
        _restWindowElapsedMs = 0.0;
        _restTimerMs = 0.0;
      }
    } else {
      _restTimerMs += deltaMs;
      if (_restTimerMs >= _restIntervalMs) {
        _restWindowActive = true;
        _restWindowElapsedMs = 0.0;
      }
    }

    if (restBefore != _restWindowActive) {
      obstacleProvider.setRestMode(_restWindowActive);
      coinProvider.setRestWindowActive(_restWindowActive);
      _lastRestProgressNotified = 0.0;
      _markHudDirty();
      _pushToast(
        GameToast(
          message:
              _restWindowActive
                  ? 'Rest zone 窶・ink regen boosted'
                  : 'Speed resumes! Stay sharp',
          icon:
              _restWindowActive
                  ? Icons.self_improvement_rounded
                  : Icons.flash_on_rounded,
          color:
              _restWindowActive
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFFF97316),
        ),
      );
    }

    if (_activeRunBoost != null) {
      _boostRemainingMs = math.max(0.0, _boostRemainingMs - deltaMs);
      _markHudDirty();
      if (_boostRemainingMs <= 0) {
        _activeRunBoost = null;
        coinProvider.configureSpawn(
          multiplier: _activeDifficulty.coinMultiplier,
        );
        lineProvider.configureUpgrades(
          regenMultiplier: _activeUpgrades.inkRegenMultiplier,
        );
        _pushToast(
          const GameToast(
            message: 'Boost expired',
            icon: Icons.bolt_outlined,
            color: Color(0xFFFACC15),
          ),
        );
        _markHudDirty();
      }
    }

    final initialCoins = coinProvider.coinsCollected;

    // --- Updates ---
    lineProvider.updateLineLifetimes();
    if (_emergencyInkAvailable &&
        lineProvider.grantEmergencyInk(_remoteDifficulty.emergencyInkFloor)) {
      _emergencyInkAvailable = false;
      _pushToast(
        const GameToast(
          message: 'Auto-refill deployed',
          icon: Icons.water_drop_rounded,
          color: Color(0xFF22C55E),
          duration: Duration(milliseconds: 1800),
        ),
      );
      _markHudDirty();
    }
    obstacleProvider.update(
      deltaMs: deltaMs,
      screenWidth: _screenSize.width,
      tutorialMode: isTutorialActive,
      playerX: _playerX,
      restWindow: _restWindowActive,
    );
    if (_restWindowActive) {
      final progress = restWindowProgress;
      if ((progress - _lastRestProgressNotified).abs() >= 0.05) {
        _lastRestProgressNotified = progress;
        _markHudDirty();
      }
    }

    // --- Player physics ---
    _playerYSpeed += GameConstants.gravityPerFrame * dt;
    _playerY += _playerYSpeed * dt;

    if (lineProvider.lines.isNotEmpty) {
      _drawTimeMsThisRun += deltaMs.toInt();
    }

    bool onGround = false;
    // Check for collision with drawn lines
    for (final line in lineProvider.lines) {
      if (_playerX < line.minX - 24 || _playerX > line.maxX + 24) {
        continue;
      }
      for (int i = 0; i < line.points.length - 1; i++) {
        final Offset p1 = line.points[i];
        final Offset p2 = line.points[i + 1];
        final double deltaX = p2.dx - p1.dx;
        if (deltaX.abs() < 0.01) {
          continue;
        }
        if ((_playerX >= p1.dx && _playerX <= p2.dx) ||
            (_playerX >= p2.dx && _playerX <= p1.dx)) {
          final double progress = (_playerX - p1.dx) / deltaX;
          final double lineY = p1.dy + (p2.dy - p1.dy) * progress;
          if (_playerYSpeed >= 0 &&
              (_playerY > lineY - 25 && _playerY < lineY + 5)) {
            _playerY = lineY - 20;
            _playerYSpeed = 0;
            onGround = true;
            break;
          }
        }
      }
      if (onGround) break;
    }

    // Check for ground collision
    if (!onGround && _playerY >= GameConstants.playerStartY) {
      _playerY = GameConstants.playerStartY;
      _playerYSpeed = 0;
      onGround = true;
    }

    if (onGround) {
      _coyoteTimerMs = _baseCoyoteDurationMs;
    }

    bool didTriggerBufferedJump = false;
    if (_jumpBufferTimerMs > 0 && (onGround || _coyoteTimerMs > 0)) {
      _playerYSpeed = GameConstants.jumpVelocity;
      _jumpBufferTimerMs = 0.0;
      _coyoteTimerMs = 0.0;
      onGround = false;
      didTriggerBufferedJump = true;
    }

    if (didTriggerBufferedJump) {
      soundProvider.playJumpSfx();
      _emitHaptic();
      _jumpsThisRun++;
    }

    final Rect playerRect = Rect.fromLTWH(playerX - 15, playerY - 15, 30, 30);

    // --- Coin and Obstacle updates ---
    coinProvider.maybeSpawnCoin(
      deltaMs: deltaMs,
      screenWidth: _screenSize.width,
      screenHeight: _screenSize.height,
    );
    coinProvider.update(
      deltaMs: deltaMs,
      scrollSpeed: obstacleProvider.speed,
      playerRect: playerRect,
      screenWidth: _screenSize.width,
    );

    // Play coin sound if a coin was collected
    if (coinProvider.coinsCollected > initialCoins) {
      soundProvider.playCoinSfx();
      _emitHaptic();
    }

    bool collisionWarning = false;
    for (var obstacle in obstacleProvider.obstacles) {
      final obstacleRect = Rect.fromLTWH(
        obstacle.x,
        obstacle.y,
        obstacle.width,
        obstacle.height,
      );
      if (playerRect.overlaps(obstacleRect)) {
        if (_invulnerabilityMs > 0) {
          collisionWarning = true;
          if (!_invulnerabilityWarningShown) {
            _invulnerabilityWarningShown = true;
            _emitHaptic(heavy: true);
          }
          _invulnerabilityMs = 700.0;
          break;
        }
        _gameState = GameState.dead;
        obstacleProvider.stopSpawning();
        soundProvider.stopBgm();
        soundProvider.playGameOverSfx();
        _emitHaptic(heavy: true);
        final now = DateTime.now();
        if (_runStartTime != null) {
          _lastRunDuration = now.difference(_runStartTime!);
        }
        _lastRunAccident = _elapsedRunMs < 12000;
        _hasCompletedTutorial =
            _hasCompletedTutorial || (_didJumpThisRun && _didDrawLineThisRun);
        _hasBankedRewards = false;
        _ticker?.stop();
        notifyListeners();
        return;
      }
    }
    if (collisionWarning) {
      _markHudDirty();
    }

    // --- Difficulty Curve ---
    if (_score >= _nextSpeedRampScore) {
      _currentSpeedMultiplier = (_currentSpeedMultiplier + _speedRampIncrease)
          .clamp(GameConstants.absoluteMinSpeedMultiplier, _maxSpeedMultiplier);
      obstacleProvider.setSpeedMultiplier(_currentSpeedMultiplier);
      _nextSpeedRampScore += _remoteDifficulty.speedRampIntervalScore;
      _pushToast(
        const GameToast(
          message: 'Speed up!',
          icon: Icons.speed_rounded,
          color: Color(0xFFFB7185),
        ),
      );
      _markHudDirty();
    }

    _elapsedRunMs += deltaMs;
    _scoreAccumulator += dt;
    int scoreIncrements = 0;
    while (_scoreAccumulator >= 1.0) {
      _score++;
      scoreIncrements++;
      _scoreAccumulator -= 1.0;
    }
    if (scoreIncrements > 0) {
      _markHudDirty();
    }
    _markWorldDirty();
  }

  void revivePlayer() {
    if (_gameState != GameState.dead || !canRevive) return;

    _revivesUsedThisRun++;
    obstacleProvider.reset();
    lineProvider.clearAllLines();
    _playerY = GameConstants.playerStartY;
    _playerYSpeed = 0.0;
    _gameState = GameState.running;
    _jumpBufferTimerMs = 0.0;
    _coyoteTimerMs = _baseCoyoteDurationMs;
    _lastFrameTimestamp = null;
    _runStartTime = DateTime.now().subtract(_lastRunDuration);
    _restTimerMs = 0.0;
    _restWindowElapsedMs = 0.0;
    _restWindowActive = false;
    coinProvider
      ..setRestWindowActive(false)
      ..configureSpawn(multiplier: _activeDifficulty.coinMultiplier);
    obstacleProvider.configureDifficulty(
      speedMultiplier: _activeDifficulty.speedMultiplier,
      densityMultiplier: _activeDifficulty.densityMultiplier,
      safeWindow: _activeDifficulty.safeWindowPx,
      startGrace: const Duration(milliseconds: 800),
    );
    obstacleProvider.start(
      screenWidth: _screenSize.width,
      tutorialMode: isTutorialActive,
    );
    _invulnerabilityMs = 1500.0;
    _invulnerabilityWarningShown = false;
    soundProvider.startBgm();
    _ticker?.start();

    notifyListeners();
  }

  void _emitHaptic({bool heavy = false}) {
    final strength = metaProvider.hapticStrength;
    if (strength <= 0.05) {
      return;
    }
    if (heavy) {
      if (strength > 0.8) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } else {
      if (strength < 0.4) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  void jump() {
    if (_gameState != GameState.running) {
      return;
    }
    _jumpBufferTimerMs = _jumpBufferDurationMs;
    if (!_didJumpThisRun) {
      _didJumpThisRun = true;
      notifyListeners();
    }
  }

  void markLineUsed() {
    if (_gameState != GameState.running) {
      return;
    }
    if (!_didDrawLineThisRun) {
      _didDrawLineThisRun = true;
      notifyListeners();
    }
  }

  Future<void> finalizeRun({required MetaProvider metaProvider}) async {
    if (_gameState != GameState.dead || _hasBankedRewards) {
      return;
    }
    final stats = _buildRunStats();
    final completedBefore =
        metaProvider.dailyMissions.where((mission) => mission.completed).length;
    if (stats.coins > 0) {
      await metaProvider.addCoins(stats.coins);
    }
    _lastRunBonusCoins = _resolveScoreBonus(stats.score);
    if (_lastRunBonusCoins > 0) {
      await metaProvider.addCoins(_lastRunBonusCoins);
    }
    _updateNextBonusTarget(stats.score);
    metaProvider.applyRunStats(stats);
    final completedAfter =
        metaProvider.dailyMissions.where((mission) => mission.completed).length;
    _recentRuns.insert(0, stats);
    if (_recentRuns.length > GameConstants.maxRecentRunsTracked) {
      _recentRuns.removeLast();
    }
    if (stats.accidentDeath) {
      _accidentStreak++;
      if (_accidentStreak >= GameConstants.accidentStreakGraceThreshold) {
        _nextRunGrace = GameConstants.accidentGraceDuration;
        _accidentStreak = 0;
      }
    } else {
      _accidentStreak = 0;
    }
    adManager.registerGameOver(_lastRunDuration);
    final missionsCompletedDelta = math.max(
      0,
      completedAfter - completedBefore,
    );
    final totalCoinsAfterRun = metaProvider.totalCoins;
    if (stats.coins > 0) {
      unawaited(
        analytics.logCoinsCollected(
          amount: stats.coins,
          totalCoins: totalCoinsAfterRun,
          source: 'run',
        ),
      );
    }
    unawaited(
      analytics.logGameEnd(
        stats: stats,
        revivesUsed: _revivesUsedThisRun,
        totalCoins: totalCoinsAfterRun,
        missionsCompletedDelta: missionsCompletedDelta,
      ),
    );
    _hasBankedRewards = true;
    _markHudDirty();
  }

  void resetGame() {
    _gameState = GameState.ready;
    _score = 0;
    _playerY = GameConstants.playerStartY;
    _playerYSpeed = 0.0;
    _jumpBufferTimerMs = 0.0;
    _coyoteTimerMs = 0.0;
    _lastFrameTimestamp = null;
    _runStartTime = null;
    _elapsedRunMs = 0.0;
    _didJumpThisRun = false;
    _didDrawLineThisRun = false;
    _lastRunDuration = Duration.zero;
    _hasBankedRewards = false;
    _ticker?.stop();
    lineProvider.clearAllLines();
    obstacleProvider.reset();
    coinProvider.reset();
    soundProvider.stopBgm();
    _revivesUsedThisRun = 0;
    _restWindowActive = false;
    coinProvider.setRestWindowActive(false);
    obstacleProvider.setRestMode(false);
    _scoreAccumulator = 0.0;
    _activeRunBoost = null;
    _boostRemainingMs = 0.0;
    notifyListeners();
  }

  RunStats _buildRunStats() {
    return RunStats(
      duration: _lastRunDuration,
      score: _score,
      coins: coinProvider.coinsCollected,
      usedLine: _didDrawLineThisRun,
      jumpsPerformed: _jumpsThisRun,
      drawTimeMs: _drawTimeMsThisRun,
      accidentDeath: _lastRunAccident,
    );
  }

  _DifficultyTuning _evaluateDifficulty() {
    if (_recentRuns.isEmpty) {
      return _DifficultyTuning(
        speedMultiplier: 1.0,
        densityMultiplier: 1.0,
        coinMultiplier: 1.0,
        safeWindowPx: _difficultyTuning.emptyHistorySafeWindowPx,
      );
    }
    final recent =
        _recentRuns.take(GameConstants.difficultySampleSize).toList();
    final avgDurationSeconds =
        recent.map((r) => r.duration.inSeconds).fold<int>(0, (a, b) => a + b) /
        recent.length;
    final avgScore =
        recent.map((r) => r.score).fold<int>(0, (a, b) => a + b) /
        recent.length;
    final accidentRate =
        recent.where((r) => r.accidentDeath).length / recent.length;

    double speed = 1.0;
    double density = 1.0;
    double coin = 1.0;
    double safeWindow = _difficultyTuning.defaultSafeWindowPx;

    if (avgDurationSeconds > _difficultyTuning.longRunDurationSeconds) {
      speed += _difficultyTuning.longRunSpeedDelta;
      density += _difficultyTuning.longRunDensityDelta;
      coin += _difficultyTuning.longRunCoinDelta;
    } else if (avgDurationSeconds < _difficultyTuning.shortRunDurationSeconds) {
      speed += _difficultyTuning.shortRunSpeedDelta;
      density += _difficultyTuning.shortRunDensityDelta;
      coin += _difficultyTuning.shortRunCoinDelta;
    }

    if (accidentRate > _difficultyTuning.highAccidentRate) {
      speed += _difficultyTuning.highAccidentSpeedDelta;
      density += _difficultyTuning.highAccidentDensityDelta;
      safeWindow += _difficultyTuning.highAccidentSafeWindowDelta;
      coin += _difficultyTuning.highAccidentCoinDelta;
    } else if (accidentRate < _difficultyTuning.lowAccidentRate &&
        avgDurationSeconds > _difficultyTuning.consistentRunDurationSeconds) {
      speed += _difficultyTuning.lowAccidentSpeedDelta;
      density += _difficultyTuning.lowAccidentDensityDelta;
    }

    if (avgScore > _difficultyTuning.highScoreThreshold) {
      density += _difficultyTuning.highScoreDensityDelta;
      coin += _difficultyTuning.highScoreCoinDelta;
    } else if (avgScore < _difficultyTuning.lowScoreThreshold) {
      density += _difficultyTuning.lowScoreDensityDelta;
      coin += _difficultyTuning.lowScoreCoinDelta;
    }

    return _DifficultyTuning(
      speedMultiplier: speed.clamp(
        _difficultyTuning.minSpeedMultiplier,
        _difficultyTuning.maxSpeedMultiplier,
      ),
      densityMultiplier: density.clamp(
        _difficultyTuning.minDensityMultiplier,
        _difficultyTuning.maxDensityMultiplier,
      ),
      coinMultiplier: coin.clamp(
        _difficultyTuning.minCoinMultiplier,
        _difficultyTuning.maxCoinMultiplier,
      ),
      safeWindowPx: safeWindow.clamp(
        _difficultyTuning.minSafeWindowPx,
        _difficultyTuning.maxSafeWindowPx,
      ),
    );
  }

  @visibleForTesting
  void setDifficultyTuningForTesting(DifficultyTuningRemoteConfig tuning) {
    _difficultyTuning = tuning;
  }

  @visibleForTesting
  void setRecentRunsForTesting(List<RunStats> runs) {
    _recentRuns
      ..clear()
      ..addAll(runs);
  }

  @visibleForTesting
  _DifficultyTuning evaluateDifficultyForTesting() {
    return _evaluateDifficulty();
  }

  // Called by ChangeNotifierProxyProvider when dependencies change.
  void updateDependencies(
    AdManager ad,
    LineProvider line,
    ObstacleProvider obstacle,
    CoinProvider coin,
    MetaProvider meta,
    RemoteConfigService remote,
  ) {
    adManager = ad;
    lineProvider = line;
    obstacleProvider = obstacle;
    coinProvider = coin;
    metaProvider = meta;
    remoteConfigProvider = remote;
    _applyRemoteDifficulty(remote.difficulty);
    _difficultyTuning = remote.difficultyTuning;
    if (_gameState == GameState.running) {
      _currentSpeedMultiplier = _currentSpeedMultiplier.clamp(
        GameConstants.absoluteMinSpeedMultiplier,
        _maxSpeedMultiplier,
      );
      obstacleProvider.setSpeedMultiplier(_currentSpeedMultiplier);
    }
  }

  void handleAppLifecyclePause() {
    _ticker?.stop();
    soundProvider.pauseBgmForInterruption();
  }

  void handleAppLifecycleResume() {
    if (_gameState == GameState.running) {
      _ticker?.start();
      soundProvider.resumeBgmAfterInterruption();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    soundProvider.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }
}
