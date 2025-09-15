
import 'dart:async';
import 'package:flutter/material.dart';
import 'ad_provider.dart';
import 'line_provider.dart';
import 'obstacle_provider.dart';
import 'coin_provider.dart';
import 'sound_provider.dart'; // Import SoundProvider

enum GameState { ready, running, dead, result }

class GameProvider with ChangeNotifier {
  GameState _gameState = GameState.ready;
  double _playerX = 100.0;
  double _playerY = 380.0;
  double _playerYSpeed = 0.0;
  int _score = 0;
  Ticker? _ticker;
  Size _screenSize = Size.zero;

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
  });

  // Getters
  GameState get gameState => _gameState;
  double get playerX => _playerX;
  double get playerY => _playerY;
  int get score => _score;
  int get coinsCollected => coinProvider.coinsCollected;

  void setScreenSize(Size size) {
    _screenSize = size;
  }

  void startGame(TickerProvider vsync) {
    if (_gameState == GameState.running) return;

    _gameState = GameState.running;
    _score = 0;
    _playerY = 380.0;
    _playerYSpeed = 0.0;

    // Reset all providers
    lineProvider.clearAllLines();
    obstacleProvider.reset();
    coinProvider.reset();
    obstacleProvider.startSpawning();
    soundProvider.startBgm(); // Start BGM

    adProvider.loadInterstitialAd(); // Load interstitial ad

    _ticker?.dispose();
    _ticker = vsync.createTicker(_gameLoop);
    _ticker!.start();

    notifyListeners();
  }

  void _gameLoop(Duration elapsed) {
    if (_gameState != GameState.running) {
      _ticker?.stop();
      return;
    }

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
        Offset p1 = line.points[i];
        Offset p2 = line.points[i + 1];
        if (_playerX > p1.dx && _playerX < p2.dx || _playerX > p2.dx && _playerX < p1.dx) {
          double lineY = p1.dy + (p2.dy - p1.dy) * (_playerX - p1.dx) / (p2.dx - p1.dx);
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
    }

    Rect playerRect = Rect.fromLTWH(playerX - 15, playerY - 15, 30, 30);

    // --- Coin and Obstacle updates ---
    coinProvider.maybeSpawnCoin(_screenSize.width, _screenSize.height);
    coinProvider.update(obstacleProvider.speed, playerRect, _screenSize.width);

    // Play coin sound if a coin was collected
    if (coinProvider.coinsCollected > initialCoins) {
      soundProvider.playCoinSfx();
    }

    obstacleProvider.updateObstacles();

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
    obstacleProvider.startSpawning();
    soundProvider.startBgm(); // Restart BGM
    _ticker?.start();

    notifyListeners();
  }

  void jump() {
    if (_gameState == GameState.running && _playerY >= 370) {
      _playerYSpeed = -12.0;
      soundProvider.playJumpSfx(); // Play jump sound
      notifyListeners();
    }
  }

  void resetGame() {
      _gameState = GameState.ready;
      _score = 0;
      soundProvider.stopBgm(); // Ensure BGM is stopped
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
