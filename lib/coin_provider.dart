
import 'dart:math';
import 'package:flutter/material.dart';

// Represents a single coin in the game world.
class Coin {
  Offset position;
  final double radius = 15.0; // Size of the coin

  Coin({required this.position});
}

// Manages the state of all coins in the game.
class CoinProvider with ChangeNotifier {
  final List<Coin> _coins = [];
  int _coinsCollected = 0;
  final Random _random = Random();

  List<Coin> get coins => _coins;
  int get coinsCollected => _coinsCollected;

  // Periodically spawn new coins off-screen to the right.
  void maybeSpawnCoin(double screenWidth, double screenHeight) {
    // A 1% chance to spawn a coin on any given frame.
    if (_random.nextInt(100) < 2) {
      // Spawn coins at a random height, but not too close to the screen edges.
      double yPosition = _random.nextDouble() * (screenHeight - 100) + 50;
      _coins.add(Coin(position: Offset(screenWidth + 50, yPosition)));
      notifyListeners();
    }
  }

  // Update coin positions and check for collisions.
  void update(double speed, Rect playerRect, double screenWidth) {
    // Move existing coins
    for (var coin in _coins) {
      coin.position = coin.position.translate(-speed, 0);
    }

    // Check for collision with the player
    final collectedCoins = <Coin>[];
    for (var coin in _coins) {
      final coinRect = Rect.fromCircle(center: coin.position, radius: coin.radius);
      if (playerRect.overlaps(coinRect)) {
        collectedCoins.add(coin);
        _coinsCollected++;
      }
    }
    // Remove collected and off-screen coins
    _coins.removeWhere((coin) =>
        collectedCoins.contains(coin) || coin.position.dx < -coin.radius);

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
