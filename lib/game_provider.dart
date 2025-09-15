
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'ad_provider.dart';
import 'line_provider.dart';
import 'obstacle_provider.dart';
import 'coin_provider.dart';
import 'sound_provider.dart'; // Import SoundProvider

enum GameState { ready, running, dead, result }

class GameProvider with ChangeNotifier {
  GameState _gameState = GameState.ready;
  final double _playerX = 100.0;
  double _playerY = 380.0;
  double _playerYSpeed = 0.0;
  int _score = 0;
  Ticker? _ticker;
  Size _screenSize = Size.zero;
  static const double _coyoteDurationMs = 120.0;
  static const double _jumpBufferDurationMs = 100.0;
  double _coyoteTimerMs = 0.0;
  double _jumpBufferTimerMs = 0.0;
  DateTime? _lastFrameTimestamp;

  // Providers
  AdProvider adProvider;
  LineProvider lineProvider;
  ObstacleProvider obstacleProvider;
  CoinProvider coinProvider;
  SoundProvider soundProvider; // Add SoundProvider

  GameProvider({
    required this.adProvider,
    required this.lineProvider,
    required this.obstacleProvider,
    required this.coinProvider,
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
    _coyoteTimerMs = _coyoteDurationMs;
    _lastFrameTimestamp = null;

    // Reset all providers
    lineProvider.clearAllLines();
    obstacleProvider.reset();
    coinProvider.reset();
    obstacleProvider.startSpawning();
    soundProvider.startBgm(); // Start BGM

    adProvider.loadInterstitialAd(); // Load interstitial ad

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

    final initialCoins = coinProvider.coinsCollected;

    // --- Updates ---
    lineProvider.updateLineLifetimes();
    obstacleProvider.updateObstacles();
    
    // --- Player physics ---
    _playerYSpeed += 0.5; // Gravity
    _playerY += _playerYSpeed;

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
      _coyoteTimerMs = _coyoteDurationMs;
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
    }

    final Rect playerRect = Rect.fromLTWH(playerX - 15, playerY - 15, 30, 30);

    // --- Coin and Obstacle updates ---
    coinProvider.maybeSpawnCoin(_screenSize.width, _screenSize.height);
    coinProvider.update(obstacleProvider.speed, playerRect, _screenSize.width);

    // Play coin sound if a coin was collected
    if (coinProvider.coinsCollected > initialCoins) {
      soundProvider.playCoinSfx();
    }

    // --- Obstacle collision ---
    for (var obstacle in obstacleProvider.obstacles) {
      Rect obstacleRect = Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height);
      if (playerRect.overlaps(obstacleRect)) {
        _gameState = GameState.dead;
        obstacleProvider.stopSpawning();
        soundProvider.stopBgm(); // Stop BGM
        soundProvider.playGameOverSfx(); // Play game over sound
        _ticker?.stop();
        adProvider.loadRewardAd(); // Pre-load ad for revive option
        notifyListeners();
        return;
      }
    }
    
    // --- Difficulty Curve ---
    if (_score > 0 && _score % 500 == 0) {
      obstacleProvider.increaseSpeed();
    }

    _score++;
    notifyListeners();
  }

  void revivePlayer() {
    if (_gameState != GameState.dead) return;

    obstacleProvider.reset();
    _playerY = 380.0;
    _playerYSpeed = 0.0;
    _gameState = GameState.running;
    _jumpBufferTimerMs = 0.0;
    _coyoteTimerMs = _coyoteDurationMs;
    _lastFrameTimestamp = null;
    obstacleProvider.startSpawning();
    soundProvider.startBgm(); // Restart BGM
    _ticker?.start();

    notifyListeners();
  }

  void jump() {
    if (_gameState != GameState.running) {
      return;
    }
    _jumpBufferTimerMs = _jumpBufferDurationMs;
  }

  void resetGame() {
    _gameState = GameState.ready;
    _score = 0;
    _playerY = 380.0;
    _playerYSpeed = 0.0;
    _jumpBufferTimerMs = 0.0;
    _coyoteTimerMs = 0.0;
    _lastFrameTimestamp = null;
    _ticker?.stop();
    lineProvider.clearAllLines();
    obstacleProvider.reset();
    coinProvider.reset();
    soundProvider.stopBgm();
    notifyListeners();
  }
  
  // Called by ChangeNotifierProxyProvider when dependencies change.
  void updateDependencies(
    AdProvider ad,
    LineProvider line,
    ObstacleProvider obstacle,
    CoinProvider coin,
  ) {
    adProvider = ad;
    lineProvider = line;
    obstacleProvider = obstacle;
    coinProvider = coin;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    soundProvider.dispose();
    super.dispose();
  }
}
