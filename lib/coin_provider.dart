
import 'dart:math';

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
  final Random _random = Random();

  /// Base probability (0-1) per frame to spawn a new coin.
  static const double _baseSpawnChance = 0.02;

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
  void maybeSpawnCoin(double screenWidth, double screenHeight) {
    final effectiveChance = _baseSpawnChance *
        _spawnMultiplier *
        (_inRestWindow ? _restSpawnBonus : 1.0);
    if (_random.nextDouble() < effectiveChance) {
      final yPosition = _random.nextDouble() * (screenHeight - 100) + 50;
      _coins.add(Coin(position: Offset(screenWidth + 50, yPosition)));
      notifyListeners();
    }
  }

  // Update coin positions and check for collisions.
  void update(double speed, Rect playerRect, double screenWidth) {
    for (var coin in _coins) {
      coin.position = coin.position.translate(-speed, 0);
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
