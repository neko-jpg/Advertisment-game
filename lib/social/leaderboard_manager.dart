/// Leaderboard manager for coordinating ranking and competition systems
library leaderboard_manager;

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/social_models.dart';
import 'services/leaderboard_service.dart';

/// Manager for leaderboard and competition features
class LeaderboardManager {
  static LeaderboardManager? _instance;
  static LeaderboardManager get instance => _instance!;
  
  late final LeaderboardService _leaderboardService;
  final StreamController<LeaderboardUpdate> _updateController = StreamController.broadcast();
  
  /// Stream of leaderboard updates
  Stream<LeaderboardUpdate> get updateStream => _updateController.stream;

  LeaderboardManager._();

  /// Initialize the leaderboard manager
  static Future<void> initialize() async {
    _instance = LeaderboardManager._();
    final prefs = await SharedPreferences.getInstance();
    _instance!._leaderboardService = LeaderboardService(prefs);
    
    // Listen to leaderboard updates
    _instance!._leaderboardService.leaderboardStream.listen((leaderboard) {
      _instance!._updateController.add(LeaderboardUpdate(
        type: UpdateType.leaderboard,
        leaderboard: leaderboard,
      ));
    });
    
    // Listen to badge updates
    _instance!._leaderboardService.badgesStream.listen((badges) {
      _instance!._updateController.add(LeaderboardUpdate(
        type: UpdateType.badges,
        badges: badges,
      ));
    });
  }

  /// Submit a score to all relevant leaderboards
  /// Requirements: 4.1 - Global leaderboard implementation
  Future<ScoreSubmissionResult> submitScore({
    required String playerId,
    required String playerName,
    required int score,
  }) async {
    try {
      await _leaderboardService.submitScore(playerId, playerName, score);
      
      // Get updated leaderboards to check improvements
      final globalLeaderboard = await _leaderboardService.getLeaderboard(LeaderboardType.global);
      final weeklyLeaderboard = await _leaderboardService.getLeaderboard(LeaderboardType.weekly);
      final monthlyLeaderboard = await _leaderboardService.getLeaderboard(LeaderboardType.monthly);
      
      final improvements = <RankImprovement>[];
      
      // Check for rank improvements
      if (globalLeaderboard?.currentPlayerEntry != null) {
        final entry = globalLeaderboard!.currentPlayerEntry!;
        if (entry.rank <= 10) {
          improvements.add(RankImprovement(
            leaderboardType: LeaderboardType.global,
            newRank: entry.rank,
            improvement: 'Entered top 10 globally!',
          ));
        }
      }
      
      if (weeklyLeaderboard?.currentPlayerEntry != null) {
        final entry = weeklyLeaderboard!.currentPlayerEntry!;
        if (entry.rank <= 5) {
          improvements.add(RankImprovement(
            leaderboardType: LeaderboardType.weekly,
            newRank: entry.rank,
            improvement: 'Top 5 this week!',
          ));
        }
      }
      
      // Get newly earned badges
      final badges = await _leaderboardService.getPlayerBadges(playerId);
      final recentBadges = badges.where((badge) {
        final timeDiff = DateTime.now().difference(badge.earnedAt);
        return timeDiff.inMinutes < 5; // Badges earned in last 5 minutes
      }).toList();
      
      return ScoreSubmissionResult(
        success: true,
        rankImprovements: improvements,
        newBadges: recentBadges,
        globalRank: globalLeaderboard?.currentPlayerEntry?.rank,
        weeklyRank: weeklyLeaderboard?.currentPlayerEntry?.rank,
        monthlyRank: monthlyLeaderboard?.currentPlayerEntry?.rank,
      );
    } catch (e) {
      return ScoreSubmissionResult(
        success: false,
        error: 'Failed to submit score: $e',
      );
    }
  }

  /// Get leaderboard data
  /// Requirements: 4.1 - Global and friends leaderboard
  Future<Leaderboard?> getLeaderboard(LeaderboardType type) async {
    return await _leaderboardService.getLeaderboard(type);
  }

