
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'ad_provider.dart';
import 'coin_provider.dart';
import 'game_models.dart';
import 'line_provider.dart';
import 'meta_provider.dart';
import 'obstacle_provider.dart';
import 'sound_provider.dart';

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
  final double _playerX = 100.0;
  double _playerY = 380.0;
  double _playerYSpeed = 0.0;
  int _score = 0;
  Ticker? _ticker;
  Size _screenSize = Size.zero;
  double _baseCoyoteDurationMs = 120.0;
  static const double _jumpBufferDurationMs = 100.0;
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
  _DifficultyTuning _activeDifficulty = const _DifficultyTuning(
    speedMultiplier: 1.0,
    densityMultiplier: 1.0,
    coinMultiplier: 1.0,
    safeWindowPx: 180,
  );
  UpgradeSnapshot _activeUpgrades =
      const UpgradeSnapshot(inkRegenMultiplier: 1, maxRevives: 1, coyoteBonusMs: 0);

  // Providers
  AdProvider adProvider;
  LineProvider lineProvider;
  ObstacleProvider obstacleProvider;
  CoinProvider coinProvider;
  MetaProvider metaProvider;
  SoundProvider soundProvider;

  GameProvider({
    required this.adProvider,
    required this.lineProvider,
    required this.obstacleProvider,
    required this.coinProvider,
    required this.metaProvider,
    required this.soundProvider,
    required TickerProvider vsync,
  }) {
    _ticker = vsync.createTicker(_gameLoop);
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
      isTutorialActive && !_didDrawLineThisRun &&
      _elapsedRunMs >= 5000 && _elapsedRunMs <= 18000;
  bool get isRestWindow => _restWindowActive;
  double get restWindowProgress =>
      _restWindowActive ? (_restWindowElapsedMs / _restDurationMs).clamp(0.0, 1.0) : 0.0;
  bool get canRevive => _revivesUsedThisRun < _activeUpgrades.maxRevives;

  static const double _restIntervalMs = 30000.0;
  static const double _restDurationMs = 6000.0;

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
    _playerY = 380.0;
    _playerYSpeed = 0.0;
    _jumpBufferTimerMs = 0.0;
    _activeUpgrades = metaProvider.upgradeSnapshot;
    _baseCoyoteDurationMs = 120.0 + _activeUpgrades.coyoteBonusMs;
    _coyoteTimerMs = _baseCoyoteDurationMs;
    _lastFrameTimestamp = null;
    _runStartTime = DateTime.now();
    _elapsedRunMs = 0.0;
    _restTimerMs = 0.0;
    _restWindowElapsedMs = 0.0;
    _restWindowActive = false;
    obstacleProvider.setRestMode(false);
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

    metaProvider.refreshDailyMissionsIfNeeded();

    lineProvider
      ..configureUpgrades(regenMultiplier: _activeUpgrades.inkRegenMultiplier)
      ..clearAllLines();
    obstacleProvider.reset();
    coinProvider
      ..reset()
      ..configureSpawn(multiplier: 1.0);

    _activeDifficulty = _evaluateDifficulty();
    final startGrace = _nextRunGrace;
    _nextRunGrace = Duration.zero;

    obstacleProvider.configureDifficulty(
      speedMultiplier: _activeDifficulty.speedMultiplier,
      densityMultiplier: _activeDifficulty.densityMultiplier,
      safeWindow: _activeDifficulty.safeWindowPx,
      startGrace: startGrace,
    );
    coinProvider.configureSpawn(multiplier: _activeDifficulty.coinMultiplier);
    coinProvider.setRestWindowActive(false);

    obstacleProvider.start(
      screenWidth: _screenSize.width,
      tutorialMode: isTutorialActive,
    );
    soundProvider.startBgm();

    adProvider.loadInterstitialAd();

    _ticker!.start();

    notifyListeners();
  }

  void _gameLoop(Duration elapsed) {
    if (_gameState != GameState.running) {
      _ticker?.stop();
      return;
    }

    final now = DateTime.now();
    final double deltaMs;
    if (_lastFrameTimestamp == null) {
      deltaMs = 16.0;
    } else {
      final elapsedMs =
          now.difference(_lastFrameTimestamp!).inMilliseconds.toDouble();
      deltaMs = math.min(200.0, math.max(0.0, elapsedMs));
    }
    _lastFrameTimestamp = now;

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
    }

    final initialCoins = coinProvider.coinsCollected;

    // --- Updates ---
    lineProvider.updateLineLifetimes();
    obstacleProvider.update(
      deltaMs: deltaMs,
      screenWidth: _screenSize.width,
      tutorialMode: isTutorialActive,
      playerX: _playerX,
      restWindow: _restWindowActive,
    );

    // --- Player physics ---
    _playerYSpeed += 0.5; // Gravity
    _playerY += _playerYSpeed;

    if (lineProvider.lines.isNotEmpty) {
      _drawTimeMsThisRun += deltaMs.toInt();
    }

    bool onGround = false;
    // Check for collision with drawn lines
    for (final line in lineProvider.lines) {
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
          if (_playerYSpeed >= 0 && (_playerY > lineY - 25 && _playerY < lineY + 5)) {
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
    if (!onGround && _playerY >= 380) {
      _playerY = 380;
      _playerYSpeed = 0;
      onGround = true;
    }

    if (onGround) {
      _coyoteTimerMs = _baseCoyoteDurationMs;
    }

    bool didTriggerBufferedJump = false;
    if (_jumpBufferTimerMs > 0 && (onGround || _coyoteTimerMs > 0)) {
      _playerYSpeed = -12.0;
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
    coinProvider.maybeSpawnCoin(_screenSize.width, _screenSize.height);
    coinProvider.update(obstacleProvider.speed, playerRect, _screenSize.width);

    // Play coin sound if a coin was collected
    if (coinProvider.coinsCollected > initialCoins) {
      soundProvider.playCoinSfx();
      _emitHaptic();
    }

    bool collisionWarning = false;
    for (var obstacle in obstacleProvider.obstacles) {
      final obstacleRect =
          Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height);
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
        adProvider.loadRewardAd();
        notifyListeners();
        return;
      }
    }
    if (collisionWarning) {
      notifyListeners();
    }
    
    // --- Difficulty Curve ---
    if (_score > 0 && _score % 500 == 0) {
      obstacleProvider.increaseSpeed();
    }

    _elapsedRunMs += deltaMs;
    _score++;
    notifyListeners();
  }

  void revivePlayer() {
    if (_gameState != GameState.dead || !canRevive) return;

    _revivesUsedThisRun++;
    obstacleProvider.reset();
    lineProvider.clearAllLines();
    _playerY = 380.0;
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
    if (stats.coins > 0) {
      await metaProvider.addCoins(stats.coins);
    }
    metaProvider.applyRunStats(stats);
    _recentRuns.insert(0, stats);
    if (_recentRuns.length > 5) {
      _recentRuns.removeLast();
    }
    if (stats.accidentDeath) {
      _accidentStreak++;
      if (_accidentStreak >= 2) {
        _nextRunGrace = const Duration(seconds: 5);
        _accidentStreak = 0;
      }
    } else {
      _accidentStreak = 0;
    }
    adProvider.registerRunEnd(_lastRunDuration);
    _hasBankedRewards = true;
  }

  void resetGame() {
    _gameState = GameState.ready;
    _score = 0;
    _playerY = 380.0;
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
      return const _DifficultyTuning(
        speedMultiplier: 1.0,
        densityMultiplier: 1.0,
        coinMultiplier: 1.0,
        safeWindowPx: 200,
      );
    }
    final recent = _recentRuns.take(3).toList();
    final avgDurationSeconds = recent
            .map((r) => r.duration.inSeconds)
            .fold<int>(0, (a, b) => a + b) /
        recent.length;
    final avgScore = recent
            .map((r) => r.score)
            .fold<int>(0, (a, b) => a + b) /
        recent.length;
    final accidentRate =
        recent.where((r) => r.accidentDeath).length / recent.length;

    double speed = 1.0;
    double density = 1.0;
    double coin = 1.0;
    double safeWindow = 180.0;

    if (avgDurationSeconds > 45) {
      speed += 0.18;
      density += 0.12;
      coin -= 0.12;
    } else if (avgDurationSeconds < 20) {
      speed -= 0.12;
      density -= 0.18;
      coin += 0.18;
    }

    if (accidentRate > 0.66) {
      speed -= 0.15;
      density -= 0.18;
      safeWindow += 60;
      coin += 0.15;
    } else if (accidentRate < 0.2 && avgDurationSeconds > 30) {
      speed += 0.08;
      density += 0.1;
    }

    if (avgScore > 900) {
      density += 0.08;
      coin -= 0.08;
    } else if (avgScore < 300) {
      density -= 0.1;
      coin += 0.12;
    }

    return _DifficultyTuning(
      speedMultiplier: speed.clamp(0.7, 1.6),
      densityMultiplier: density.clamp(0.6, 1.8),
      coinMultiplier: coin.clamp(0.7, 1.8),
      safeWindowPx: safeWindow.clamp(140, 260),
    );
  }
  
  // Called by ChangeNotifierProxyProvider when dependencies change.
  void updateDependencies(
    AdProvider ad,
    LineProvider line,
    ObstacleProvider obstacle,
    CoinProvider coin,
    MetaProvider meta,
  ) {
    adProvider = ad;
    lineProvider = line;
    obstacleProvider = obstacle;
    coinProvider = coin;
    metaProvider = meta;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    soundProvider.dispose();
    super.dispose();
  }
}
