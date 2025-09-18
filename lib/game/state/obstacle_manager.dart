import 'dart:math' as math;
import 'package:flutter/material.dart';

class Obstacle {
  double x;
  final double y;
  final double width;
  final double height;
  final Key key = UniqueKey();
  bool nearMissRegistered;

  Obstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.nearMissRegistered = false,
  });
}

class ObstacleProvider with ChangeNotifier {
  ObstacleProvider({required this.gameWidth});

  static const double _groundY = 360.0;
  static const double _baseMinSpawnGap = 150.0;

  final List<Obstacle> _obstacles = [];
  final double gameWidth;
  final math.Random _random = math.Random();

  double _speed = 5.0;
  double _spawnCooldownMs = 1200;
  double _timeSinceStartMs = 0;
  double _screenWidth = 0;
  double _playerX = 0;
  bool _active = false;
  bool _useIntroSequence = false;
  bool _restMode = false;
  double _densityMultiplier = 1.0;
  double _safeWindowPx = 180.0;
  double _pendingStartGraceMs = 0.0;
  final List<_ScheduledPattern> _introQueue = [];
  double _tutorialSafetyWindowMs = 0.0;
  double _tutorialElapsedMs = 0.0;

  List<Obstacle> get obstacles => List.unmodifiable(_obstacles);
  double get speed => _speed;

  void start({required double screenWidth, required bool tutorialMode}) {
    _screenWidth = screenWidth == 0 ? gameWidth : screenWidth;
    _active = true;
    _useIntroSequence = tutorialMode;
    _spawnCooldownMs = tutorialMode ? 1400 : _spawnDelay();
    _timeSinceStartMs = 0;
    _introQueue
      ..clear()
      ..addAll(_buildIntroSequence());
    _tutorialElapsedMs = 0.0;
    if (_pendingStartGraceMs > 0) {
      _spawnCooldownMs += _pendingStartGraceMs;
      _pendingStartGraceMs = 0;
    }
  }

  void stopSpawning() {
    _active = false;
  }

  void update({
    required double deltaMs,
    required double screenWidth,
    required bool tutorialMode,
    required double playerX,
    required bool restWindow,
  }) {
    if (!_active) {
      return;
    }

    _screenWidth = screenWidth == 0 ? _screenWidth : screenWidth;
    _playerX = playerX;
    _timeSinceStartMs += deltaMs;
    if (tutorialMode) {
      _tutorialElapsedMs += deltaMs;
    }
    _spawnCooldownMs -= deltaMs;
    _restMode = restWindow;

    final double dt = deltaMs / 16.0;
    final double displacement = _speed * dt;
    for (final obstacle in _obstacles) {
      obstacle.x -= displacement;
    }
    _obstacles.removeWhere((obstacle) => obstacle.x + obstacle.width < -50);

    if (_useIntroSequence && _introQueue.isNotEmpty) {
      while (_introQueue.isNotEmpty &&
          _timeSinceStartMs >= _introQueue.first.spawnTimeMs) {
        _spawnPattern(_introQueue.removeAt(0).pattern);
      }
      if (_introQueue.isEmpty ||
          (_tutorialSafetyWindowMs > 0 &&
              _tutorialElapsedMs >= _tutorialSafetyWindowMs)) {
        _useIntroSequence = false;
        _spawnCooldownMs = 900;
      }
    }

    final bool tutorialSafetyActive =
        tutorialMode && _tutorialElapsedMs < _tutorialSafetyWindowMs;

    if (!_useIntroSequence && !_restMode && _spawnCooldownMs <= 0) {
      final pool =
          tutorialSafetyActive
              ? _tutorialSafePatterns
              : tutorialMode
              ? _easyPatterns
              : _standardPatterns;
      final pattern = pool[_random.nextInt(pool.length)];
      _spawnPattern(pattern);
      _spawnCooldownMs = _spawnDelay();
    } else if (_restMode) {
      _spawnCooldownMs = math.max(_spawnCooldownMs, 400);
    }

    notifyListeners();
  }

  void increaseSpeed() {
    _speed = math.min(_speed + 0.25, 10.0);
    notifyListeners();
  }

  void reset() {
    _active = false;
    _obstacles.clear();
    _speed = 5.0;
    _spawnCooldownMs = 1200;
    _timeSinceStartMs = 0;
    _introQueue.clear();
    _densityMultiplier = 1.0;
    _safeWindowPx = 180.0;
    _pendingStartGraceMs = 0.0;
    _restMode = false;
    _tutorialElapsedMs = 0.0;
    notifyListeners();
  }

