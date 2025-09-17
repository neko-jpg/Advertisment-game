import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/progression/skill_progression_system.dart';

void main() {
  group('SkillProgressionSystem', () {
    late SkillProgressionSystem system;

    setUp(() {
      system = SkillProgressionSystem();
    });

    group('Skill Tier Calculation', () {
      test('calculates novice tier for new player', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(minutes: 5),
          averageScore: 25.0,
          bestScore: 50,
          totalGamesPlayed: 3,
          successfulGames: 1,
          averageAccuracy: 0.4,
          consistencyRating: 0.3,
          improvementRate: 0.0,
        );

        final tier = system.calculateSkillTier(metrics);
        expect(tier, equals(SkillTier.novice));
      });

      test('calculates apprentice tier for improving player', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(minutes: 30),
          averageScore: 200.0,
          bestScore: 300,
          totalGamesPlayed: 20,
          successfulGames: 12,
          averageAccuracy: 0.65,
          consistencyRating: 0.6,
          improvementRate: 0.1,
        );

        final tier = system.calculateSkillTier(metrics);
        expect(tier, equals(SkillTier.apprentice));
      });

      test('calculates skilled tier for competent player', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(hours: 1),
          averageScore: 500.0,
          bestScore: 700,
          totalGamesPlayed: 50,
          successfulGames: 38,
          averageAccuracy: 0.8,
          consistencyRating: 0.75,
          improvementRate: 0.15,
        );

        final tier = system.calculateSkillTier(metrics);
        expect(tier, equals(SkillTier.skilled));
      });

      test('calculates expert tier for advanced player', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(hours: 2),
          averageScore: 800.0,
          bestScore: 1200,
          totalGamesPlayed: 100,
          successfulGames: 85,
          averageAccuracy: 0.88,
          consistencyRating: 0.85,
          improvementRate: 0.2,
        );

        final tier = system.calculateSkillTier(metrics);
        expect(tier, equals(SkillTier.expert));
      });

      test('calculates master tier for exceptional player', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(hours: 4),
          averageScore: 1000.0,
          bestScore: 1500,
          totalGamesPlayed: 200,
          successfulGames: 180,
          averageAccuracy: 0.92,
          consistencyRating: 0.9,
          improvementRate: 0.25,
        );

        final tier = system.calculateSkillTier(metrics);
        expect(tier, equals(SkillTier.master));
      });
    });

    group('Milestone Requirements', () {
      test('checks milestone requirements correctly', () {
        final milestone = SkillMilestone(
          id: 'test_milestone',
          name: 'Test Milestone',
          description: 'Test description',
          tier: SkillTier.apprentice,
          requirements: {
            'gamesPlayed': 10,
            'averageScore': 200,
            'successRate': 0.6,
          },
          rewards: [UnlockableFeature.rainbowPen],
          experienceRequired: 500,
        );

        // Metrics that meet requirements
        final validMetrics = SkillMetrics(
          totalPlayTime: Duration(minutes: 30),
          averageScore: 250.0,
          bestScore: 400,
          totalGamesPlayed: 15,
          successfulGames: 10,
          averageAccuracy: 0.7,
          consistencyRating: 0.6,
          improvementRate: 0.1,
        );

        expect(system.checkMilestoneRequirements(milestone, validMetrics), isTrue);

        // Metrics that don't meet requirements
        final invalidMetrics = SkillMetrics(
          totalPlayTime: Duration(minutes: 15),
          averageScore: 150.0,
          bestScore: 200,
          totalGamesPlayed: 5,
          successfulGames: 2,
          averageAccuracy: 0.5,
          consistencyRating: 0.4,
          improvementRate: 0.0,
        );

        expect(system.checkMilestoneRequirements(milestone, invalidMetrics), isFalse);
      });
    });

    group('Progression Updates', () {
      test('updates progression and unlocks features', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(minutes: 30),
          averageScore: 200.0,
          bestScore: 300,
          totalGamesPlayed: 25,
          successfulGames: 15,
          averageAccuracy: 0.65,
          consistencyRating: 0.6,
          improvementRate: 0.1,
        );

        final progression = system.updateProgression(metrics);

        expect(progression.currentTier, equals(SkillTier.apprentice));
        expect(progression.unlockedFeatures.contains(UnlockableFeature.basicDrawingTools), isTrue);
        expect(progression.unlockedFeatures.contains(UnlockableFeature.advancedDrawingTools), isTrue);
        expect(progression.experience, greaterThan(0));
      });

      test('tracks completed milestones', () {
        final metrics = SkillMetrics(
          totalPlayTime: Duration(minutes: 10),
          averageScore: 75.0,
          bestScore: 100,
          totalGamesPlayed: 10,
          successfulGames: 6,
          averageAccuracy: 0.6,
          consistencyRating: 0.5,
          improvementRate: 0.05,
        );

        final progression = system.updateProgression(metrics);

        expect(progression.completedMilestones.isNotEmpty, isTrue);
        expect(progression.skillPoints, greaterThan(0));
      });
    });

    group('Challenge Modes', () {
      test('returns available challenge modes based on tier', () {
        // Test with novice tier (should have no challenges)
        system.updateProgression(SkillMetrics(
          totalPlayTime: Duration(minutes: 5),
          averageScore: 25.0,
          bestScore: 50,
          totalGamesPlayed: 3,
          successfulGames: 1,
          averageAccuracy: 0.4,
          consistencyRating: 0.3,
          improvementRate: 0.0,
        ));

        var availableChallenges = system.getAvailableChallengeModes();
        expect(availableChallenges.length, equals(0));

        // Test with skilled tier (should have multiple challenges)
        system.updateProgression(SkillMetrics(
          totalPlayTime: Duration(hours: 1),
          averageScore: 500.0,
          bestScore: 700,
          totalGamesPlayed: 50,
          successfulGames: 38,
          averageAccuracy: 0.8,
          consistencyRating: 0.75,
          improvementRate: 0.15,
        ));

        availableChallenges = system.getAvailableChallengeModes();
        expect(availableChallenges.length, greaterThan(0));
        expect(availableChallenges.any((c) => c.id == 'speed_challenge'), isTrue);
      });
    });

    group('Feature Unlocking', () {
      test('unlocks features based on tier progression', () {
        expect(system.isFeatureUnlocked(UnlockableFeature.basicDrawingTools), isFalse);

        // Progress to apprentice tier
        system.updateProgression(SkillMetrics(
          totalPlayTime: Duration(minutes: 30),
          averageScore: 200.0,
          bestScore: 300,
          totalGamesPlayed: 25,
          successfulGames: 15,
          averageAccuracy: 0.65,
          consistencyRating: 0.6,
          improvementRate: 0.1,
        ));

        expect(system.isFeatureUnlocked(UnlockableFeature.basicDrawingTools), isTrue);
        expect(system.isFeatureUnlocked(UnlockableFeature.advancedDrawingTools), isTrue);
        expect(system.isFeatureUnlocked(UnlockableFeature.masterMode), isFalse);
      });
    });

    group('Progress Tracking', () {
      test('calculates progress to next tier correctly', () {
        system.updateProgression(SkillMetrics(
          totalPlayTime: Duration(minutes: 15),
          averageScore: 100.0,
          bestScore: 150,
          totalGamesPlayed: 15,
          successfulGames: 8,
          averageAccuracy: 0.55,
          consistencyRating: 0.5,
          improvementRate: 0.05,
        ));

        final progress = system.getProgressToNextTier();
        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      });

      test('identifies next milestone correctly', () {
        final nextMilestone = system.getNextMilestone();
        expect(nextMilestone, isNotNull);
        expect(nextMilestone!.id, isNotEmpty);
      });
    });

    group('Display Names', () {
      test('provides correct display names for tiers', () {
        expect(system.getSkillTierDisplayName(SkillTier.novice), equals('初心者'));
        expect(system.getSkillTierDisplayName(SkillTier.apprentice), equals('見習い'));
        expect(system.getSkillTierDisplayName(SkillTier.skilled), equals('熟練者'));
        expect(system.getSkillTierDisplayName(SkillTier.expert), equals('エキスパート'));
        expect(system.getSkillTierDisplayName(SkillTier.master), equals('マスター'));
      });

      test('provides correct display names for features', () {
        expect(system.getFeatureDisplayName(UnlockableFeature.basicDrawingTools), equals('基本描画ツール'));
        expect(system.getFeatureDisplayName(UnlockableFeature.rainbowPen), equals('虹ペン'));
        expect(system.getFeatureDisplayName(UnlockableFeature.masterMode), equals('マスターモード'));
      });
    });

    group('Experience System', () {
      test('calculates experience requirements for tiers', () {
        expect(system.getExperienceRequiredForTier(SkillTier.novice), equals(0));
        expect(system.getExperienceRequiredForTier(SkillTier.apprentice), equals(1000));
        expect(system.getExperienceRequiredForTier(SkillTier.skilled), equals(3000));
        expect(system.getExperienceRequiredForTier(SkillTier.expert), equals(7000));
        expect(system.getExperienceRequiredForTier(SkillTier.master), equals(15000));
      });
    });
  });
}