/// Main social system integration for Quick Draw Dash
library social_system;

import 'dart:async';
import 'leaderboard_manager.dart';
import 'social_sharing_manager.dart';
import 'community_manager.dart';
import 'models/social_models.dart';

/// Main social system that coordinates all social features
class SocialSystem {
  static SocialSystem? _instance;
  static SocialSystem get instance => _instance!;
  
  final StreamController<SocialSystemUpdate> _updateController = StreamController.broadcast();
  
  /// Stream of social system updates
  Stream<SocialSystemUpdate> get updateStream => _updateController.stream;

  SocialSystem._();

  /// Initialize the complete social system
  static Future<void> initialize() async {
    _instance = SocialSystem._();
    
    // Initialize all subsystems
    await LeaderboardManager.initialize();
    await SocialSharingManager.initialize();
    await CommunityManager.initialize();
    
    // Listen to updates from all subsystems
    LeaderboardManager.instance.updateStream.listen((update) {
      _instance!._updateController.add(SocialSystemUpdate(
        type: SocialSystemUpdateType.leaderboard,
        leaderboardUpdate: update,
      ));
    });
    
    SocialSharingManager.instance.updateStream.listen((update) {
      _instance!._updateController.add(SocialSystemUpdate(
        type: SocialSystemUpdateType.social,
        socialUpdate: update,
      ));
    });
    
    CommunityManager.instance.updateStream.listen((update) {
      _instance!._updateController.add(SocialSystemUpdate(
        type: SocialSystemUpdateType.community,
        communityUpdate: update,
      ));
    });
  }

  /// Handle post-game score submission with full social integration
  Future<PostGameSocialResult> handlePostGameScore({
    required String playerId,
    required String playerName,
    required int score,
  }) async {
    final results = <String, dynamic>{};
    
    // 1. Submit to leaderboards
    final leaderboardResult = await LeaderboardManager.instance.submitScore(
      playerId: playerId,
      playerName: playerName,
      score: score,
    );
    results['leaderboard'] = leaderboardResult;
    
    // 2. Update team scores if player is in teams
    final playerTeams = await CommunityManager.instance.getPlayerTeams(playerId);
    final teamResults = <TeamResult>[];
    
    for (final team in playerTeams) {
      final teamResult = await CommunityManager.instance.updateTeamScore(
        teamId: team.teamId,
        playerId: playerId,
        score: score,
      );
      teamResults.add(teamResult);
    }
    results['teams'] = teamResults;
    
    // 3. Check for social sharing opportunities
    final shouldPromptShare = leaderboardResult.hasImprovements || 
                             leaderboardResult.newBadges.isNotEmpty;
    
    return PostGameSocialResult(
      leaderboardResult: leaderboardResult,
      teamResults: teamResults,
      shouldPromptShare: shouldPromptShare,
      sharePrompts: shouldPromptShare ? _generateSharePrompts(leaderboardResult) : [],
    );
  }

  /// Get comprehensive social status for a player
  Future<ComprehensiveSocialStatus> getPlayerSocialStatus(String playerId) async {
    // Get data from all subsystems
    final rankingSummary = await LeaderboardManager.instance.getPlayerRankingSummary(playerId);
    final socialSummary = await SocialSharingManager.instance.getSocialSummary(playerId);
    final communitySummary = await CommunityManager.instance.getCommunitySummary(playerId);
    
    // Get pending items
    final pendingInvitations = await SocialSharingManager.instance.getPendingInvitations(playerId);
    final pendingChallenges = await SocialSharingManager.instance.getPendingChallenges(playerId);
    
    return ComprehensiveSocialStatus(
      playerId: playerId,
      rankingSummary: rankingSummary,
      socialSummary: socialSummary,
      communitySummary: communitySummary,
      pendingInvitations: pendingInvitations,
      pendingChallenges: pendingChallenges,
      totalNotifications: pendingInvitations.length + pendingChallenges.length,
    );
  }

  /// Generate contextual share prompts based on achievements
  List<SharePrompt> _generateSharePrompts(ScoreSubmissionResult result) {
    final prompts = <SharePrompt>[];
    
    // High score sharing
    if (result.globalRank != null && result.globalRank! <= 10) {
      prompts.add(SharePrompt(
        type: SharePromptType.highScore,
        title: 'Amazing Score!',
        message: 'You\'re in the top 10 globally! Share your achievement!',
        data: {
          'score': result.globalRank,
          'rank': result.globalRank,
        },
      ));
    }
    
    // Badge achievements
    for (final badge in result.newBadges) {
      prompts.add(SharePrompt(
        type: SharePromptType.achievement,
        title: 'New Badge Earned!',
        message: 'You earned the "${badge.name}" badge!',
        data: {'badge': badge},
      ));
    }
    
    // Rank improvements
    for (final improvement in result.rankImprovements) {
      prompts.add(SharePrompt(
        type: SharePromptType.milestone,
        title: 'Rank Improvement!',
        message: improvement.improvement,
        data: {
          'leaderboardType': improvement.leaderboardType,
          'newRank': improvement.newRank,
        },
      ));
    }
    
    return prompts;
  }

  /// Dispose all resources
  void dispose() {
    LeaderboardManager.instance.dispose();
    SocialSharingManager.instance.dispose();
    CommunityManager.instance.dispose();
    _updateController.close();
  }
}

/// Result of post-game social processing
class PostGameSocialResult {
  final ScoreSubmissionResult leaderboardResult;
  final List<TeamResult> teamResults;
  final bool shouldPromptShare;
  final List<SharePrompt> sharePrompts;

  const PostGameSocialResult({
    required this.leaderboardResult,
    required this.teamResults,
    required this.shouldPromptShare,
    required this.sharePrompts,
  });
}

/// Comprehensive social status for a player
class ComprehensiveSocialStatus {
  final String playerId;
  final PlayerRankingSummary rankingSummary;
  final SocialSummary socialSummary;
  final CommunitySummary communitySummary;
  final List<FriendInvitation> pendingInvitations;
  final List<FriendChallenge> pendingChallenges;
  final int totalNotifications;

  const ComprehensiveSocialStatus({
    required this.playerId,
    required this.rankingSummary,
    required this.socialSummary,
    required this.communitySummary,
    required this.pendingInvitations,
    required this.pendingChallenges,
    required this.totalNotifications,
  });

  bool get hasNotifications => totalNotifications > 0;
}

/// Share prompt for contextual sharing
class SharePrompt {
  final SharePromptType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;

  const SharePrompt({
    required this.type,
    required this.title,
    required this.message,
    required this.data,
  });
}

/// Types of share prompts
enum SharePromptType {
  highScore,
  achievement,
  milestone,
  challenge,
}

/// Social system update types
enum SocialSystemUpdateType {
  leaderboard,
  social,
  community,
}

/// Social system update notification
class SocialSystemUpdate {
  final SocialSystemUpdateType type;
  final LeaderboardUpdate? leaderboardUpdate;
  final SocialUpdate? socialUpdate;
  final CommunityUpdate? communityUpdate;

  const SocialSystemUpdate({
    required this.type,
    this.leaderboardUpdate,
    this.socialUpdate,
    this.communityUpdate,
  });
}