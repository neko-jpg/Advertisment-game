
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class Obstacle {
  double x;
  final double y;
  final double width;
  final double height;
  final Key key = UniqueKey();

  Obstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class ObstacleProvider with ChangeNotifier {
  final List<Obstacle> _obstacles = [];
  final double gameWidth;
  Timer? _spawnTimer;

  double _speed = 5.0;
  int _nextSpawnTime = 2000;

  List<Obstacle> get obstacles => _obstacles;
  double get speed => _speed;

  ObstacleProvider({required this.gameWidth});

  void startSpawning() {
    stopSpawning();
    _spawnTimer = Timer.periodic(Duration(milliseconds: _nextSpawnTime), (timer) {
      _spawnObstacle();
    });
  }

  void stopSpawning() {
    _spawnTimer?.cancel();
  }

  void _spawnObstacle() {
    final random = Random();
    _obstacles.add(Obstacle(
      x: gameWidth + 50,
      y: 360, // Position on the floor
      width: 30 + random.nextDouble() * 40,
      height: 40,
    ));
    notifyListeners();
  }

  void updateObstacles() {
    for (var obstacle in _obstacles) {
      obstacle.x -= _speed;
    }
    _obstacles.removeWhere((obstacle) => obstacle.x + obstacle.width < 0);
    notifyListeners();
  }

  void increaseSpeed() {
      _speed += 0.2;
      // Optionally, decrease spawn time to make obstacles appear more frequently
      if (_nextSpawnTime > 1000) {
          _nextSpawnTime -= 50;
          stopSpawning();
          startSpawning();
      }
      notifyListeners();
  }

  void reset() {
    stopSpawning();
    _obstacles.clear();
    _speed = 5.0;
    _nextSpawnTime = 2000;
    notifyListeners();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    super.dispose();
  }
}
