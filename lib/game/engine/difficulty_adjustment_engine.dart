import 'dart:math' as math;

enum SkillLevel {
  beginner,
  intermediate,
  advanced,
  expert,
}

class PlayerMetrics {
  const PlayerMetrics({
    required this.averageScore,
    required this.averageSessionDuration,
    required this.successRate,
    required this.jumpAccuracy,
    required this.drawingEfficiency,
    required this.consistencyScore,
    required this.recentPerformanceTrend,
  });

  final double averageScore;
  final Duration averageSessionDuration;
  final double successRate;
  final double jumpAccuracy;
  final double drawingEfficiency;
  final double consistencyScore;
  final double recentPerformanceTrend;
}

class GameConfig {
  const GameConfig({
    required this.speedMultiplier,
    required this.densityMultiplier,
    required this.safeWindowPx,
    required this.coinMultiplier,
    required this.jumpBufferMs,
    required this.coyoteTimeMs,
  });

  final double speedMultiplier;
  final double densityMultiplier;
  final double safeWindowPx;
  final double coinMultiplier;
  final double jumpBufferMs;
  final double coyoteTimeMs;

  GameConfig copyWith({
    double? speedMultiplier,
    double? densityMultiplier,
    double? safeWindowPx,
    double? coinMultiplier,
    double? jumpBufferMs,
    double? coyoteTimeMs,
  }) {
    return GameConfig(
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      densityMultiplier: densityMultiplier ?? this.densityMultiplier,
      safeWindowPx: safeWindowPx ?? this.safeWindowPx,
      coinMultiplier: coinMultiplier ?? this.coinMultiplier,
      jumpBufferMs: jumpBufferMs ?? this.jumpBufferMs,
      coyoteTimeMs: coyoteTimeMs ?? this.coyoteTimeMs,
    );
  }
}

class GameSession {
  GameSession({
    required this.sessionId,
    required this.startTime,
  });

  final String sessionId;
  final DateTime startTime;
  
  DateTime? endTime;
  int score = 0;
  int totalJumps = 0;
  int successfulJumps = 0;
  int totalObstaclesEncountered = 0;
  int obstaclesAvoided = 0;
  int coinsCollected = 0;
  bool wasSuccessful = false;

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
  double get jumpAccuracy => totalJumps > 0 ? successfulJumps / totalJumps : 0.0;
  double get avoidanceRate => totalObstaclesEncountered > 0 
      ? obstaclesAvoided / totalObstaclesEncountered : 0.0;
}

class DifficultyAdjustment {
  const DifficultyAdjustment({
    required this.timestamp,
    required this.reason,
    required this.previousConfig,
    required this.newConfig,
  });

  final DateTime timestamp;
  final String reason;
  final GameConfig previousConfig;
  final GameConfig newConfig;
}

class DifficultyAdjustmentEngine {
  static const int _maxSessionHistory = 10;
  static const int _consecutiveFailureThreshold = 3;
  static const double _difficultyReductionRate = 0.2;
  static const double _minDifficultyMultiplier = 0.5;
  static const Duration _adjustmentCooldown = Duration(seconds: 5);

  final List<GameSession> _sessionHistory = [];
  final List<DifficultyAdjustment> _adjustmentHistory = [];
  
  GameSession? _currentSession;
  int _consecutiveFailures = 0;
  int _consecutiveSuccesses = 0;
  DateTime? _lastAdjustment;

  static const GameConfig _baseConfig = GameConfig(
    speedMultiplier: 1.0,
    densityMultiplier: 1.0,
    safeWindowPx: 180.0,
    coinMultiplier: 1.0,
    jumpBufferMs: 100.0,
    coyoteTimeMs: 80.0,
  );

  GameConfig _currentConfig = _baseConfig;

  double calculateDifficultyMultiplier(int consecutiveFailures) {
    if (consecutiveFailures < _consecutiveFailureThreshold) {
      return 1.0;
    }

    final reductionSteps = consecutiveFailures - _consecutiveFailureThreshold + 1;
    final multiplier = 1.0 - (reductionSteps * _difficultyReductionRate);
    
    return math.max(multiplier, _minDifficultyMultiplier);
  }

