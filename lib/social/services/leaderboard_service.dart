/// Leaderboard service for managing rankings and competitions
library leaderboard_service;

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/social_models.dart';

/// Service for managing leaderboards and rankings
class LeaderboardService {
  static const String _globalLeaderboardKey = 'global_leaderboard';
  static const String _friendsLeaderboardKey = 'friends_leaderboard';
  static const String _weeklyLeaderboardKey = 'weekly_leaderboard';
  static const String _monthlyLeaderboardKey = 'monthly_leaderboard';
  static const String _playerBadgesKey = 'player_badges';
  static const String _lastWeeklyResetKey = 'last_weekly_reset';
  static const String _lastMonthlyResetKey = 'last_monthly_reset';

  final SharedPreferences _prefs;
  final StreamController<Leaderboard> _leaderboardController = StreamController.broadcast();
  final StreamController<List<Badge>> _badgesController = StreamController.broadcast();

  LeaderboardService(this._prefs) {
    _initializeLeaderboards();
  }

  /// Stream of leaderboard updates
  Stream<Leaderboard> get leaderboardStream => _leaderboardController.stream;

  /// Stream of badge updates
  Stream<List<Badge>> get badgesStream => _badgesController.stream;

  /// Initialize leaderboards with sample data if empty
  Future<void> _initializeLeaderboards() async {
    await _checkAndResetPeriodic();
    
    // Initialize with sample data if empty
    final globalData = _prefs.getString(_globalLeaderboardKey);
    if (globalData == null) {
      await _createSampleLeaderboards();
    }
  }

  /// Check and reset weekly/monthly leaderboards if needed
  Future<void> _checkAndResetPeriodic() async {
    final now = DateTime.now();
    
    // Check weekly reset (every Monday)
    final lastWeeklyReset = _prefs.getString(_lastWeeklyResetKey);
    if (lastWeeklyReset == null || _shouldResetWeekly(DateTime.parse(lastWeeklyReset), now)) {
      await _resetWeeklyLeaderboard();
      await _prefs.setString(_lastWeeklyResetKey, now.toIso8601String());
    }
    
    // Check monthly reset (first day of month)
    final lastMonthlyReset = _prefs.getString(_lastMonthlyResetKey);
    if (lastMonthlyReset == null || _shouldResetMonthly(DateTime.parse(lastMonthlyReset), now)) {
      await _resetMonthlyLeaderboard();
      await _prefs.setString(_lastMonthlyResetKey, now.toIso8601String());
    }
  }

  bool _shouldResetWeekly(DateTime lastReset, DateTime now) {
    final daysSinceReset = now.difference(lastReset).inDays;
    final lastResetWeekday = lastReset.weekday;
    final nowWeekday = now.weekday;
    
    // Reset if it's been more than 7 days or if we've passed Monday
    return daysSinceReset >= 7 || (lastResetWeekday > 1 && nowWeekday == 1);
  }

  bool _shouldResetMonthly(DateTime lastReset, DateTime now) {
    return lastReset.month != now.month || lastReset.year != now.year;
  }

