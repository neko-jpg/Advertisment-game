import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/game_constants.dart';

const _kCoinRadius = 12.0;
const _kOffscreenCullX = -48.0;

/// Handles spawning, movement and collection of coins during a run.
class CoinProvider with ChangeNotifier {
  CoinProvider();

  final List<Coin> _coins = <Coin>[];
  final math.Random _random = math.Random();

  double _spawnTimerMs = 0.0;
  double _spawnRateMultiplier = 1.0;
  bool _restWindowActive = false;
  int _coinsCollected = 0;

  /// Active coins currently visible in the world.
  List<Coin> get coins => List.unmodifiable(_coins);

  /// Total number of coins collected in the current run.
  int get coinsCollected => _coinsCollected;

  /// Configures spawn frequency modifiers coming from difficulty / boosts.
  void configureSpawn({required double multiplier}) {
    _spawnRateMultiplier = multiplier.clamp(0.4, 3.0);
  }

  /// Enables or disables rest window behaviour.
  void setRestWindowActive(bool active) {
    if (_restWindowActive == active) {
      return;
    }
    _restWindowActive = active;
    notifyListeners();
  }

  /// Clears all coins and resets counters.
  void reset() {
    final bool hadCoins = _coins.isNotEmpty || _coinsCollected != 0;
    _coins.clear();
    _coinsCollected = 0;
    _spawnTimerMs = 0.0;
    _restWindowActive = false;
    if (hadCoins) {
      notifyListeners();
    }
  }

  /// Attempts to spawn a new coin if the timer has elapsed.
  void maybeSpawnCoin({
    required double deltaMs,
    required double screenWidth,
    required double screenHeight,
  }) {
    if (screenWidth <= 0) {
      return;
    }
    _spawnTimerMs -= deltaMs;
    if (_spawnTimerMs > 0) {
      return;
    }

    final double verticalBand = math.max(80.0, screenHeight * 0.35);
    final double groundY = GameConstants.playerStartY - 32;
    final double minY = math.max(60.0, groundY - verticalBand);
    final double maxY = groundY - 12;
    final double y = math.min(maxY, minY + _random.nextDouble() * verticalBand);

    _coins.add(
      Coin(
        position: Offset(screenWidth + 36, y),
        radius: _kCoinRadius,
      ),
    );

    _spawnTimerMs = _nextSpawnDelayMs();
    notifyListeners();
  }

  /// Updates coin positions and handles collection.
  void update({
    required double deltaMs,
    required double scrollSpeed,
    required Rect playerRect,
    required double _screenWidth,
  }) {
    if (_coins.isEmpty) {
      return;
    }

    final double dt = deltaMs / 16.0;
    final double displacement = (scrollSpeed.clamp(0.0, 30.0) + 2.0) * dt;

    bool changed = false;
    for (final Coin coin in _coins) {
      coin.position = coin.position.translate(-displacement, 0);
    }

    for (int i = _coins.length - 1; i >= 0; i--) {
      final Coin coin = _coins[i];
      if (coin.position.dx < _kOffscreenCullX) {
        _coins.removeAt(i);
        changed = true;
        continue;
      }
      if (coin.intersects(playerRect)) {
        _coins.removeAt(i);
        _coinsCollected++;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Clears transient coin effects. Used by the error recovery system.
  void clearEffects() {
    if (_coins.isEmpty) {
      return;
    }
    _coins.clear();
    notifyListeners();
  }

  /// Removes coins that are far away from the player to save memory.
  void clearDistantCoins() {
    final int before = _coins.length;
    _coins.removeWhere((Coin coin) => coin.position.dx < _kOffscreenCullX * 2);
    if (before != _coins.length) {
      notifyListeners();
    }
  }

  double _nextSpawnDelayMs() {
    final double base = _restWindowActive ? 600.0 : 850.0;
    final double randomness = 0.65 + _random.nextDouble() * 0.7;
    return base * randomness / _spawnRateMultiplier.clamp(0.2, 4.0);
  }
}

/// Simple coin model used by the renderer and collision system.
class Coin {
  Coin({
    required this.position,
    required this.radius,
    DateTime? spawnTime,
  }) : spawnTime = spawnTime ?? DateTime.now();

  Offset position;
  final double radius;
  final DateTime spawnTime;

  Offset get center => position;

  bool intersects(Rect rect) {
    final double clampedX = math.max(rect.left, math.min(position.dx, rect.right));
    final double clampedY = math.max(rect.top, math.min(position.dy, rect.bottom));
    final double dx = position.dx - clampedX;
    final double dy = position.dy - clampedY;
    return dx * dx + dy * dy <= radius * radius;
  }
}