  SkillLevel assessPlayerSkill(List<GameSession> sessions) {
    if (sessions.isEmpty) {
      return SkillLevel.beginner;
    }

    final recentSessions = sessions.take(5).toList();
    final avgScore = recentSessions.map((s) => s.score).reduce((a, b) => a + b) / recentSessions.length;
    final avgDuration = recentSessions
        .map((s) => s.duration.inSeconds)
        .reduce((a, b) => a + b) / recentSessions.length;
    final avgAccuracy = recentSessions
        .map((s) => s.jumpAccuracy)
        .reduce((a, b) => a + b) / recentSessions.length;

    if (avgScore >= 1000 && avgDuration >= 60 && avgAccuracy >= 0.8) {
      return SkillLevel.advanced;
    } else if (avgScore >= 500 && avgDuration >= 30 && avgAccuracy >= 0.6) {
      return SkillLevel.intermediate;
    } else if (avgScore >= 200 && avgDuration >= 15 && avgAccuracy >= 0.4) {
      return SkillLevel.intermediate;
    } else {
      return SkillLevel.beginner;
    }
  }

  GameConfig adjustGameBalance(PlayerMetrics metrics) {
    final now = DateTime.now();
    
    if (_lastAdjustment != null && 
        now.difference(_lastAdjustment!) < _adjustmentCooldown) {
      return _currentConfig;
    }

    final previousConfig = _currentConfig;
    
    double speedAdjustment = 0.0;
    double densityAdjustment = 0.0;
    double safeWindowAdjustment = 0.0;
    double coinAdjustment = 0.0;
    double jumpBufferAdjustment = 0.0;
    double coyoteTimeAdjustment = 0.0;

    if (metrics.successRate < 0.3) {
      speedAdjustment -= 0.2;
      densityAdjustment -= 0.15;
      safeWindowAdjustment += 40.0;
      coinAdjustment += 0.3;
    } else if (metrics.successRate > 0.8) {
      speedAdjustment += 0.15;
      densityAdjustment += 0.1;
      safeWindowAdjustment -= 20.0;
    }

    if (metrics.recentPerformanceTrend < -0.3) {
      jumpBufferAdjustment += 50.0;
      coyoteTimeAdjustment += 20.0;
      coinAdjustment += 0.2;
    }

    if (metrics.consistencyScore < 0.5) {
      safeWindowAdjustment += 20.0;
      jumpBufferAdjustment += 25.0;
    }

    _currentConfig = GameConfig(
      speedMultiplier: math.max(0.5, math.min(2.0, _baseConfig.speedMultiplier + speedAdjustment)),
      densityMultiplier: math.max(0.4, math.min(2.5, _baseConfig.densityMultiplier + densityAdjustment)),
      safeWindowPx: math.max(120.0, math.min(300.0, _baseConfig.safeWindowPx + safeWindowAdjustment)),
      coinMultiplier: math.max(0.5, math.min(3.0, _baseConfig.coinMultiplier + coinAdjustment)),
      jumpBufferMs: math.max(50.0, math.min(200.0, _baseConfig.jumpBufferMs + jumpBufferAdjustment)),
      coyoteTimeMs: math.max(50.0, math.min(150.0, _baseConfig.coyoteTimeMs + coyoteTimeAdjustment)),
    );

    _adjustmentHistory.add(DifficultyAdjustment(
      timestamp: now,
      reason: 'Performance-based adjustment: success=${metrics.successRate.toStringAsFixed(2)}, trend=${metrics.recentPerformanceTrend.toStringAsFixed(2)}',
      previousConfig: previousConfig,
      newConfig: _currentConfig,
    ));

    _lastAdjustment = now;
    return _currentConfig;
  }

  void startSession(String sessionId) {
    _currentSession = GameSession(
      sessionId: sessionId,
      startTime: DateTime.now(),
    );
  }

  void endSession({required int finalScore, required bool wasSuccessful}) {
    if (_currentSession == null) return;

    _currentSession!.endTime = DateTime.now();
    _currentSession!.score = finalScore;
    _currentSession!.wasSuccessful = wasSuccessful;

    _sessionHistory.insert(0, _currentSession!);
    if (_sessionHistory.length > _maxSessionHistory) {
      _sessionHistory.removeLast();
    }

    _currentSession = null;
  }