  /// Create sample leaderboard data
  Future<void> _createSampleLeaderboards() async {
    final sampleEntries = [
      LeaderboardEntry(
        playerId: 'player_1',
        playerName: 'ArtMaster',
        score: 15420,
        rank: 1,
        achievedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      LeaderboardEntry(
        playerId: 'player_2',
        playerName: 'SpeedDrawer',
        score: 14890,
        rank: 2,
        achievedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      LeaderboardEntry(
        playerId: 'player_3',
        playerName: 'LineRunner',
        score: 13750,
        rank: 3,
        achievedAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      LeaderboardEntry(
        playerId: 'current_player',
        playerName: 'You',
        score: 8500,
        rank: 15,
        achievedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];

    final globalLeaderboard = Leaderboard(
      type: LeaderboardType.global,
      entries: sampleEntries,
      lastUpdated: DateTime.now(),
      totalPlayers: 1247,
      currentPlayerEntry: sampleEntries.last,
    );

    await _saveLeaderboard(globalLeaderboard);
  }

  /// Get leaderboard by type
  Future<Leaderboard?> getLeaderboard(LeaderboardType type) async {
    await _checkAndResetPeriodic();
    
    final key = _getLeaderboardKey(type);
    final data = _prefs.getString(key);
    
    if (data == null) return null;
    
    final json = jsonDecode(data) as Map<String, dynamic>;
    return _leaderboardFromJson(json, type);
  }

  /// Submit a new score to leaderboards
  Future<void> submitScore(String playerId, String playerName, int score) async {
    final now = DateTime.now();
    
    // Update all leaderboard types
    for (final type in LeaderboardType.values) {
      final leaderboard = await getLeaderboard(type);
      if (leaderboard != null) {
        final updatedLeaderboard = await _updateLeaderboardWithScore(
          leaderboard,
          playerId,
          playerName,
          score,
          now,
        );
        await _saveLeaderboard(updatedLeaderboard);
        
        // Check for new badges
        await _checkAndAwardBadges(playerId, updatedLeaderboard);
      }
    }
  }

  /// Update leaderboard with new score
  Future<Leaderboard> _updateLeaderboardWithScore(
    Leaderboard leaderboard,
    String playerId,
    String playerName,
    int score,
    DateTime achievedAt,
  ) async {
    final entries = List<LeaderboardEntry>.from(leaderboard.entries);
    
    // Remove existing entry for this player
    entries.removeWhere((entry) => entry.playerId == playerId);
    
    // Add new entry
    final newEntry = LeaderboardEntry(
      playerId: playerId,
      playerName: playerName,
      score: score,
      rank: 1, // Will be recalculated
      achievedAt: achievedAt,
    );
    
    entries.add(newEntry);
    
    // Sort by score (descending) and recalculate ranks
    entries.sort((a, b) => b.score.compareTo(a.score));
    final rankedEntries = entries.asMap().entries.map((entry) {
      return entry.value.copyWith(rank: entry.key + 1);
    }).toList();
    
    // Keep only top 100 entries
    final topEntries = rankedEntries.take(100).toList();
    
    // Find current player entry
    final currentPlayerEntry = topEntries.firstWhere(
      (entry) => entry.playerId == playerId,
      orElse: () => newEntry.copyWith(rank: rankedEntries.length + 1),
    );
    
    return leaderboard.copyWith(
      entries: topEntries,
      lastUpdated: achievedAt,
      currentPlayerEntry: currentPlayerEntry,
    );
  }

  /// Check and award badges based on leaderboard performance
  Future<void> _checkAndAwardBadges(String playerId, Leaderboard leaderboard) async {
    final currentBadges = await getPlayerBadges(playerId);
    final newBadges = <Badge>[];
    
    final playerEntry = leaderboard.currentPlayerEntry;
    if (playerEntry == null) return;
    
    // Top player badge (rank 1)
    if (playerEntry.rank == 1 && !_hasBadge(currentBadges, BadgeType.topPlayer)) {
      newBadges.add(Badge(
        type: BadgeType.topPlayer,
        name: 'Top Player',
        description: 'Reached #1 on the leaderboard!',
        iconUrl: 'assets/badges/top_player.png',
        earnedAt: DateTime.now(),
        rarity: 5,
      ));
    }
    
    // Weekly champion badge
    if (leaderboard.type == LeaderboardType.weekly && 
        playerEntry.rank == 1 && 
        !_hasBadge(currentBadges, BadgeType.weeklyChampion)) {
      newBadges.add(Badge(
        type: BadgeType.weeklyChampion,
        name: 'Weekly Champion',
        description: 'Won the weekly competition!',
        iconUrl: 'assets/badges/weekly_champion.png',
        earnedAt: DateTime.now(),
        rarity: 4,
      ));
    }
    
    // Monthly champion badge
    if (leaderboard.type == LeaderboardType.monthly && 
        playerEntry.rank == 1 && 
        !_hasBadge(currentBadges, BadgeType.monthlyChampion)) {
      newBadges.add(Badge(
        type: BadgeType.monthlyChampion,
        name: 'Monthly Champion',
        description: 'Won the monthly competition!',
        iconUrl: 'assets/badges/monthly_champion.png',
        earnedAt: DateTime.now(),
        rarity: 5,
      ));
    }
    
    if (newBadges.isNotEmpty) {
      await _awardBadges(playerId, newBadges);
    }
  }

  /// Check if player has a specific badge type
  bool _hasBadge(List<Badge> badges, BadgeType type) {
    return badges.any((badge) => badge.type == type);
  }

  /// Award badges to player
  Future<void> _awardBadges(String playerId, List<Badge> badges) async {
    final currentBadges = await getPlayerBadges(playerId);
    final allBadges = [...currentBadges, ...badges];
    
    final badgesJson = allBadges.map((badge) => badge.toJson()).toList();
    await _prefs.setString('${_playerBadgesKey}_$playerId', jsonEncode(badgesJson));
    
    _badgesController.add(allBadges);
  }

  /// Get player's badges
  Future<List<Badge>> getPlayerBadges(String playerId) async {
    final data = _prefs.getString('${_playerBadgesKey}_$playerId');
    if (data == null) return [];
    
    final badgesJson = jsonDecode(data) as List<dynamic>;
    return badgesJson.map((json) => Badge.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get leaderboard rewards for a specific rank
  List<LeaderboardReward> getLeaderboardRewards() {
    return [
      const LeaderboardReward(
        minRank: 1,
        maxRank: 1,
        coinReward: 1000,
        badges: [],
        specialItem: 'Golden Crown',
      ),
      const LeaderboardReward(
        minRank: 2,
        maxRank: 3,
        coinReward: 500,
        badges: [],
        specialItem: 'Silver Trophy',
      ),
      const LeaderboardReward(
        minRank: 4,
        maxRank: 10,
        coinReward: 250,
        badges: [],
      ),
      const LeaderboardReward(
        minRank: 11,
        maxRank: 50,
        coinReward: 100,
        badges: [],
      ),
    ];
  }

  /// Reset weekly leaderboard
  Future<void> _resetWeeklyLeaderboard() async {
    final emptyLeaderboard = Leaderboard(
      type: LeaderboardType.weekly,
      entries: [],
      lastUpdated: DateTime.now(),
      totalPlayers: 0,
    );
    await _saveLeaderboard(emptyLeaderboard);
  }

  /// Reset monthly leaderboard
  Future<void> _resetMonthlyLeaderboard() async {
    final emptyLeaderboard = Leaderboard(
      type: LeaderboardType.monthly,
      entries: [],
      lastUpdated: DateTime.now(),
      totalPlayers: 0,
    );
    await _saveLeaderboard(emptyLeaderboard);
  }

  /// Save leaderboard to storage
  Future<void> _saveLeaderboard(Leaderboard leaderboard) async {
    final key = _getLeaderboardKey(leaderboard.type);
    final json = _leaderboardToJson(leaderboard);
    await _prefs.setString(key, jsonEncode(json));
    _leaderboardController.add(leaderboard);
  }

  /// Get storage key for leaderboard type
  String _getLeaderboardKey(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.global:
      case LeaderboardType.allTime:
        return _globalLeaderboardKey;
      case LeaderboardType.friends:
        return _friendsLeaderboardKey;
      case LeaderboardType.weekly:
        return _weeklyLeaderboardKey;
      case LeaderboardType.monthly:
        return _monthlyLeaderboardKey;
    }
  }

  /// Convert leaderboard to JSON
  Map<String, dynamic> _leaderboardToJson(Leaderboard leaderboard) {
    return {
      'type': leaderboard.type.name,
      'entries': leaderboard.entries.map((e) => e.toJson()).toList(),
      'lastUpdated': leaderboard.lastUpdated.toIso8601String(),
      'totalPlayers': leaderboard.totalPlayers,
      'currentPlayerEntry': leaderboard.currentPlayerEntry?.toJson(),
    };
  }

  /// Convert JSON to leaderboard
  Leaderboard _leaderboardFromJson(Map<String, dynamic> json, LeaderboardType type) {
    return Leaderboard(
      type: type,
      entries: (json['entries'] as List<dynamic>)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      totalPlayers: json['totalPlayers'] as int,
      currentPlayerEntry: json['currentPlayerEntry'] != null
          ? LeaderboardEntry.fromJson(json['currentPlayerEntry'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Dispose resources
  void dispose() {
    _leaderboardController.close();
    _badgesController.close();
  }
}