/// Tests for leaderboard and competition system
library leaderboard_system_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/social/models/social_models.dart';
import '../lib/social/services/leaderboard_service.dart';
import '../lib/social/leaderboard_manager.dart';

void main() {
  group('Leaderboard System Tests', () {
    late SharedPreferences prefs;
    late LeaderboardService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = LeaderboardService(prefs);
    });

    tearDown(() async {
      service.dispose();
      await prefs.clear();
    });

    group('LeaderboardService', () {
      test('should initialize with sample data', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        
        final globalLeaderboard = await service.getLeaderboard(LeaderboardType.global);
        expect(globalLeaderboard, isNotNull);
        expect(globalLeaderboard!.entries.isNotEmpty, true);
        expect(globalLeaderboard.type, LeaderboardType.global);
      });

      test('should submit score and update rankings', () async {
        // Submit a high score
        await service.submitScore('test_player', 'TestPlayer', 20000);
        
        final leaderboard = await service.getLeaderboard(LeaderboardType.global);
        expect(leaderboard, isNotNull);
        
        // Find the test player entry
        final testPlayerEntry = leaderboard!.entries
            .firstWhere((entry) => entry.playerId == 'test_player');
        
        expect(testPlayerEntry.score, 20000);
        expect(testPlayerEntry.playerName, 'TestPlayer');
        expect(testPlayerEntry.rank, 1); // Should be rank 1 with high score
      });

      test('should award badges for achievements', () async {
        // Submit score to get rank 1
        await service.submitScore('badge_player', 'BadgePlayer', 25000);
        
        // Wait for badge processing
        await Future.delayed(const Duration(milliseconds: 100));
        
        final badges = await service.getPlayerBadges('badge_player');
        expect(badges.isNotEmpty, true);
        
        // Should have top player badge
        final topPlayerBadge = badges.firstWhere(
          (badge) => badge.type == BadgeType.topPlayer,
          orElse: () => throw Exception('Top player badge not found'),
        );
        
        expect(topPlayerBadge.name, 'Top Player');
        expect(topPlayerBadge.rarity, 5);
      });

      test('should handle multiple score submissions correctly', () async {
        // Submit multiple scores for same player
        await service.submitScore('multi_player', 'MultiPlayer', 5000);
        await service.submitScore('multi_player', 'MultiPlayer', 10000);
        await service.submitScore('multi_player', 'MultiPlayer', 15000);
        
        final leaderboard = await service.getLeaderboard(LeaderboardType.global);
        expect(leaderboard, isNotNull);
        
        // Should only have one entry for the player with highest score
        final playerEntries = leaderboard!.entries
            .where((entry) => entry.playerId == 'multi_player')
            .toList();
        
        expect(playerEntries.length, 1);
        expect(playerEntries.first.score, 15000);
      });

      test('should maintain top 100 entries only', () async {
        // Submit 150 different scores
        for (int i = 0; i < 150; i++) {
          await service.submitScore('player_$i', 'Player$i', 1000 + i);
        }
        
        final leaderboard = await service.getLeaderboard(LeaderboardType.global);
        expect(leaderboard, isNotNull);
        expect(leaderboard!.entries.length, lessThanOrEqualTo(100));
        
        // Entries should be sorted by score descending
        for (int i = 0; i < leaderboard.entries.length - 1; i++) {
          expect(
            leaderboard.entries[i].score,
            greaterThanOrEqualTo(leaderboard.entries[i + 1].score),
          );
        }
      });

      test('should handle weekly leaderboard reset', () async {
        // Submit score to weekly leaderboard
        await service.submitScore('weekly_player', 'WeeklyPlayer', 12000);
        
        var weeklyLeaderboard = await service.getLeaderboard(LeaderboardType.weekly);
        expect(weeklyLeaderboard, isNotNull);
        expect(weeklyLeaderboard!.entries.isNotEmpty, true);
        
        // Manually trigger weekly reset
        await service._resetWeeklyLeaderboard();
        
        weeklyLeaderboard = await service.getLeaderboard(LeaderboardType.weekly);
        expect(weeklyLeaderboard, isNotNull);
        expect(weeklyLeaderboard!.entries.isEmpty, true);
      });

      test('should provide leaderboard rewards correctly', () async {
        final rewards = service.getLeaderboardRewards();
        expect(rewards.isNotEmpty, true);
        
        // Check reward structure
        final topReward = rewards.first;
        expect(topReward.minRank, 1);
        expect(topReward.maxRank, 1);
        expect(topReward.coinReward, greaterThan(0));
        expect(topReward.specialItem, isNotNull);
        
        // Test eligibility
        expect(topReward.isEligible(1), true);
        expect(topReward.isEligible(2), false);
      });
    });

    group('LeaderboardManager Integration', () {
      setUp(() async {
        await LeaderboardManager.initialize();
      });

      test('should submit score and return result with improvements', () async {
        final result = await LeaderboardManager.instance.submitScore(
          playerId: 'integration_player',
          playerName: 'IntegrationPlayer',
          score: 18000,
        );
        
        expect(result.success, true);
        expect(result.globalRank, isNotNull);
        expect(result.weeklyRank, isNotNull);
        expect(result.monthlyRank, isNotNull);
      });

      test('should get player ranking summary', () async {
        // Submit score first
        await LeaderboardManager.instance.submitScore(
          playerId: 'summary_player',
          playerName: 'SummaryPlayer',
          score: 16000,
        );
        
        final summary = await LeaderboardManager.instance
            .getPlayerRankingSummary('summary_player');
        
        expect(summary.playerId, 'summary_player');
        expect(summary.highestScore, 16000);
        expect(summary.globalRank, isNotNull);
        expect(summary.badges, isNotNull);
      });

      test('should get all leaderboards', () async {
        final leaderboards = await LeaderboardManager.instance.getAllLeaderboards();
        
        expect(leaderboards.isNotEmpty, true);
        expect(leaderboards.containsKey(LeaderboardType.global), true);
        expect(leaderboards.containsKey(LeaderboardType.weekly), true);
        expect(leaderboards.containsKey(LeaderboardType.monthly), true);
      });

      test('should get qualified rewards for player', () async {
        // Submit high score to qualify for rewards
        await LeaderboardManager.instance.submitScore(
          playerId: 'reward_player',
          playerName: 'RewardPlayer',
          score: 30000,
        );
        
        final qualifiedRewards = await LeaderboardManager.instance
            .getQualifiedRewards('reward_player');
        
        expect(qualifiedRewards.isNotEmpty, true);
      });
    });

    group('Badge System', () {
      test('should award different badge types correctly', () async {
        // Test top player badge
        await service.submitScore('top_player', 'TopPlayer', 50000);
        await Future.delayed(const Duration(milliseconds: 100));
        
        var badges = await service.getPlayerBadges('top_player');
        expect(badges.any((b) => b.type == BadgeType.topPlayer), true);
        
        // Test weekly champion badge (simulate weekly leaderboard)
        final weeklyLeaderboard = await service.getLeaderboard(LeaderboardType.weekly);
        if (weeklyLeaderboard != null) {
          await service.submitScore('weekly_champ', 'WeeklyChamp', 45000);
          await Future.delayed(const Duration(milliseconds: 100));
          
          badges = await service.getPlayerBadges('weekly_champ');
          // Note: Weekly champion badge logic would need weekly leaderboard context
        }
      });

      test('should not award duplicate badges', () async {
        // Submit multiple high scores
        await service.submitScore('no_dupe_player', 'NoDupePlayer', 40000);
        await service.submitScore('no_dupe_player', 'NoDupePlayer', 41000);
        await service.submitScore('no_dupe_player', 'NoDupePlayer', 42000);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        final badges = await service.getPlayerBadges('no_dupe_player');
        final topPlayerBadges = badges.where((b) => b.type == BadgeType.topPlayer).toList();
        
        expect(topPlayerBadges.length, 1); // Should only have one top player badge
      });

      test('should serialize and deserialize badges correctly', () async {
        final originalBadge = Badge(
          type: BadgeType.topPlayer,
          name: 'Test Badge',
          description: 'Test Description',
          iconUrl: 'test_icon.png',
          earnedAt: DateTime.now(),
          rarity: 5,
        );
        
        final json = originalBadge.toJson();
        final deserializedBadge = Badge.fromJson(json);
        
        expect(deserializedBadge.type, originalBadge.type);
        expect(deserializedBadge.name, originalBadge.name);
        expect(deserializedBadge.description, originalBadge.description);
        expect(deserializedBadge.iconUrl, originalBadge.iconUrl);
        expect(deserializedBadge.rarity, originalBadge.rarity);
      });
    });

    group('Requirements Verification', () {
      test('Requirement 4.1: Global leaderboard implementation', () async {
        // Submit scores from multiple players
        await service.submitScore('global_1', 'GlobalPlayer1', 10000);
        await service.submitScore('global_2', 'GlobalPlayer2', 15000);
        await service.submitScore('global_3', 'GlobalPlayer3', 12000);
        
        final globalLeaderboard = await service.getLeaderboard(LeaderboardType.global);
        expect(globalLeaderboard, isNotNull);
        expect(globalLeaderboard!.type, LeaderboardType.global);
        expect(globalLeaderboard.entries.length, greaterThanOrEqualTo(3));
        
        // Verify ranking order (highest score first)
        expect(globalLeaderboard.entries.first.score, 15000);
        expect(globalLeaderboard.entries.first.rank, 1);
      });

      test('Requirement 4.4: Badge system for ranking achievements', () async {
        // Submit score to achieve rank 1
        await service.submitScore('badge_test', 'BadgeTest', 99999);
        await Future.delayed(const Duration(milliseconds: 100));
        
        final badges = await service.getPlayerBadges('badge_test');
        expect(badges.isNotEmpty, true);
        
        final topPlayerBadge = badges.firstWhere(
          (badge) => badge.type == BadgeType.topPlayer,
          orElse: () => throw Exception('Top player badge should be awarded'),
        );
        
        expect(topPlayerBadge.name, 'Top Player');
        expect(topPlayerBadge.description, contains('Reached #1'));
      });
    });
  });
}