  void recordFailure() {
    _consecutiveFailures++;
    _consecutiveSuccesses = 0;

    if (_consecutiveFailures >= _consecutiveFailureThreshold) {
      final multiplier = calculateDifficultyMultiplier(_consecutiveFailures);
      final previousConfig = _currentConfig;
      
      _currentConfig = _currentConfig.copyWith(
        speedMultiplier: _baseConfig.speedMultiplier * multiplier,
        densityMultiplier: _baseConfig.densityMultiplier * multiplier,
      );

      _adjustmentHistory.add(DifficultyAdjustment(
        timestamp: DateTime.now(),
        reason: 'Consecutive failure adjustment: ${_consecutiveFailures} failures',
        previousConfig: previousConfig,
        newConfig: _currentConfig,
      ));
    }
  }

  void recordSuccess() {
    _consecutiveSuccesses++;
    _consecutiveFailures = 0;

    if (_consecutiveSuccesses >= 6) {
      final previousConfig = _currentConfig;
      
      _currentConfig = _currentConfig.copyWith(
        speedMultiplier: math.min(_baseConfig.speedMultiplier, _currentConfig.speedMultiplier + 0.1),
        densityMultiplier: math.min(_baseConfig.densityMultiplier, _currentConfig.densityMultiplier + 0.05),
      );

      if (_currentConfig.speedMultiplier != previousConfig.speedMultiplier ||
          _currentConfig.densityMultiplier != previousConfig.densityMultiplier) {
        _adjustmentHistory.add(DifficultyAdjustment(
          timestamp: DateTime.now(),
          reason: 'Success recovery adjustment: ${_consecutiveSuccesses} successes',
          previousConfig: previousConfig,
          newConfig: _currentConfig,
        ));
      }

      _consecutiveSuccesses = 0;
    }
  }

  void updateSessionMetrics({
    required int jumps,
    required int successfulJumps,
    int? coinsCollected,
  }) {
    if (_currentSession == null) return;

    _currentSession!.totalJumps = jumps;
    _currentSession!.successfulJumps = successfulJumps;
    if (coinsCollected != null) {
      _currentSession!.coinsCollected = coinsCollected;
    }
  }

  void resetDifficulty() {
    _currentConfig = _baseConfig;
    _consecutiveFailures = 0;
    _consecutiveSuccesses = 0;
  }

  PlayerMetrics get currentMetrics {
    if (_sessionHistory.isEmpty) {
      return const PlayerMetrics(
        averageScore: 0.0,
        averageSessionDuration: Duration.zero,
        successRate: 0.0,
        jumpAccuracy: 0.0,
        drawingEfficiency: 0.0,
        consistencyScore: 0.0,
        recentPerformanceTrend: 0.0,
      );
    }

    final recentSessions = _sessionHistory.take(5).toList();
    
    final avgScore = recentSessions.map((s) => s.score).reduce((a, b) => a + b) / recentSessions.length;
    final avgDuration = Duration(
      seconds: (recentSessions.map((s) => s.duration.inSeconds).reduce((a, b) => a + b) / recentSessions.length).round(),
    );
    final successRate = recentSessions.where((s) => s.wasSuccessful).length / recentSessions.length;
    final jumpAccuracy = recentSessions.map((s) => s.jumpAccuracy).reduce((a, b) => a + b) / recentSessions.length;
    
    double trend = 0.0;
    if (recentSessions.length >= 4) {
      final firstHalf = recentSessions.sublist(0, recentSessions.length ~/ 2);
      final secondHalf = recentSessions.sublist(recentSessions.length ~/ 2);
      
      final firstAvg = firstHalf.map((s) => s.score).reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.map((s) => s.score).reduce((a, b) => a + b) / secondHalf.length;
      
      trend = (firstAvg - secondAvg) / math.max(firstAvg, secondAvg);
    }

    final scores = recentSessions.map((s) => s.score.toDouble()).toList();
    final variance = _calculateVariance(scores);
    final consistencyScore = variance > 0 ? 1.0 / (1.0 + variance / 10000) : 1.0;

    return PlayerMetrics(
      averageScore: avgScore,
      averageSessionDuration: avgDuration,
      successRate: successRate,
      jumpAccuracy: jumpAccuracy,
      drawingEfficiency: jumpAccuracy,
      consistencyScore: consistencyScore,
      recentPerformanceTrend: trend,
    );
  }

  SkillLevel get currentSkillLevel => assessPlayerSkill(_sessionHistory);

  GameConfig get currentConfig => _currentConfig;

  List<DifficultyAdjustment> get recentAdjustments => 
      _adjustmentHistory.take(10).toList();

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));
    
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }
}