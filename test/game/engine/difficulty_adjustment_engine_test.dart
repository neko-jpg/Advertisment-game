import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/engine/difficulty_adjustment_engine.dart';

void main() {
  group('DifficultyAdjustmentEngine', () {
    late DifficultyAdjustmentEngine engine;

    setUp(() {
      engine = DifficultyAdjustmentEngine();
    });

    group('calculateDifficultyMultiplier', () {
      test('returns 1.0 for failures below threshold', () {
        expect(engine.calculateDifficultyMultiplier(0), equals(1.0));
        expect(engine.calculateDifficultyMultiplier(1), equals(1.0));
        expect(engine.calculateDifficultyMultiplier(2), equals(1.0));
      });

      test('reduces difficulty by 20% for 3 consecutive failures', () {
        final multiplier = engine.calculateDifficultyMultiplier(3);
        expect(multiplier, equals(0.8));
      });

      test('reduces difficulty progressively for more failures', () {
        expect(engine.calculateDifficultyMultiplier(4), equals(0.6));
        expect(engine.calculateDifficultyMultiplier(5), equals(0.5)); // Capped at 0.5
      });

      test('caps difficulty reduction at maximum threshold', () {
        final multiplier = engine.calculateDifficultyMultiplier(10);
        expect(multiplier, greaterThanOrEqualTo(0.5));
      });
    });

    group('assessPlayerSkill', () {
      test('returns beginner for empty session list', () {
        expect(engine.assessPlayerSkill([]), equals(SkillLevel.beginner));
      });

      test('classifies beginner player correctly', () {
        final sessions = [
          _createGameSession(score: 50, duration: Duration(seconds: 10)),
          _createGameSession(score: 75, duration: Duration(seconds: 15)),
          _createGameSession(score: 100, duration: Duration(seconds: 12)),
        ];

        expect(engine.assessPlayerSkill(sessions), equals(SkillLevel.beginner));
      });

      test('classifies intermediate player correctly', () {
        final sessions = [
          _createGameSession(score: 300, duration: Duration(seconds: 25)),
          _createGameSession(score: 350, duration: Duration(seconds: 30)),
          _createGameSession(score: 400, duration: Duration(seconds: 35)),
        ];

        expect(engine.assessPlayerSkill(sessions), equals(SkillLevel.intermediate));
      });

      test('classifies advanced player correctly', () {
        final sessions = [
          _createGameSession(score: 700, duration: Duration(seconds: 45)),
          _createGameSession(score: 800, duration: Duration(seconds: 50)),
          _createGameSession(score: 900, duration: Duration(seconds: 55)),
        ];

        expect(engine.assessPlayerSkill(sessions), equals(SkillLevel.intermediate));
      });

      test('classifies expert player correctly', () {
        final sessions = [
          _createGameSession(score: 1200, duration: Duration(seconds: 70)),
          _createGameSession(score: 1300, duration: Duration(seconds: 75)),
          _createGameSession(score: 1400, duration: Duration(seconds: 80)),
        ];

        expect(engine.assessPlayerSkill(sessions), equals(SkillLevel.advanced));
      });
    });

    group('adjustGameBalance', () {
      test('makes game easier for struggling players', () {
        final metrics = PlayerMetrics(
          averageScore: 100.0,
          averageSessionDuration: Duration(seconds: 15),
          successRate: 0.2, // Low success rate
          jumpAccuracy: 0.3,
          drawingEfficiency: 0.4,
          consistencyScore: 0.5,
          recentPerformanceTrend: -0.2,
        );

        final config = engine.adjustGameBalance(metrics);
        
        // Should reduce speed and density, increase safe window and coins
        expect(config.speedMultiplier, lessThan(1.0));
        expect(config.densityMultiplier, lessThan(1.0));
        expect(config.safeWindowPx, greaterThan(180.0));
        expect(config.coinMultiplier, greaterThan(1.0));
      });

      test('increases challenge for high-performing players', () {
        final metrics = PlayerMetrics(
          averageScore: 1000.0,
          averageSessionDuration: Duration(seconds: 60),
          successRate: 0.9, // High success rate
          jumpAccuracy: 0.85,
          drawingEfficiency: 0.8,
          consistencyScore: 0.8, // High consistency
          recentPerformanceTrend: 0.1,
        );

        final config = engine.adjustGameBalance(metrics);
        
        // Should increase speed and density, reduce safe window
        expect(config.speedMultiplier, greaterThan(1.0));
        expect(config.densityMultiplier, greaterThan(1.0));
        expect(config.safeWindowPx, lessThan(180.0));
      });

      test('provides assistance for declining performance', () {
        final metrics = PlayerMetrics(
          averageScore: 500.0,
          averageSessionDuration: Duration(seconds: 30),
          successRate: 0.6,
          jumpAccuracy: 0.5,
          drawingEfficiency: 0.6,
          consistencyScore: 0.4,
          recentPerformanceTrend: -0.4, // Declining performance
        );

        final config = engine.adjustGameBalance(metrics);
        
        // Should increase jump buffer and coyote time
        expect(config.jumpBufferMs, greaterThanOrEqualTo(150.0));
        expect(config.coyoteTimeMs, greaterThanOrEqualTo(100.0));
      });
    });

    group('session management', () {
      test('starts and ends session correctly', () {
        engine.startSession('test-session-1');
        
        // Simulate some gameplay
        engine.recordFailure();
        engine.recordSuccess();
        engine.updateSessionMetrics(
          jumps: 5,
          successfulJumps: 3,
          coinsCollected: 10,
        );

        engine.endSession(finalScore: 250, wasSuccessful: true);
        
        // Should have recorded the session
        expect(engine.currentMetrics.averageScore, equals(250.0));
      });

      test('tracks consecutive failures correctly', () {
        engine.startSession('test-session-2');
        
        // Record multiple failures
        engine.recordFailure();
        engine.recordFailure();
        engine.recordFailure();
        
        // Should trigger difficulty reduction
        final config = engine.currentConfig;
        expect(config.speedMultiplier, lessThan(1.0));
      });

      test('recovers difficulty after sustained success', () {
        engine.startSession('test-session-3');
        
        // First trigger difficulty reduction
        for (int i = 0; i < 3; i++) {
          engine.recordFailure();
        }
        
        final reducedConfig = engine.currentConfig;
        expect(reducedConfig.speedMultiplier, lessThan(1.0));
        
        // Then record sustained success
        for (int i = 0; i < 6; i++) {
          engine.recordSuccess();
        }
        
        final recoveredConfig = engine.currentConfig;
        expect(recoveredConfig.speedMultiplier, greaterThan(reducedConfig.speedMultiplier));
      });
    });

    group('real-time adjustment', () {
      test('prevents too frequent adjustments', () {
        final metrics = PlayerMetrics(
          averageScore: 100.0,
          averageSessionDuration: Duration(seconds: 15),
          successRate: 0.2,
          jumpAccuracy: 0.3,
          drawingEfficiency: 0.4,
          consistencyScore: 0.5,
          recentPerformanceTrend: -0.2,
        );

        // First adjustment should work
        final config1 = engine.adjustGameBalance(metrics);
        expect(config1.speedMultiplier, lessThan(1.0));

        // Immediate second adjustment should be ignored
        final config2 = engine.adjustGameBalance(metrics);
        expect(config2.speedMultiplier, equals(config1.speedMultiplier));
      });

      test('records difficulty adjustments', () {
        engine.startSession('adjustment-test');
        
        // Trigger adjustment
        for (int i = 0; i < 3; i++) {
          engine.recordFailure();
        }
        
        final adjustments = engine.recentAdjustments;
        expect(adjustments, isNotEmpty);
        expect(adjustments.first.reason, contains('failure'));
      });
    });

    group('configuration management', () {
      test('resets difficulty to base configuration', () {
        engine.startSession('reset-test');
        
        // Modify difficulty
        for (int i = 0; i < 3; i++) {
          engine.recordFailure();
        }
        
        expect(engine.currentConfig.speedMultiplier, lessThan(1.0));
        
        // Reset
        engine.resetDifficulty();
        
        expect(engine.currentConfig.speedMultiplier, equals(1.0));
        expect(engine.currentConfig.densityMultiplier, equals(1.0));
        expect(engine.currentConfig.safeWindowPx, equals(180.0));
      });

      test('provides current skill level assessment', () {
        // Start with no sessions - should be beginner
        expect(engine.currentSkillLevel, equals(SkillLevel.beginner));
        
        // Add some expert-level sessions
        engine.startSession('skill-test-1');
        engine.updateSessionMetrics(jumps: 20, successfulJumps: 18);
        engine.endSession(finalScore: 1200, wasSuccessful: true);
        
        engine.startSession('skill-test-2');
        engine.updateSessionMetrics(jumps: 25, successfulJumps: 22);
        engine.endSession(finalScore: 1300, wasSuccessful: true);
        
        // Should now assess as higher skill level
        expect(engine.currentSkillLevel, isNot(equals(SkillLevel.beginner)));
      });
    });

    group('edge cases', () {
      test('handles empty metrics gracefully', () {
        final emptyMetrics = engine.currentMetrics;
        expect(emptyMetrics.averageScore, equals(0.0));
        expect(emptyMetrics.successRate, equals(0.0));
        expect(emptyMetrics.jumpAccuracy, equals(0.0));
      });

      test('handles single session metrics', () {
        engine.startSession('single-session');
        engine.updateSessionMetrics(jumps: 10, successfulJumps: 7);
        engine.endSession(finalScore: 500, wasSuccessful: true);
        
        final metrics = engine.currentMetrics;
        expect(metrics.averageScore, equals(500.0));
        expect(metrics.jumpAccuracy, equals(0.7));
      });

      test('limits session history size', () {
        // Add more sessions than the window size
        for (int i = 0; i < 15; i++) {
          engine.startSession('session-$i');
          engine.endSession(finalScore: i * 100, wasSuccessful: true);
        }
        
        // Should only keep the most recent sessions
        expect(engine.currentMetrics.averageScore, lessThan(1500.0));
      });
    });
  });
}

/// Helper function to create a test game session
GameSession _createGameSession({
  required int score,
  required Duration duration,
  double jumpAccuracy = 0.7,
  double avoidanceRate = 0.6,
}) {
  final session = GameSession(
    sessionId: 'test-${DateTime.now().millisecondsSinceEpoch}',
    startTime: DateTime.now().subtract(duration),
  );
  
  session.endTime = DateTime.now();
  session.score = score;
  session.totalJumps = 10;
  session.successfulJumps = (10 * jumpAccuracy).round();
  session.totalObstaclesEncountered = 15;
  session.obstaclesAvoided = (15 * avoidanceRate).round();
  session.coinsCollected = score ~/ 10;
  
  return session;
}