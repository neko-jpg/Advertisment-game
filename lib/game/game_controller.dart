import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/analytics/analytics_service.dart';
import '../services/ad_service.dart';
import '../services/player_wallet.dart';
import 'audio/sound_controller.dart';
import 'models.dart';
import 'models/game_models.dart' show RunStats;

enum GamePhase { loading, ready, running, gameOver }

enum TutorialStage { intro, jump, draw, coin, complete }

class GameController extends ChangeNotifier {
  GameController({
    required this.vsync,
    required this.soundController,
    required this.adService,
    required this.analytics,
    required this.wallet,
  }) {
    _ticker = vsync.createTicker(_handleTick);
  }

  final TickerProvider vsync;
  final SoundController soundController;
  final AdService adService;
  final AnalyticsService analytics;
  final PlayerWallet wallet;

  late final Ticker _ticker;
  GamePhase _phase = GamePhase.loading;

  Size _viewport = Size.zero;
  double _groundY = 0;
  static const double _groundHeight = 96;

  Offset _playerPosition = Offset.zero;
  static const double _playerRadius = 18;
  double _velocityY = 0;
  bool _onGround = false;
  double _coyoteTimer = 0;
  static const double _coyoteDuration = 0.12;

  static const double _gravity = 1650;
  static const double _jumpVelocity = -720;

  final List<DrawnLine> _lines = <DrawnLine>[];
  DrawnLine? _activeLine;
  double _ink = 1.0;
  double _inkCooldown = 0.0;
  double _inkRechargeDelay = 0.0;
  static const double _lineLifetimeSeconds = 2.2;
  static const double _lineCooldownSeconds = 0.6;
  static const double _inkRechargePerSecond = 0.68;
  static const double _inkDrawCostPerSecond = 0.82;
  static const double _inkRechargeDelaySeconds = 0.35;

  final List<Obstacle> _obstacles = <Obstacle>[];
  final List<Coin> _coins = <Coin>[];
  final math.Random _random = math.Random();

  double _scrollSpeed = 240;
  double _spawnTimer = 0;
  double _scoreAccumulator = 0;
  int _score = 0;
  int _coinsCollected = 0;
  int _lastRunAwardedCoins = 0;
  int _bestScore = 0;
  DateTime? _runStartedAt;
  Duration _lastRunDuration = Duration.zero;
  bool _pausedForLifecycle = false;
  TutorialStage _tutorialStage = TutorialStage.intro;
  bool _tutorialCompleted = false;
  ObstacleBehavior? _lastDeathCause;
  int _jumpsPerformed = 0;
  double _drawTimeMs = 0;
  bool _usedLineThisRun = false;

  bool _reviveAvailable = true;
  bool _rewardInFlight = false;

  SharedPreferences? _prefs;
  Duration? _lastTick;

  GamePhase get phase => _phase;
  Size get viewport => _viewport;
  Offset get playerPosition => _playerPosition;
  double get playerRadius => _playerRadius;
  double get groundY => _groundY;
  double get inkLevel => _ink.clamp(0.0, 1.0);
  int get score => _score;
  int get bestScore => _bestScore;
  int get coinsCollected => _coinsCollected;
  int get lastRunAwardedCoins => _lastRunAwardedCoins;
  int get totalCoins => wallet.totalCoins;
  Duration get lastRunDuration => _lastRunDuration;
  bool get reviveAvailable => _reviveAvailable;
  bool get rewardInFlight => _rewardInFlight;
  TutorialStage get tutorialStage => _tutorialStage;
  bool get tutorialCompleted => _tutorialCompleted;
  bool get tutorialActive => !_tutorialCompleted;

  UnmodifiableListView<DrawnLine> get lines => UnmodifiableListView(_lines);
  UnmodifiableListView<Obstacle> get obstacles =>
      UnmodifiableListView(_obstacles);
  UnmodifiableListView<Coin> get coins => UnmodifiableListView(_coins);