  /// Clears all cached obstacles and intro sequences. Used for recovery.
  void performEmergencyCleanup() {
    if (_obstacles.isEmpty && _introQueue.isEmpty) {
      return;
    }
    _obstacles.clear();
    _introQueue.clear();
    notifyListeners();
  }

  /// Removes obstacles that are far behind the player to save memory.
  void clearDistantObstacles() {
    final int before = _obstacles.length;
    _obstacles.removeWhere((Obstacle obstacle) => obstacle.x < _playerX - 200);
    if (before != _obstacles.length) {
      notifyListeners();
    }
  }

  double _spawnDelay() {
    final density = _densityMultiplier.clamp(0.4, 2.2);
    final minDelay = 850.0 / density;
    final maxDelay = 1400.0 / density;
    return minDelay + _random.nextDouble() * (maxDelay - minDelay);
  }

  void _spawnPattern(_ObstaclePattern pattern) {
    final baseX = _computeSpawnBaseX();
    for (final template in pattern.templates) {
      _obstacles.add(
        Obstacle(
          x: baseX + template.offsetX,
          y: template.y,
          width: template.width,
          height: template.height,
        ),
      );
    }
  }

  double _computeSpawnBaseX() {
    if (_obstacles.isEmpty) {
      return math.max(_screenWidth + 40, _playerX + _safeWindowPx);
    }
    final furthest = _obstacles.reduce((a, b) => a.x > b.x ? a : b);
    final dynamicGap =
        (_baseMinSpawnGap + _speed * 6) / _densityMultiplier.clamp(0.4, 2.2);
    final safeStart = furthest.x + furthest.width + dynamicGap;
    final playerSafe = _playerX + _safeWindowPx;
    return math.max(_screenWidth + 40, math.max(safeStart, playerSafe));
  }

  void configureDifficulty({
    required double speedMultiplier,
    required double densityMultiplier,
    required double safeWindow,
    required Duration startGrace,
  }) {
    _densityMultiplier = densityMultiplier;
    _safeWindowPx = safeWindow;
    _speed = 5.0 * speedMultiplier.clamp(0.6, 2.0);
    _pendingStartGraceMs = startGrace.inMilliseconds.toDouble();
  }

  void setRestMode(bool enabled) {
    _restMode = enabled;
  }

  void configureTutorialWindow({required double durationMs}) {
    _tutorialSafetyWindowMs = durationMs;
  }

  void setSpeedMultiplier(double multiplier) {
    _speed = 5.0 * multiplier.clamp(0.4, 3.0);
  }

  List<_ScheduledPattern> _buildIntroSequence() {
    return [
      _ScheduledPattern(
        spawnTimeMs: 1200,
        pattern: _ObstaclePattern.single(width: 60, height: 38, y: _groundY),
      ),
      _ScheduledPattern(
        spawnTimeMs: 3200,
        pattern: _ObstaclePattern.chain(
          count: 2,
          spacing: 140,
          width: 55,
          height: 40,
          y: _groundY,
        ),
      ),
      _ScheduledPattern(
        spawnTimeMs: 6200,
        pattern: _ObstaclePattern.single(width: 70, height: 60, y: _groundY),
      ),
      _ScheduledPattern(
        spawnTimeMs: 9200,
        pattern: _ObstaclePattern.chain(
          count: 3,
          spacing: 130,
          width: 45,
          height: 40,
          y: _groundY,
        ),
      ),
      _ScheduledPattern(spawnTimeMs: 13200, pattern: _ObstaclePattern.stair()),
      _ScheduledPattern(
        spawnTimeMs: 18200,
        pattern: _ObstaclePattern.chain(
          count: 3,
          spacing: 150,
          width: 45,
          height: 38,
          y: _groundY,
        ),
      ),
      _ScheduledPattern(
        spawnTimeMs: 23200,
        pattern: _ObstaclePattern.single(width: 90, height: 70, y: _groundY),
      ),
      _ScheduledPattern(
        spawnTimeMs: 27200,
        pattern: _ObstaclePattern.chain(
          count: 2,
          spacing: 160,
          width: 50,
          height: 42,
          y: _groundY,
        ),
      ),
      _ScheduledPattern(
        spawnTimeMs: 31200,
        pattern: _ObstaclePattern.single(
          width: 75,
          height: 55,
          y: _groundY - 10,
        ),
      ),
    ];
  }
}

