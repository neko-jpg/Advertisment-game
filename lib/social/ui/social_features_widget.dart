/// Social features UI widget for friend invitations and challenges
library social_features_widget;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/social_models.dart';
import '../social_sharing_manager.dart';

/// Widget for social features including invitations and challenges
class SocialFeaturesWidget extends StatefulWidget {
  final String currentPlayerId;
  final String currentPlayerName;
  final VoidCallback? onClose;

  const SocialFeaturesWidget({
    super.key,
    required this.currentPlayerId,
    required this.currentPlayerName,
    this.onClose,
  });

  @override
  State<SocialFeaturesWidget> createState() => _SocialFeaturesWidgetState();
}

class _SocialFeaturesWidgetState extends State<SocialFeaturesWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FriendInvitation> _pendingInvitations = [];
  List<FriendChallenge> _pendingChallenges = [];
  List<FriendChallenge> _userChallenges = [];
  SocialSummary? _socialSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSocialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSocialData() async {
    setState(() => _isLoading = true);
    
    try {
      final pendingInvitations = await SocialSharingManager.instance
          .getPendingInvitations(widget.currentPlayerId);
      final pendingChallenges = await SocialSharingManager.instance
          .getPendingChallenges(widget.currentPlayerId);
      final userChallenges = await SocialSharingManager.instance
          .getUserChallenges(widget.currentPlayerId);
      final socialSummary = await SocialSharingManager.instance
          .getSocialSummary(widget.currentPlayerId);
      
      setState(() {
        _pendingInvitations = pendingInvitations;
        _pendingChallenges = pendingChallenges;
        _userChallenges = userChallenges;
        _socialSummary = socialSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load social data: $e')),
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
            Colors.green.shade900,
            Colors.teal.shade900,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Social Features',
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
              onPressed: _loadSocialData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Invitations'),
              Tab(text: 'Challenges'),
              Tab(text: 'Share'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : Column(
                children: [
                  // Social summary
                  if (_socialSummary != null) _buildSocialSummary(),
                  
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInvitationsTab(),
                        _buildChallengesTab(),
                        _buildShareTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSocialSummary() {
    final summary = _socialSummary!;
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
          _buildSummaryItem('Friends', summary.friendsCount.toString(), Icons.people),
          _buildSummaryItem('Invitations', summary.pendingInvitations.toString(), Icons.mail),
          _buildSummaryItem('Challenges', summary.pendingChallenges.toString(), Icons.sports_martial_arts),
          _buildSummaryItem('Completed', summary.completedChallenges.toString(), Icons.check_circle),
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

  Widget _buildInvitationsTab() {
    return Column(
      children: [
        // Send invitation button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showSendInvitationDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Invite Friends'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        
        // Pending invitations
        Expanded(
          child: _pendingInvitations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 64,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending invitations',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingInvitations.length,
                  itemBuilder: (context, index) {
                    final invitation = _pendingInvitations[index];
                    return _buildInvitationCard(invitation);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(FriendInvitation invitation) {
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
                CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Text(
                    invitation.inviterName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${invitation.inviterName} invited you!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Join and get 500 coins + special skin',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptInvitation(invitation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineInvitation(invitation),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesTab() {
    return Column(
      children: [
        // Send challenge button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showSendChallengeDialog,
            icon: const Icon(Icons.sports_martial_arts),
            label: const Text('Send Challenge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        
        // Challenges list
        Expanded(
          child: _pendingChallenges.isEmpty && _userChallenges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_martial_arts_outlined,
                        size: 64,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No challenges yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_pendingChallenges.isNotEmpty) ...[
                      Text(
                        'Pending Challenges',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._pendingChallenges.map((challenge) => _buildChallengeCard(challenge, true)),
                      const SizedBox(height: 16),
                    ],
                    if (_userChallenges.isNotEmpty) ...[
                      Text(
                        'Your Challenges',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._userChallenges.map((challenge) => _buildChallengeCard(challenge, false)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(FriendChallenge challenge, bool isPending) {
    final isIncoming = challenge.challengeeId == widget.currentPlayerId;
    final otherPlayerName = isIncoming ? challenge.challengerName : challenge.challengeeName;
    
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
                Icon(
                  _getChallengeIcon(challenge.type),
                  color: Colors.amber,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncoming 
                            ? '$otherPlayerName challenged you!'
                            : 'You challenged $otherPlayerName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_getChallengeTypeText(challenge.type)} - Target: ${challenge.targetScore}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildChallengeStatusChip(challenge.status),
              ],
            ),
            if (isPending && isIncoming) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _acceptChallenge(challenge),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineChallenge(challenge),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text('Decline'),
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

  Widget _buildShareTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildShareOption(
            'Share High Score',
            'Show off your best score to friends',
            Icons.emoji_events,
            () => _shareHighScore(),
          ),
          const SizedBox(height: 12),
          _buildShareOption(
            'Share Achievement',
            'Celebrate your latest badge',
            Icons.military_tech,
            () => _shareAchievement(),
          ),
          const SizedBox(height: 12),
          _buildShareOption(
            'Invite Friends',
            'Get 500 coins when friends join',
            Icons.person_add,
            () => _showSendInvitationDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: Colors.amber, size: 32),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
        onTap: onTap,
      ),
    );
  }

  Widget _buildChallengeStatusChip(ChallengeStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case ChallengeStatus.pending:
        color = Colors.orange;
        text = 'Pending';
        break;
      case ChallengeStatus.accepted:
        color = Colors.blue;
        text = 'Accepted';
        break;
      case ChallengeStatus.completed:
        color = Colors.green;
        text = 'Completed';
        break;
      case ChallengeStatus.failed:
        color = Colors.red;
        text = 'Failed';
        break;
      case ChallengeStatus.expired:
        color = Colors.grey;
        text = 'Expired';
        break;
    }
    
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }

  void _showSendInvitationDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your friend\'s email or username:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'friend@example.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Both you and your friend will receive 500 coins and a special skin!',
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
              if (controller.text.isNotEmpty) {
                _sendInvitation(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showSendChallengeDialog() {
    // For demo purposes, show a simple dialog
    // In a real app, this would show a friend selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Challenge'),
        content: const Text('Challenge feature coming soon! You\'ll be able to challenge friends to beat your high score.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation(String identifier) async {
    final result = await SocialSharingManager.instance.sendFriendInvitation(
      inviterId: widget.currentPlayerId,
      inviterName: widget.currentPlayerName,
      inviteeIdentifier: identifier,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'Invitation sent!' : 'Failed to send invitation')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadSocialData();
      }
    }
  }

  Future<void> _acceptInvitation(FriendInvitation invitation) async {
    final result = await SocialSharingManager.instance.acceptFriendInvitation(
      invitationId: invitation.invitationId,
      inviteeId: widget.currentPlayerId,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'Invitation accepted!' : 'Failed to accept invitation')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadSocialData();
      }
    }
  }

  Future<void> _declineInvitation(FriendInvitation invitation) async {
    // For demo purposes, just remove from list
    setState(() {
      _pendingInvitations.removeWhere((inv) => inv.invitationId == invitation.invitationId);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined')),
      );
    }
  }

  Future<void> _acceptChallenge(FriendChallenge challenge) async {
    final result = await SocialSharingManager.instance.acceptChallenge(challenge.challengeId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'Challenge accepted!' : 'Failed to accept challenge')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      
      if (result.success) {
        _loadSocialData();
      }
    }
  }

  Future<void> _declineChallenge(FriendChallenge challenge) async {
    // For demo purposes, just remove from list
    setState(() {
      _pendingChallenges.removeWhere((ch) => ch.challengeId == challenge.challengeId);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge declined')),
      );
    }
  }

  Future<void> _shareHighScore() async {
    // Demo high score sharing
    final result = await SocialSharingManager.instance.shareHighScore(
      playerId: widget.currentPlayerId,
      playerName: widget.currentPlayerName,
      score: 15000,
      rank: 5,
      platforms: ['twitter', 'facebook'],
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? 'High score shared!' : 'Failed to share')),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _shareAchievement() async {
    // Demo achievement sharing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Achievement'),
        content: const Text('Achievement sharing feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  IconData _getChallengeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.beatScore:
        return Icons.emoji_events;
      case ChallengeType.speedRun:
        return Icons.speed;
      case ChallengeType.perfectRun:
        return Icons.star;
      case ChallengeType.coinCollection:
        return Icons.monetization_on;
    }
  }

  String _getChallengeTypeText(ChallengeType type) {
    switch (type) {
      case ChallengeType.beatScore:
        return 'Beat Score';
      case ChallengeType.speedRun:
        return 'Speed Run';
      case ChallengeType.perfectRun:
        return 'Perfect Run';
      case ChallengeType.coinCollection:
        return 'Coin Collection';
    }
  }
}