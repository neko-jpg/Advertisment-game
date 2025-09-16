
import 'dart:math' as math;

import 'package:flutter/material.dart';

// Represents a single coin in the game world.
class Coin {
  Coin({required this.position});

  Offset position;
  final double radius = 15.0; // Size of the coin
}

// Manages the state of all coins in the game.
class CoinProvider with ChangeNotifier {
  CoinProvider();

  final List<Coin> _coins = [];
  int _coinsCollected = 0;
  final math.Random _random = math.Random();

  /// Target spawn rate in coins per second at baseline difficulty.
  static const double _baseSpawnRatePerSecond = 1.2;

  double _spawnMultiplier = 1.0;
  double _restSpawnBonus = 1.5;
  bool _inRestWindow = false;

  List<Coin> get coins => _coins;
  int get coinsCollected => _coinsCollected;

  void configureSpawn({double? multiplier, double? restBonus}) {
    if (multiplier != null) {
      _spawnMultiplier = multiplier.clamp(0.2, 3.0);
    }
    if (restBonus != null) {
      _restSpawnBonus = restBonus.clamp(1.0, 5.0);
    }
  }

  void setRestWindowActive(bool value) {
    if (_inRestWindow == value) {
      return;
    }
    _inRestWindow = value;
    notifyListeners();
  }

  // Periodically spawn new coins off-screen to the right.
  void maybeSpawnCoin({
    required double deltaMs,
    required double screenWidth,
    required double screenHeight,
  }) {
    if (deltaMs <= 0) {
      return;
    }
    final double dtSeconds = deltaMs / 1000.0;
    final double spawnRate = _baseSpawnRatePerSecond *
        _spawnMultiplier *
        (_inRestWindow ? _restSpawnBonus : 1.0);
    final double spawnProbability = 1 - math.exp(-spawnRate * dtSeconds);
    if (_random.nextDouble() < spawnProbability) {
      final yPosition =
          _random.nextDouble() * (screenHeight - 100).clamp(0.0, screenHeight) + 50;
      _coins.add(Coin(position: Offset(screenWidth + 50, yPosition)));
      notifyListeners();
    }
  }

  // Update coin positions and check for collisions.
  void update({
    required double deltaMs,
    required double scrollSpeed,
    required Rect playerRect,
    required double screenWidth,
  }) {
    final double dt = deltaMs / 16.0;
    final double displacement = scrollSpeed * dt;
    for (var coin in _coins) {
      coin.position = coin.position.translate(-displacement, 0);
    }

    final collectedCoins = <Coin>[];
    for (var coin in _coins) {
      final coinRect = Rect.fromCircle(center: coin.position, radius: coin.radius);
      if (playerRect.overlaps(coinRect)) {
        collectedCoins.add(coin);
        _coinsCollected++;
      }
    }

    _coins.removeWhere(
      (coin) => collectedCoins.contains(coin) || coin.position.dx < -coin.radius,
    );

    if (collectedCoins.isNotEmpty) {
      notifyListeners();
    }
  }

  // Reset the state for a new game.
  void reset() {
    _coins.clear();
    _coinsCollected = 0;
    notifyListeners();
  }
}
