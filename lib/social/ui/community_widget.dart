/// Community UI widget for teams, events, and artwork gallery
library community_widget;

import 'package:flutter/material.dart';
import '../models/social_models.dart';
import '../community_manager.dart';

/// Widget for community features including teams, events, and artwork
class CommunityWidget extends StatefulWidget {
  final String currentPlayerId;
  final String currentPlayerName;
  final VoidCallback? onClose;

  const CommunityWidget({
    super.key,
    required this.currentPlayerId,
    required this.currentPlayerName,
    this.onClose,
  });

  @override
  State<CommunityWidget> createState() => _CommunityWidgetState();
}

class _CommunityWidgetState extends State<CommunityWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Team> _playerTeams = [];
  List<Team> _teamLeaderboard = [];
  List<MonthlyEvent> _activeEvents = [];
  List<Artwork> _featuredArtwork = [];
  List<Artwork> _popularArtwork = [];
  CommunitySummary? _communitySummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommunityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityData() async {
    setState(() => _isLoading = true);
    
    try {
      final playerTeams = await CommunityManager.instance.getPlayerTeams(widget.currentPlayerId);
      final teamLeaderboard = await CommunityManager.instance.getTeamLeaderboard();
      final activeEvents = await CommunityManager.instance.getActiveEvents();
      final featuredArtwork = await CommunityManager.instance.getFeaturedArtwork();
      final popularArtwork = await CommunityManager.instance.getPopularArtwork();
      final communitySummary = await CommunityManager.instance.getCommunitySummary(widget.currentPlayerId);
      
      setState(() {
        _playerTeams = playerTeams;
        _teamLeaderboard = teamLeaderboard;
        _activeEvents = activeEvents;
        _featuredArtwork = featuredArtwork;
        _popularArtwork = popularArtwork;
        _communitySummary = communitySummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load community data: $e')),
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
            Colors.purple.shade900,
            Colors.indigo.shade900,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Community',
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
              onPressed: _loadCommunityData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Teams'),
              Tab(text: 'Events'),
              Tab(text: 'Gallery'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : Column(
                children: [
                  // Community summary
                  if (_communitySummary != null) _buildCommunitySummary(),
                  
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTeamsTab(),
                        _buildEventsTab(),
                        _buildGalleryTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCommunitySummary() {
    final summary = _communitySummary!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Teams', summary.teamsCount.toString(), Icons.groups),
          _buildSummaryItem('Artwork', summary.artworkCount.toString(), Icons.palette),
          _buildSummaryItem('Likes', summary.totalArtworkLikes.toString(), Icons.favorite),
          _buildSummaryItem('Events', summary.activeEventsCount.toString(), Icons.event),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.amber, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamsTab() {
    return Column(
      children: [
        // Create/Join team buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateTeamDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Team'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showJoinTeamDialog,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join Team'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Teams content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player's teams
                if (_playerTeams.isNotEmpty) ...[
                  const Text(
                    'Your Teams',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._playerTeams.map((team) => _buildTeamCard(team, true)),
                  const SizedBox(height: 24),
                ],
                
                // Team leaderboard
                const Text(
                  'Team Leaderboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (_teamLeaderboard.isEmpty)
                  Center(
                    child: Text(
                      'No teams yet. Create the first one!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  )
                else
                  ..._teamLeaderboard.take(10).map((team) => _buildTeamCard(team, false)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Team team, bool isPlayerTeam) {
    final rank = _teamLeaderboard.indexOf(team) + 1;
    
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!isPlayerTeam && rank <= 3)
                  Icon(
                    rank == 1 ? Icons.emoji_events : Icons.military_tech,
                    color: rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey : Colors.orange),
                    size: 24,
                  ),
                if (!isPlayerTeam && rank <= 3) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.teamName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${team.memberIds.length} members • ${team.totalScore} points',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPlayerTeam)
                  Text(
                    '#$rank',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (isPlayerTeam) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _viewTeamDetails(team),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _leaveTeam(team),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Leave'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Events',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_activeEvents.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active events',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back soon for exciting community events!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._activeEvents.map((event) => _buildEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildEventCard(MonthlyEvent event) {
    final daysLeft = event.endDate.difference(DateTime.now()).inDays;
    
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getEventIcon(event.type),
                  color: Colors.amber,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.eventName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$daysLeft days left',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            // Rewards preview
            if (event.rewards.isNotEmpty) ...[
              Text(
                'Rewards:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...event.rewards.take(3).map((reward) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  '${_getRankText(reward.rank)}: ${reward.coinReward} coins${reward.specialItem != null ? ' + ${reward.specialItem}' : ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              )),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _participateInEvent(event),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Participate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Submit artwork button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showSubmitArtworkDialog,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Submit Artwork'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          
          // Gallery tabs
          const TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Featured'),
              Tab(text: 'Popular'),
            ],
          ),
          
          // Gallery content
          Expanded(
            child: TabBarView(
              children: [
                _buildArtworkGrid(_featuredArtwork),
                _buildArtworkGrid(_popularArtwork),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkGrid(List<Artwork> artworks) {
    if (artworks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No artwork yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share your creation!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: artworks.length,
      itemBuilder: (context, index) {
        final artwork = artworks[index];
        return _buildArtworkCard(artwork);
      },
    );
  }

  Widget _buildArtworkCard(Artwork artwork) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Artwork image placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Icon(
                Icons.image,
                size: 48,
                color: Colors.white54,
              ),
            ),
          ),
          
          // Artwork info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artwork.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${artwork.playerName}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      artwork.likes.toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (artwork.status == ArtworkStatus.featured)
                      Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTeamDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your team name:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Team name',
                border: OutlineInputBorder(),
              ),
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createTeam(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Team'),
        content: const Text('Team joining feature coming soon! You\'ll be able to browse and join existing teams.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSubmitArtworkDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Artwork'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: In a full implementation, you would select an image file here.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _submitArtwork(titleController.text, descriptionController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeam(String teamName) async {
    final result = await CommunityManager.instance.createTeam(
      teamName: teamName,
      leaderId: widget.currentPlayerId,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'Team created!' : 'Failed to create team')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadCommunityData();
      }
    }
  }

  Future<void> _leaveTeam(Team team) async {
    final result = await CommunityManager.instance.leaveTeam(
      teamId: team.teamId,
      playerId: widget.currentPlayerId,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'Left team!' : 'Failed to leave team')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadCommunityData();
      }
    }
  }

  void _viewTeamDetails(Team team) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(team.teamName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members: ${team.memberIds.length}'),
            Text('Total Score: ${team.totalScore}'),
            Text('Status: ${team.status.name}'),
            const SizedBox(height: 16),
            const Text('Member Scores:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...team.memberScores.entries.map((entry) => 
              Text('${entry.key}: ${entry.value} points')
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _participateInEvent(MonthlyEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.eventName),
        content: Text('Event participation feature coming soon! You\'ll be able to join ${event.eventName} and compete for rewards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitArtwork(String title, String description) async {
    final result = await CommunityManager.instance.submitArtwork(
      playerId: widget.currentPlayerId,
      playerName: widget.currentPlayerName,
      title: title,
      description: description.isEmpty ? null : description,
      imageUrl: 'assets/artwork/placeholder.png',
      tags: ['community', 'player-created'],
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'Artwork submitted!' : 'Failed to submit artwork')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadCommunityData();
      }
    }
  }

  IconData _getEventIcon(EventType type) {
    switch (type) {
      case EventType.teamBattle:
        return Icons.groups;
      case EventType.artContest:
        return Icons.palette;
      case EventType.speedChallenge:
        return Icons.speed;
      case EventType.collectathon:
        return Icons.monetization_on;
    }
  }

  String _getRankText(int rank) {
    switch (rank) {
      case 1:
        return '1st Place';
      case 2:
        return '2nd Place';
      case 3:
        return '3rd Place';
      default:
        return '${rank}th Place';
    }
  }
}