  /// Get all leaderboards for display
  Future<Map<LeaderboardType, Leaderboard>> getAllLeaderboards() async {
    final leaderboards = <LeaderboardType, Leaderboard>{};
    
    for (final type in LeaderboardType.values) {
      final leaderboard = await _leaderboardService.getLeaderboard(type);
      if (leaderboard != null) {
        leaderboards[type] = leaderboard;
      }
    }
    
    return leaderboards;
  }

  /// Get player's badges
  /// Requirements: 4.4 - Badge system implementation
  Future<List<Badge>> getPlayerBadges(String playerId) async {
    return await _leaderboardService.getPlayerBadges(playerId);
  }

  /// Get available rewards for current rankings
  Future<List<LeaderboardReward>> getAvailableRewards() async {
    return _leaderboardService.getLeaderboardRewards();
  }

  /// Check if player qualifies for any rewards
  Future<List<LeaderboardReward>> getQualifiedRewards(String playerId) async {
    final rewards = <LeaderboardReward>[];
    final availableRewards = await getAvailableRewards();
    
    // Check global leaderboard
    final globalLeaderboard = await getLeaderboard(LeaderboardType.global);
    if (globalLeaderboard?.currentPlayerEntry != null) {
      final rank = globalLeaderboard!.currentPlayerEntry!.rank;
      rewards.addAll(availableRewards.where((reward) => reward.isEligible(rank)));
    }
    
    return rewards;
  }

  /// Get player's current ranking summary
  Future<PlayerRankingSummary> getPlayerRankingSummary(String playerId) async {
    final globalLeaderboard = await getLeaderboard(LeaderboardType.global);
    final weeklyLeaderboard = await getLeaderboard(LeaderboardType.weekly);
    final monthlyLeaderboard = await getLeaderboard(LeaderboardType.monthly);
    final badges = await getPlayerBadges(playerId);
    
    return PlayerRankingSummary(
      playerId: playerId,
      globalRank: globalLeaderboard?.currentPlayerEntry?.rank,
      weeklyRank: weeklyLeaderboard?.currentPlayerEntry?.rank,
      monthlyRank: monthlyLeaderboard?.currentPlayerEntry?.rank,
      totalBadges: badges.length,
      highestScore: globalLeaderboard?.currentPlayerEntry?.score ?? 0,
      badges: badges,
    );
  }

  /// Dispose resources
  void dispose() {
    _leaderboardService.dispose();
    _updateController.close();
  }
}

/// Result of score submission
class ScoreSubmissionResult {
  final bool success;
  final String? error;
  final List<RankImprovement> rankImprovements;
  final List<Badge> newBadges;
  final int? globalRank;
  final int? weeklyRank;
  final int? monthlyRank;

  const ScoreSubmissionResult({
    required this.success,
    this.error,
    this.rankImprovements = const [],
    this.newBadges = const [],
    this.globalRank,
    this.weeklyRank,
    this.monthlyRank,
  });

  bool get hasImprovements => rankImprovements.isNotEmpty || newBadges.isNotEmpty;
}

/// Represents a rank improvement
class RankImprovement {
  final LeaderboardType leaderboardType;
  final int newRank;
  final String improvement;

  const RankImprovement({
    required this.leaderboardType,
    required this.newRank,
    required this.improvement,
  });
}

/// Player's ranking summary
class PlayerRankingSummary {
  final String playerId;
  final int? globalRank;
  final int? weeklyRank;
  final int? monthlyRank;
  final int totalBadges;
  final int highestScore;
  final List<Badge> badges;

  const PlayerRankingSummary({
    required this.playerId,
    this.globalRank,
    this.weeklyRank,
    this.monthlyRank,
    required this.totalBadges,
    required this.highestScore,
    required this.badges,
  });
}

/// Leaderboard update types
enum UpdateType {
  leaderboard,
  badges,
  rewards,
}

/// Leaderboard update notification
class LeaderboardUpdate {
  final UpdateType type;
  final Leaderboard? leaderboard;
  final List<Badge>? badges;
  final List<LeaderboardReward>? rewards;

  const LeaderboardUpdate({
    required this.type,
    this.leaderboard,
    this.badges,
    this.rewards,
  });
}