/// Leaderboard UI widget for displaying rankings and competitions
library leaderboard_widget;

import 'package:flutter/material.dart';
import '../models/social_models.dart';
import '../leaderboard_manager.dart';

/// Widget for displaying leaderboards with tabs for different types
class LeaderboardWidget extends StatefulWidget {
  final String currentPlayerId;
  final VoidCallback? onClose;

  const LeaderboardWidget({
    super.key,
    required this.currentPlayerId,
    this.onClose,
  });

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<LeaderboardType, Leaderboard> _leaderboards = {};
  List<Badge> _playerBadges = [];
  bool _isLoading = true;

  final List<LeaderboardType> _tabTypes = [
    LeaderboardType.global,
    LeaderboardType.weekly,
    LeaderboardType.monthly,
    LeaderboardType.friends,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTypes.length, vsync: this);
    _loadLeaderboards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboards() async {
    setState(() => _isLoading = true);
    
    try {
      final leaderboards = await LeaderboardManager.instance.getAllLeaderboards();
      final badges = await LeaderboardManager.instance.getPlayerBadges(widget.currentPlayerId);
      
      setState(() {
        _leaderboards = leaderboards;
        _playerBadges = badges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leaderboards: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade900,
            Colors.purple.shade900,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Leaderboards',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.onClose != null
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadLeaderboards,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _tabTypes.map((type) => Tab(text: _getTabTitle(type))).toList(),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : Column(
                children: [
                  // Player badges section
                  if (_playerBadges.isNotEmpty) _buildBadgesSection(),
                  
                  // Leaderboard tabs
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _tabTypes.map((type) {
                        final leaderboard = _leaderboards[type];
                        return _buildLeaderboardTab(leaderboard, type);
                      }).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Badges',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _playerBadges.length,
              itemBuilder: (context, index) {
                final badge = _playerBadges[index];
                return _buildBadgeItem(badge);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(Badge badge) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getBadgeColor(badge.rarity),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Icon(
              _getBadgeIcon(badge.type),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab(Leaderboard? leaderboard, LeaderboardType type) {
    if (leaderboard == null || leaderboard.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No rankings yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play some games to see rankings!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Current player summary
        if (leaderboard.currentPlayerEntry != null)
          _buildPlayerSummary(leaderboard.currentPlayerEntry!, leaderboard.totalPlayers),
        
        // Leaderboard list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaderboard.entries.length,
            itemBuilder: (context, index) {
              final entry = leaderboard.entries[index];
              final isCurrentPlayer = entry.playerId == widget.currentPlayerId;
              return _buildLeaderboardEntry(entry, isCurrentPlayer);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerSummary(LeaderboardEntry playerEntry, int totalPlayers) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.amber,
            child: Text(
              '#${playerEntry.rank}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${playerEntry.score} points',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Out of $totalPlayers players',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardEntry(LeaderboardEntry entry, bool isCurrentPlayer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? Colors.amber.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: isCurrentPlayer
            ? Border.all(color: Colors.amber)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(entry.rank),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${entry.score} points',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Achievement indicator
          if (entry.rank <= 3)
            Icon(
              entry.rank == 1 ? Icons.emoji_events : Icons.military_tech,
              color: _getRankColor(entry.rank),
              size: 24,
            ),
        ],
      ),
    );
  }

  String _getTabTitle(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.global:
        return 'Global';
      case LeaderboardType.weekly:
        return 'Weekly';
      case LeaderboardType.monthly:
        return 'Monthly';
      case LeaderboardType.friends:
        return 'Friends';
      case LeaderboardType.allTime:
        return 'All Time';
    }
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return Colors.orange.shade700;
    return Colors.blue.shade600;
  }

  Color _getBadgeColor(int rarity) {
    switch (rarity) {
      case 5:
        return Colors.purple.shade600;
      case 4:
        return Colors.amber.shade600;
      case 3:
        return Colors.blue.shade600;
      case 2:
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getBadgeIcon(BadgeType type) {
    switch (type) {
      case BadgeType.topPlayer:
        return Icons.emoji_events;
      case BadgeType.weeklyChampion:
        return Icons.calendar_today;
      case BadgeType.monthlyChampion:
        return Icons.calendar_month;
      case BadgeType.streakMaster:
        return Icons.local_fire_department;
      case BadgeType.socialButterfly:
        return Icons.people;
      case BadgeType.challenger:
        return Icons.sports_martial_arts;
      case BadgeType.mentor:
        return Icons.school;
    }
  }
}