  Future<void> initialize() async {
    _phase = GamePhase.loading;
    notifyListeners();

    await wallet.ensureReady();

    try {
      _prefs = await SharedPreferences.getInstance();
      _bestScore = _prefs?.getInt('qdd_best_score') ?? 0;
      final tutorialDone = _prefs?.getBool('qdd_tutorial_complete') ?? false;
      if (tutorialDone) {
        _tutorialStage = TutorialStage.complete;
        _tutorialCompleted = true;
      } else {
        _tutorialStage = TutorialStage.intro;
        _tutorialCompleted = false;
      }
    } catch (error, stackTrace) {
      debugPrint('QuickDrawDash: failed to load preferences - $error');
      debugPrintStack(stackTrace: stackTrace);
      _bestScore = 0;
    }

    _phase = GamePhase.ready;
    notifyListeners();
  }

  void _advanceTutorial(TutorialStage stage) {
    if (_tutorialCompleted && stage == TutorialStage.complete) {
      return;
    }
    if (_tutorialStage == stage) {
      return;
    }
    if (_tutorialCompleted && stage != TutorialStage.complete) {
      return;
    }
    _tutorialStage = stage;
    if (stage == TutorialStage.complete) {
      _tutorialCompleted = true;
      unawaited(_prefs?.setBool('qdd_tutorial_complete', true));
    }
    notifyListeners();
  }

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    if (_viewport == size) {
      return;
    }
    _viewport = size;
    _groundY = size.height - _groundHeight - _playerRadius;
    if (_phase != GamePhase.running) {
      _playerPosition = Offset(size.width * 0.22, _groundY);
    }
    notifyListeners();
  }

  void startGame() {
    if (_viewport == Size.zero) {
      return;
    }
    _resetRunState();
    _runStartedAt = DateTime.now();
    _jumpsPerformed = 0;
    _drawTimeMs = 0;
    _usedLineThisRun = false;
    _lastDeathCause = null;
    _phase = GamePhase.running;
    _ticker.start();
    _lastTick = null;
    soundController.startBgm();
    if (!_tutorialCompleted && _tutorialStage == TutorialStage.intro) {
      _advanceTutorial(TutorialStage.jump);
    } else {
      notifyListeners();
    }
    unawaited(
      analytics.logGameStart(
        tutorialActive: !_tutorialCompleted,
        revivesUnlocked: _reviveAvailable ? 1 : 0,
        inkMultiplier: 1.0,
        totalCoins: wallet.totalCoins,
        missionsAvailable: false,
      ),
    );
  }

  void backToMenu() {
    if (_phase == GamePhase.running) {
      _ticker.stop();
      soundController.stopBgm();
    }
    _phase = GamePhase.ready;
    _runStartedAt = null;
    _pausedForLifecycle = false;
    notifyListeners();
  }

  void jump() {
    if (_phase != GamePhase.running) {
      return;
    }
    final bool canJump = _onGround || _coyoteTimer > 0;
    if (!canJump) {
      return;
    }
    _velocityY = _jumpVelocity;
    _onGround = false;
    _coyoteTimer = 0;
    _jumpsPerformed += 1;
    if (!_tutorialCompleted && _tutorialStage == TutorialStage.jump) {
      _advanceTutorial(TutorialStage.draw);
    }
    soundController.playJumpSfx();
  }

  bool startLine(Offset position) {
    if (_phase != GamePhase.running) {
      return false;
    }
    if (_ink < 0.18 || _inkCooldown > 0) {
      return false;
    }
    if (position.dx < _viewport.width * 0.45) {
      return false;
    }
    _activeLine = DrawnLine(points: <Offset>[position]);
    _lines.add(_activeLine!);
    _usedLineThisRun = true;
    _ink = math.max(0, _ink - 0.12);
    _inkRechargeDelay = _inkRechargeDelaySeconds;
    var advanced = false;
    if (!_tutorialCompleted && _tutorialStage == TutorialStage.draw) {
      _advanceTutorial(TutorialStage.coin);
      advanced = true;
    }
    if (!advanced) {
      notifyListeners();
    }
    return true;
  }

  void extendLine(Offset position) {
    if (_phase != GamePhase.running) {
      return;
    }
    final DrawnLine? line = _activeLine;
    if (line == null) {
      return;
    }
    final List<Offset> points = line.points;
    if (points.isEmpty || (points.last - position).distance > 4) {
      points.add(position);
      notifyListeners();
    }
  }

  void endLine() {
    if (_activeLine == null) {
      return;
    }
    if (_activeLine!.points.length < 2) {
      _lines.remove(_activeLine);
    }
    _activeLine = null;
    _inkCooldown = _lineCooldownSeconds;
    _inkRechargeDelay = _inkRechargeDelaySeconds;
    notifyListeners();
  }

  Future<bool> revive() async {
    if (!canRevive) {
      return false;
    }
    if (_rewardInFlight) {
      return false;
    }
    final Duration carriedRunDuration = _lastRunDuration;
    _rewardInFlight = true;
    notifyListeners();
    var rewarded = false;
    try {
      rewarded = await adService.showRewarded(
        onReward: () {
          rewarded = true;
        },
        placement: 'revive',
      );
    } finally {
      _rewardInFlight = false;
      notifyListeners();
    }
    if (!rewarded) {
      return false;
    }
    _reviveAvailable = false;
    _phase = GamePhase.running;
    _runStartedAt = DateTime.now().subtract(carriedRunDuration);
    _pausedForLifecycle = false;
    _playerPosition = Offset(_viewport.width * 0.22, _groundY);
    _velocityY = _jumpVelocity * 0.6;
    _onGround = false;
    _coyoteTimer = _coyoteDuration;
    _lines.clear();
    _activeLine = null;
    _ink = 1.0;
    _inkCooldown = 0;
    _obstacles.removeWhere(
      (obstacle) => obstacle.rect.left < _playerPosition.dx + 120,
    );
    _coins.removeWhere((coin) => coin.position.dx < _playerPosition.dx + 120);
    _scrollSpeed = math.max(220, _scrollSpeed * 0.85);
    _lastTick = null;
    _ticker.start();
    soundController.startBgm();
    notifyListeners();
    return true;
  }

  bool get canRevive =>
      _phase == GamePhase.gameOver &&
      _reviveAvailable &&
      adService.hasRewardedAd;

  void _resetRunState() {
    _lines.clear();
    _obstacles.clear();
    _coins.clear();
    _activeLine = null;
    _ink = 1.0;
    _inkCooldown = 0;
    _scrollSpeed = 240;
    _spawnTimer = 1.0;
    _score = 0;
    _scoreAccumulator = 0;
    _coinsCollected = 0;
    _lastRunAwardedCoins = 0;
    _reviveAvailable = true;
    _playerPosition = Offset(_viewport.width * 0.22, _groundY);
    _velocityY = 0;
    _onGround = true;
    _coyoteTimer = _coyoteDuration;
    _runStartedAt = DateTime.now();
    _lastRunDuration = Duration.zero;
    _pausedForLifecycle = false;
    _inkRechargeDelay = 0;
    _jumpsPerformed = 0;
    _drawTimeMs = 0;
    _usedLineThisRun = false;
    _lastDeathCause = null;
  }

  void _handleTick(Duration elapsed) {
    if (_phase != GamePhase.running) {
      return;
    }
    final Duration? lastTick = _lastTick;
    _lastTick = elapsed;
    final double dt =
        lastTick == null
            ? 1 / 60
            : (elapsed - lastTick).inMicroseconds /
                Duration.microsecondsPerSecond;
    final double clampedDt = dt.clamp(0.0, 1 / 30);
    _update(clampedDt);
  }

  void _update(double dt) {
    // Physics
    _velocityY += _gravity * dt;
    _playerPosition = _playerPosition.translate(0, _velocityY * dt);

    final double groundLine = _groundY;
    if (_playerPosition.dy > groundLine) {
      _playerPosition = Offset(_playerPosition.dx, groundLine);
      _velocityY = 0;
      if (!_onGround) {
        _onGround = true;
        _coyoteTimer = _coyoteDuration;
      }
    } else {
      if (_onGround) {
        _onGround = false;
      }
      if (_coyoteTimer > 0) {
        _coyoteTimer = math.max(0, _coyoteTimer - dt);
      }
    }

    _updateLines(dt);
    _applyLineSupport();

    _updateInk(dt);
    _updateObstacles(dt);
    _updateCoins(dt);
    _updateScore(dt);

    final Obstacle? obstacleHit = _checkObstacleCollision();
    if (obstacleHit != null) {
      _lastDeathCause = obstacleHit.behavior;
      _finishRun();
      return;
    }

    notifyListeners();
  }

  void _updateLines(double dt) {
    final DateTime now = DateTime.now();
    _lines.removeWhere(
      (line) =>
          now.difference(line.createdAt).inMilliseconds >
          (_lineLifetimeSeconds * 1000).round(),
    );
  }

  void _applyLineSupport() {
    if (_lines.isEmpty) {
      return;
    }
    final double playerBottom = _playerPosition.dy + _playerRadius;
    for (final DrawnLine line in _lines) {
      final List<Offset> points = line.points;
      for (var i = 0; i < points.length - 1; i++) {
        final Offset start = points[i];
        final Offset end = points[i + 1];
        final double minX = math.min(start.dx, end.dx) - 8;
        final double maxX = math.max(start.dx, end.dx) + 8;
        if (_playerPosition.dx < minX || _playerPosition.dx > maxX) {
          continue;
        }
        final double dx = end.dx - start.dx;
        if (dx.abs() < 0.001) {
          continue;
        }
        final double t = (_playerPosition.dx - start.dx) / dx;
        final double yOnLine = start.dy + (end.dy - start.dy) * t;
        if (_velocityY >= 0 &&
            playerBottom >= yOnLine - 6 &&
            playerBottom <= yOnLine + 24) {
          _playerPosition = Offset(_playerPosition.dx, yOnLine - _playerRadius);
          _velocityY = 0;
          _onGround = true;
          _coyoteTimer = _coyoteDuration;
          return;
        }
      }
    }
  }

  void _updateInk(double dt) {
    if (_activeLine != null) {
      _drawTimeMs += dt * 1000;
      _ink = math.max(0, _ink - _inkDrawCostPerSecond * dt);
      _inkRechargeDelay = _inkRechargeDelaySeconds;
      if (_ink <= 0) {
        endLine();
      }
    } else {
      if (_inkRechargeDelay > 0) {
        _inkRechargeDelay = math.max(0, _inkRechargeDelay - dt);
      }
      if (_inkCooldown > 0) {
        _inkCooldown = math.max(0, _inkCooldown - dt);
      }
      if (_inkRechargeDelay <= 0 && _ink < 1.0) {
        final double regenMultiplier = _onGround ? 1.0 : 0.72;
        _ink = math.min(
          1.0,
          _ink + _inkRechargePerSecond * regenMultiplier * dt,
        );
      }
    }
  }

  void _updateObstacles(double dt) {
    final double shift = -_scrollSpeed * dt;
    for (final obstacle in _obstacles) {
      obstacle.translate(shift);
      obstacle.update(dt);
    }
    _obstacles.removeWhere((obstacle) => obstacle.rect.right < -80);

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnObstacle();
      final double difficulty = math.min(1.25, 0.6 + _scrollSpeed / 420);
      final double baseGap = (0.9 + _random.nextDouble() * 0.6) / difficulty;
      _spawnTimer = baseGap + (_tutorialCompleted ? 0 : 0.4);
    }

    _scrollSpeed = math.min(540, _scrollSpeed + dt * 6);
  }

  void _updateCoins(double dt) {
    final double shift = -_scrollSpeed * dt;
    for (final coin in _coins) {
      coin.translate(shift);
    }
    _coins.removeWhere((coin) => coin.position.dx < -coin.radius * 2);

    _coins.removeWhere((coin) {
      final double dx = coin.position.dx - _playerPosition.dx;
      final double dy = coin.position.dy - _playerPosition.dy;
      final double distanceSq = dx * dx + dy * dy;
      if (distanceSq <= math.pow(_playerRadius + coin.radius, 2)) {
        _coinsCollected += 1;
        soundController.playCoinSfx();
        if (!_tutorialCompleted && _tutorialStage == TutorialStage.coin) {
          _advanceTutorial(TutorialStage.complete);
        }
        unawaited(
          analytics.logCoinsCollected(
            amount: 1,
            totalCoins: wallet.totalCoins,
            source: 'run',
          ),
        );
        return true;
      }
      return false;
    });
  }

  void _updateScore(double dt) {
    _scoreAccumulator += _scrollSpeed * dt * 0.02;
    if (_scoreAccumulator >= 1) {
      final int delta = _scoreAccumulator.floor();
      _score += delta;
      _scoreAccumulator -= delta;
    }
  }

  Obstacle? _checkObstacleCollision() {
    for (final obstacle in _obstacles) {
      if (_circleRectIntersect(
        center: _playerPosition,
        radius: _playerRadius,
        rect: obstacle.rect,
      )) {
        return obstacle;
      }
    }
    return null;
  }

  void _spawnObstacle() {
    if (_viewport == Size.zero) {
      return;
    }
    Obstacle obstacle;
    if (!_tutorialCompleted) {
      switch (_tutorialStage) {
        case TutorialStage.draw:
          obstacle = _buildHoveringShard();
          break;
        case TutorialStage.coin:
          obstacle = _buildGroundBlock(gentle: true);
          break;
        case TutorialStage.jump:
        case TutorialStage.intro:
        default:
          obstacle = _buildGroundBlock(gentle: true);
      }
    } else {
      final bool earlySession = _score < 180;
      final double roll = _random.nextDouble();
      if (earlySession || roll > 0.75) {
        obstacle = _buildGroundBlock(gentle: earlySession);
      } else if (roll < 0.28) {
        obstacle = _buildMovingHazard();
      } else if (roll < 0.5) {
        obstacle = _buildCeilingBarrier();
      } else {
        obstacle = _buildHoveringShard();
      }
    }
    _obstacles.add(obstacle);

    if (!_tutorialCompleted && _tutorialStage == TutorialStage.coin) {
      _spawnCoinTrail(obstacle, ascending: true);
      return;
    }

    final double coinRoll = _random.nextDouble();
    if (obstacle.behavior == ObstacleBehavior.groundBlock) {
      if (coinRoll < 0.55) {
        _spawnCoinTrail(obstacle, ascending: coinRoll < 0.3);
      } else if (coinRoll < 0.85) {
        final double coinY = math.max(60, obstacle.rect.top - 56);
        final double coinX = obstacle.rect.left + obstacle.rect.width * 0.6;
        _coins.add(Coin(position: Offset(coinX, coinY)));
      }
    } else {
      if (coinRoll < 0.7) {
        _spawnCoinTrail(
          obstacle,
          ascending: obstacle.behavior != ObstacleBehavior.ceiling,
        );
      }
    }
  }

  Obstacle _buildGroundBlock({bool gentle = false}) {
    final double width =
        (gentle ? 60 : 48) + _random.nextDouble() * (gentle ? 40 : 96);
    final double height =
        (gentle ? 54 : 70) + _random.nextDouble() * (gentle ? 30 : 64);
    final double left = _viewport.width + width + 48;
    final double top = (_groundY + _playerRadius) - height;
    return Obstacle(
      rect: Rect.fromLTWH(left, top, width, height),
      behavior: ObstacleBehavior.groundBlock,
    );
  }

  Obstacle _buildMovingHazard() {
    final double size = 42 + _random.nextDouble() * 22;
    final double left = _viewport.width + size + 64;
    final double baseTop = math.max(
      90,
      _groundY - (120 + _random.nextDouble() * 70),
    );
    final double amplitude = 40 + _random.nextDouble() * 55;
    final double frequency = 0.6 + _random.nextDouble() * 0.5;
    return Obstacle(
      rect: Rect.fromLTWH(left, baseTop, size, size),
      behavior: ObstacleBehavior.movingHazard,
      anchor: Offset(left, baseTop),
      amplitude: amplitude,
      frequency: frequency,
      phase: _random.nextDouble() * math.pi * 2,
    );
  }

  Obstacle _buildHoveringShard() {
    final double width = 34 + _random.nextDouble() * 28;
    final double height = 52 + _random.nextDouble() * 24;
    final double left = _viewport.width + width + 92;
    final double baseTop = math.max(
      80,
      _groundY - (150 + _random.nextDouble() * 90),
    );
    final double amplitude = 28 + _random.nextDouble() * 36;
    final double frequency = 0.8 + _random.nextDouble() * 0.6;
    return Obstacle(
      rect: Rect.fromLTWH(left, baseTop, width, height),
      behavior: ObstacleBehavior.hoveringShard,
      anchor: Offset(left, baseTop),
      amplitude: amplitude,
      frequency: frequency,
      phase: _random.nextDouble() * math.pi * 2,
    );
  }

  Obstacle _buildCeilingBarrier() {
    final double width = 90 + _random.nextDouble() * 120;
    final double height = 28 + _random.nextDouble() * 18;
    final double left = _viewport.width + width + 80;
    final double top = math.max(
      40,
      (_groundY - (_playerRadius * 4)) - _random.nextDouble() * 110,
    );
    return Obstacle(
      rect: Rect.fromLTWH(left, top, width, height),
      behavior: ObstacleBehavior.ceiling,
    );
  }

  void _spawnCoinTrail(Obstacle obstacle, {bool ascending = true}) {
    final int count = 4 + _random.nextInt(3);
    final double spacing = 34 + _random.nextDouble() * 8;
    final double startX = obstacle.rect.right + 24;
    double startY;
    if (obstacle.behavior == ObstacleBehavior.ceiling) {
      startY = obstacle.rect.bottom + 40;
      ascending = false;
    } else if (obstacle.behavior == ObstacleBehavior.groundBlock) {
      startY = math.max(60, obstacle.rect.top - 48);
    } else {
      startY = obstacle.rect.center.dy;
    }
    for (var i = 0; i < count; i++) {
      final double direction = ascending ? -1 : 1;
      final double x = startX + spacing * i;
      double y = startY + direction * 18 * i;
      y = y.clamp(50, _groundY + _playerRadius - 40);
      _coins.add(Coin(position: Offset(x, y)));
    }
  }

  void _finishRun() {
    _phase = GamePhase.gameOver;
    _ticker.stop();
    soundController.playGameOverSfx();
    soundController.stopBgm();

    final DateTime now = DateTime.now();
    final Duration runDuration =
        _runStartedAt != null ? now.difference(_runStartedAt!) : Duration.zero;
    _lastRunDuration = runDuration;
    _runStartedAt = null;
    _pausedForLifecycle = false;

    if (_score > _bestScore) {
      _bestScore = _score;
      _prefs?.setInt('qdd_best_score', _bestScore);
    }

    final int rewardedCoins = wallet.registerRunCoins(_coinsCollected);
    _lastRunAwardedCoins = rewardedCoins;

    final runStats = RunStats(
      duration: runDuration,
      score: _score,
      coins: _coinsCollected,
      usedLine: _usedLineThisRun,
      jumpsPerformed: _jumpsPerformed,
      drawTimeMs: _drawTimeMs.round(),
      accidentDeath: _lastDeathCause != null,
    );
    final int revivesUsed = _reviveAvailable ? 0 : 1;
    unawaited(
      analytics.logGameEnd(
        stats: runStats,
        revivesUsed: revivesUsed,
        totalCoins: wallet.totalCoins,
        missionsCompletedDelta: 0,
      ),
    );
    if (_lastDeathCause != null) {
      unawaited(
        analytics.logObstacleHit(
          obstacleType: _lastDeathCause!.name,
          score: _score,
          elapsedSeconds: runDuration.inMilliseconds / 1000,
        ),
      );
    }

    unawaited(
      adService.maybeShowInterstitial(
        lastRunDuration: runDuration,
        score: _score,
        coinsCollected: _coinsCollected,
      ),
    );
    notifyListeners();
  }

  void pauseForLifecycle() {
    if (_phase != GamePhase.running) {
      return;
    }
    if (_pausedForLifecycle) {
      return;
    }
    _ticker.stop();
    _pausedForLifecycle = true;
    _lastTick = null;
  }

  void resumeFromLifecycle() {
    if (_phase != GamePhase.running) {
      return;
    }
    if (!_pausedForLifecycle) {
      return;
    }
    _pausedForLifecycle = false;
    _ticker.start();
  }

  bool _circleRectIntersect({
    required Offset center,
    required double radius,
    required Rect rect,
  }) {
    final double closestX = center.dx.clamp(rect.left, rect.right);
    final double closestY = center.dy.clamp(rect.top, rect.bottom);
    final double dx = center.dx - closestX;
    final double dy = center.dy - closestY;
    return dx * dx + dy * dy <= radius * radius;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

