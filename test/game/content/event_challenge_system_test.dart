import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/game/content/event_challenge_system.dart';
import 'package:myapp/game/content/models/event_models.dart';
import 'package:myapp/game/models/game_models.dart';

void main() {
  group('EventChallengeSystem', () {
    late EventChallengeSystem system;
    bool stateChanged = false;

    setUp(() {
      stateChanged = false;
      system = EventChallengeSystem(
        onStateChanged: () => stateChanged = true,
      );
    });

    test('initializes with default challenges', () {
      system.initialize();
      
      expect(system.challenges.isNotEmpty, isTrue);
      expect(system.unlockedChallenges.isNotEmpty, isTrue);
      expect(stateChanged, isTrue);
    });

    test('generates daily missions', () {
      system.initialize();
      
      final missions = system.getTodaysMissions();
      expect(missions.length, equals(3));
      
      for (final mission in missions) {
        expect(mission.target, greaterThan(0));
        expect(mission.reward, greaterThan(0));
        expect(mission.progress, equals(0));
        expect(mission.completed, isFalse);
      }
    });

    test('updates challenge progress correctly', () {
      system.initialize();
      
      // Find the coin collector challenge
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      expect(coinChallenge.isUnlocked, isTrue);
      expect(coinChallenge.completed, isFalse);
      
      // Simulate collecting coins
      system.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 200,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 1000,
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));
      
      final objective = coinChallenge.objectives.first;
      expect(objective.currentValue, equals(200));
      expect(coinChallenge.progress[objective.id], equals(0.2)); // 200/1000
    });

    test('completes challenges when objectives are met', () {
      system.initialize();
      
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      // Complete the challenge by collecting enough coins
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 200,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      expect(coinChallenge.completed, isTrue);
      expect(coinChallenge.allObjectivesCompleted, isTrue);
    });

    test('unlocks new challenges when prerequisites are met', () {
      system.initialize();
      
      final perfectRunChallenge = system.challenges.firstWhere(
        (c) => c.id == 'perfect_run',
      );
      
      expect(perfectRunChallenge.isUnlocked, isFalse);
      
      // Complete the coin collector challenge
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 200,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      expect(coinChallenge.completed, isTrue);
      expect(perfectRunChallenge.isUnlocked, isTrue);
    });

    test('updates daily mission progress', () {
      system.initialize();
      
      final missions = system.getTodaysMissions();
      final coinMission = missions.firstWhere(
        (m) => m.type == MissionType.collectCoins,
        orElse: () => missions.first, // Fallback if no coin mission
      );
      
      final initialProgress = coinMission.progress;
      
      system.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 50,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 1000,
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));
      
      if (coinMission.type == MissionType.collectCoins) {
        expect(coinMission.progress, equals(initialProgress + 50));
      }
    });

    test('completes daily missions when targets are reached', () {
      system.initialize();
      
      final missions = system.getTodaysMissions();
      final mission = missions.first;
      
      // Set progress to just below target
      mission.progress = mission.target - 1;
      
      // Complete one more game to reach target
      system.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 1000, // High score to ensure mission completion
        coins: 100,
        usedLine: true,
        jumpsPerformed: 50,
        drawTimeMs: 10000,
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));
      
      // Check if any mission was completed
      final completedMissions = missions.where((m) => m.completed).toList();
      expect(completedMissions.isNotEmpty, isTrue);
    });

    test('handles perfect run challenge correctly', () {
      system.initialize();
      
      // First complete coin collector to unlock perfect run
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 200,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      final perfectRunChallenge = system.challenges.firstWhere(
        (c) => c.id == 'perfect_run',
      );
      
      expect(perfectRunChallenge.isUnlocked, isTrue);
      
      // Complete 5 runs without accidents
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 50,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0, // No accident
        ));
      }
      
      final objective = perfectRunChallenge.objectives.first;
      expect(objective.currentValue, greaterThanOrEqualTo(5));
      
      // One run with accident should reset progress
      system.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 50,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 1000,
        accidentDeath: true,
        nearMisses: 0,
        inkEfficiency: 1.0, // Accident!
      ));
      
      expect(objective.currentValue, equals(0)); // Reset
    });

    test('handles speed challenge correctly', () {
      system.initialize();
      
      final speedChallenge = system.challenges.firstWhere(
        (c) => c.id == 'speed_master',
      );
      
      expect(speedChallenge.isUnlocked, isTrue);
      
      // Complete 5 fast runs (under 30 seconds each)
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 25), // Fast completion
          score: 100,
          coins: 50,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      expect(speedChallenge.completed, isTrue);
    });

    test('can claim rewards', () {
      system.initialize();
      
      // Complete a challenge
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 200,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      expect(coinChallenge.completed, isTrue);
      expect(coinChallenge.claimed, isFalse);
      
      // Claim rewards
      final claimed = system.claimChallengeRewards(coinChallenge.id);
      expect(claimed, isTrue);
      expect(coinChallenge.claimed, isTrue);
      
      // Can't claim again
      final claimedAgain = system.claimChallengeRewards(coinChallenge.id);
      expect(claimedAgain, isFalse);
    });

    test('tracks challenge attempts', () {
      system.initialize();
      
      final speedChallenge = system.challenges.firstWhere(
        (c) => c.id == 'speed_master',
      );
      
      expect(speedChallenge.attempts, equals(0));
      
      system.startChallenge(speedChallenge.id);
      expect(speedChallenge.attempts, equals(1));
      
      system.startChallenge(speedChallenge.id);
      expect(speedChallenge.attempts, equals(2));
    });

    test('serialization works correctly', () {
      system.initialize();
      
      // Make some progress
      system.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 200,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 1000,
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));
      
      // Serialize
      final json = system.toJson();
      
      // Create new system and deserialize
      final newSystem = EventChallengeSystem(onStateChanged: () {});
      newSystem.fromJson(json);
      
      // Verify state is preserved
      expect(newSystem.challenges.length, equals(system.challenges.length));
      expect(newSystem.dailyMissionSystem.missions.length, 
             equals(system.dailyMissionSystem.missions.length));
      
      // Check that progress was preserved
      final originalCoinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      final newCoinChallenge = newSystem.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      expect(newCoinChallenge.objectives.first.currentValue,
             equals(originalCoinChallenge.objectives.first.currentValue));
    });

    test('handles drawing master challenge', () {
      system.initialize();
      
      // First unlock the drawing master challenge by completing perfect run
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      // Complete coin collector
      for (int i = 0; i < 5; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 200,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      // Complete perfect run
      final perfectRunChallenge = system.challenges.firstWhere(
        (c) => c.id == 'perfect_run',
      );
      
      for (int i = 0; i < 10; i++) {
        system.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 50,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      
      final drawingMasterChallenge = system.challenges.firstWhere(
        (c) => c.id == 'drawing_master',
      );
      
      expect(drawingMasterChallenge.isUnlocked, isTrue);
      
      // Test drawing time objective
      final drawingTimeObjective = drawingMasterChallenge.objectives.firstWhere(
        (o) => o.id == 'drawing_time',
      );
      
      // Play with lots of drawing time
      system.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 50,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 60000, // 1 minute
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));
      
      expect(drawingTimeObjective.currentValue, greaterThanOrEqualTo(60000));
    });

    test('handles edge cases gracefully', () {
      system.initialize();
      
      // Try to claim rewards from non-existent challenge
      expect(() => system.claimChallengeRewards('non_existent'), 
             throwsArgumentError);
      
      // Try to start non-existent challenge
      expect(() => system.startChallenge('non_existent'), 
             throwsArgumentError);
      
      // Try to claim rewards from incomplete challenge
      final coinChallenge = system.challenges.firstWhere(
        (c) => c.id == 'coin_collector',
      );
      
      expect(system.claimChallengeRewards(coinChallenge.id), isFalse);
    });
  });
}