class _ScheduledPattern {
  _ScheduledPattern({required this.spawnTimeMs, required this.pattern});

  final double spawnTimeMs;
  final _ObstaclePattern pattern;
}

class _ObstaclePattern {
  const _ObstaclePattern(this.templates);

  final List<_ObstacleTemplate> templates;

  factory _ObstaclePattern.single({
    required double width,
    required double height,
    required double y,
  }) {
    return _ObstaclePattern([
      _ObstacleTemplate(offsetX: 0, width: width, height: height, y: y),
    ]);
  }

  factory _ObstaclePattern.chain({
    required int count,
    required double spacing,
    required double width,
    required double height,
    required double y,
  }) {
    return _ObstaclePattern(
      List.generate(count, (index) {
        return _ObstacleTemplate(
          offsetX: index * spacing,
          width: width,
          height: height,
          y: y,
        );
      }),
    );
  }

  factory _ObstaclePattern.stair() {
    const baseY = _ObstacleProviderPresets.groundY;
    return _ObstaclePattern([
      _ObstacleTemplate(offsetX: 0, width: 50, height: 40, y: baseY),
      _ObstacleTemplate(offsetX: 120, width: 50, height: 70, y: baseY),
      _ObstacleTemplate(offsetX: 240, width: 50, height: 100, y: baseY),
    ]);
  }

  factory _ObstaclePattern.gap() {
    const baseY = _ObstacleProviderPresets.groundY;
    return _ObstaclePattern([
      _ObstacleTemplate(offsetX: 0, width: 60, height: 40, y: baseY),
      _ObstacleTemplate(offsetX: 220, width: 60, height: 40, y: baseY),
    ]);
  }
}

class _ObstacleTemplate {
  const _ObstacleTemplate({
    required this.offsetX,
    required this.width,
    required this.height,
    required this.y,
  });

  final double offsetX;
  final double width;
  final double height;
  final double y;
}

class _ObstacleProviderPresets {
  static const double groundY = 360.0;
}

final List<_ObstaclePattern> _easyPatterns = [
  _ObstaclePattern.single(
    width: 55,
    height: 40,
    y: _ObstacleProviderPresets.groundY,
  ),
  _ObstaclePattern.chain(
    count: 2,
    spacing: 160,
    width: 45,
    height: 38,
    y: _ObstacleProviderPresets.groundY,
  ),
];

final List<_ObstaclePattern> _standardPatterns = [
  _ObstaclePattern.single(
    width: 70,
    height: 60,
    y: _ObstacleProviderPresets.groundY,
  ),
  _ObstaclePattern.chain(
    count: 3,
    spacing: 120,
    width: 40,
    height: 40,
    y: _ObstacleProviderPresets.groundY,
  ),
  _ObstaclePattern.stair(),
  _ObstaclePattern([
    _ObstacleTemplate(
      offsetX: 0,
      width: 50,
      height: 40,
      y: _ObstacleProviderPresets.groundY,
    ),
    _ObstacleTemplate(
      offsetX: 160,
      width: 60,
      height: 90,
      y: _ObstacleProviderPresets.groundY,
    ),
  ]),
  _ObstaclePattern([
    _ObstacleTemplate(
      offsetX: 0,
      width: 60,
      height: 40,
      y: _ObstacleProviderPresets.groundY,
    ),
    _ObstacleTemplate(
      offsetX: 140,
      width: 60,
      height: 40,
      y: _ObstacleProviderPresets.groundY,
    ),
    _ObstacleTemplate(
      offsetX: 280,
      width: 60,
      height: 40,
      y: _ObstacleProviderPresets.groundY,
    ),
  ]),
];

final List<_ObstaclePattern> _tutorialSafePatterns = [
  _ObstaclePattern.single(
    width: 55,
    height: 38,
    y: _ObstacleProviderPresets.groundY,
  ),
  _ObstaclePattern.chain(
    count: 2,
    spacing: 170,
    width: 45,
    height: 36,
    y: _ObstacleProviderPresets.groundY,
  ),
  _ObstaclePattern.single(
    width: 60,
    height: 45,
    y: _ObstacleProviderPresets.groundY - 10,
  ),
];
