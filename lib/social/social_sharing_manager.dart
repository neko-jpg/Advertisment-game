/// Social sharing manager for friend invitations and social features
library social_sharing_manager;

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/social_models.dart';
import 'services/friend_invitation_service.dart';

/// Manager for social sharing and friend invitation features
class SocialSharingManager {
  static SocialSharingManager? _instance;
  static SocialSharingManager get instance => _instance!;
  
  late final FriendInvitationService _friendService;
  final StreamController<SocialUpdate> _updateController = StreamController.broadcast();
  
  /// Stream of social updates
  Stream<SocialUpdate> get updateStream => _updateController.stream;

  SocialSharingManager._();

  /// Initialize the social sharing manager
  static Future<void> initialize() async {
    _instance = SocialSharingManager._();
    final prefs = await SharedPreferences.getInstance();
    _instance!._friendService = FriendInvitationService(prefs);
    
    // Listen to invitation updates
    _instance!._friendService.invitationsStream.listen((invitations) {
      _instance!._updateController.add(SocialUpdate(
        type: SocialUpdateType.invitations,
        invitations: invitations,
      ));
    });
    
    // Listen to challenge updates
    _instance!._friendService.challengesStream.listen((challenges) {
      _instance!._updateController.add(SocialUpdate(
        type: SocialUpdateType.challenges,
        challenges: challenges,
      ));
    });
    
    // Listen to share updates
    _instance!._friendService.shareStream.listen((share) {
      _instance!._updateController.add(SocialUpdate(
        type: SocialUpdateType.share,
        share: share,
      ));
    });
  }

  /// Send friend invitation with rewards
  /// Requirements: 4.2 - Friend invitation system (500 coins + limited skin)
  Future<InvitationResult> sendFriendInvitation({
    required String inviterId,
    required String inviterName,
    required String inviteeIdentifier,
  }) async {
    try {
      final invitation = await _friendService.sendInvitation(
        inviterId: inviterId,
        inviterName: inviterName,
        inviteeIdentifier: inviteeIdentifier,
      );

      return InvitationResult(
        success: true,
        invitation: invitation,
        message: 'Invitation sent successfully! You and your friend will both receive 500 coins and a special skin when they join.',
      );
    } catch (e) {
      return InvitationResult(
        success: false,
        error: 'Failed to send invitation: $e',
      );
    }
  }

  /// Accept friend invitation
  Future<InvitationResult> acceptFriendInvitation({
    required String invitationId,
    required String inviteeId,
  }) async {
    try {
      final invitation = await _friendService.acceptInvitation(
        invitationId: invitationId,
        inviteeId: inviteeId,
      );

      return InvitationResult(
        success: true,
        invitation: invitation,
        message: 'Welcome! You and your friend have both received 500 coins and a special skin!',
      );
    } catch (e) {
      return InvitationResult(
        success: false,
        error: 'Failed to accept invitation: $e',
      );
    }
  }

  /// Get pending invitations for user
  Future<List<FriendInvitation>> getPendingInvitations(String userId) async {
    return await _friendService.getPendingInvitations(userId);
  }

  /// Claim invitation reward
  Future<RewardClaimResult> claimInvitationReward(String invitationId) async {
    try {
      final reward = await _friendService.claimInvitationReward(invitationId);
      
      return RewardClaimResult(
        success: true,
        reward: reward,
        message: 'Congratulations! You received ${reward.coinReward} coins${reward.specialSkin != null ? ' and ${reward.specialSkin}' : ''}!',
      );
    } catch (e) {
      return RewardClaimResult(
        success: false,
        error: 'Failed to claim reward: $e',
      );
    }
  }

  /// Send challenge to friend
  /// Requirements: 4.3 - Challenge sending and receiving system
  Future<ChallengeResult> sendChallenge({
    required String challengerId,
    required String challengerName,
    required String challengeeId,
    required String challengeeName,
    required ChallengeType type,
    required int targetScore,
  }) async {
    try {
      final challenge = await _friendService.sendChallenge(
        challengerId: challengerId,
        challengerName: challengerName,
        challengeeId: challengeeId,
        challengeeName: challengeeName,
        type: type,
        targetScore: targetScore,
      );

      return ChallengeResult(
        success: true,
        challenge: challenge,
        message: 'Challenge sent to $challengeeName!',
      );
    } catch (e) {
      return ChallengeResult(
        success: false,
        error: 'Failed to send challenge: $e',
      );
    }
  }

  /// Accept challenge
  Future<ChallengeResult> acceptChallenge(String challengeId) async {
    try {
      final challenge = await _friendService.acceptChallenge(challengeId);
      
      return ChallengeResult(
        success: true,
        challenge: challenge,
        message: 'Challenge accepted! Good luck!',
      );
    } catch (e) {
      return ChallengeResult(
        success: false,
        error: 'Failed to accept challenge: $e',
      );
    }
  }

  /// Complete challenge with score
  Future<ChallengeResult> completeChallenge({
    required String challengeId,
    required int score,
  }) async {
    try {
      final challenge = await _friendService.completeChallenge(
        challengeId: challengeId,
        score: score,
      );

      final message = challenge.status == ChallengeStatus.completed
          ? 'Congratulations! You completed the challenge!'
          : 'Challenge failed, but great effort! Try again!';

      return ChallengeResult(
        success: true,
        challenge: challenge,
        message: message,
      );
    } catch (e) {
      return ChallengeResult(
        success: false,
        error: 'Failed to complete challenge: $e',
      );
    }
  }

  /// Get pending challenges for user
  Future<List<FriendChallenge>> getPendingChallenges(String userId) async {
    return await _friendService.getPendingChallenges(userId);
  }

  /// Get all challenges for user
  Future<List<FriendChallenge>> getUserChallenges(String userId) async {
    return await _friendService.getChallenges(userId: userId);
  }

  /// Share high score achievement
  /// Requirements: 4.2 - Social media sharing functionality
  Future<ShareResult> shareHighScore({
    required String playerId,
    required String playerName,
    required int score,
    required int rank,
    required List<String> platforms,
  }) async {
    try {
      final content = _friendService.generateHighScoreShareContent(
        score: score,
        rank: rank,
      );

      final share = await _friendService.shareContent(
        playerId: playerId,
        playerName: playerName,
        type: ShareType.highScore,
        content: content,
        platforms: platforms,
      );

      return ShareResult(
        success: true,
        share: share,
        message: 'High score shared successfully!',
      );
    } catch (e) {
      return ShareResult(
        success: false,
        error: 'Failed to share high score: $e',
      );
    }
  }

  /// Share achievement badge
  Future<ShareResult> shareAchievement({
    required String playerId,
    required String playerName,
    required Badge badge,
    required List<String> platforms,
  }) async {
    try {
      final content = _friendService.generateAchievementShareContent(badge: badge);

      final share = await _friendService.shareContent(
        playerId: playerId,
        playerName: playerName,
        type: ShareType.achievement,
        content: content,
        platforms: platforms,
      );

      return ShareResult(
        success: true,
        share: share,
        message: 'Achievement shared successfully!',
      );
    } catch (e) {
      return ShareResult(
        success: false,
        error: 'Failed to share achievement: $e',
      );
    }
  }

  /// Share challenge invitation
  Future<ShareResult> shareChallenge({
    required String playerId,
    required String playerName,
    required String challengerName,
    required int targetScore,
    required ChallengeType type,
    required List<String> platforms,
  }) async {
    try {
      final content = _friendService.generateChallengeShareContent(
        challengerName: challengerName,
        targetScore: targetScore,
        type: type,
      );

      final share = await _friendService.shareContent(
        playerId: playerId,
        playerName: playerName,
        type: ShareType.challenge,
        content: content,
        platforms: platforms,
      );

      return ShareResult(
        success: true,
        share: share,
        message: 'Challenge shared successfully!',
      );
    } catch (e) {
      return ShareResult(
        success: false,
        error: 'Failed to share challenge: $e',
      );
    }
  }

  /// Get user's friends list
  Future<List<String>> getFriends(String userId) async {
    return await _friendService.getFriends(userId);
  }

  /// Get social summary for user
  Future<SocialSummary> getSocialSummary(String userId) async {
    final invitations = await _friendService.getInvitations(userId: userId);
    final challenges = await _friendService.getChallenges(userId: userId);
    final friends = await getFriends(userId);
    
    final pendingInvitations = invitations.where((inv) => 
      inv.status == InvitationStatus.pending && inv.inviteeId == userId
    ).length;
    
    final pendingChallenges = challenges.where((ch) => 
      ch.status == ChallengeStatus.pending && ch.challengeeId == userId
    ).length;
    
    final completedChallenges = challenges.where((ch) => 
      ch.status == ChallengeStatus.completed && ch.challengeeId == userId
    ).length;

    return SocialSummary(
      userId: userId,
      friendsCount: friends.length,
      pendingInvitations: pendingInvitations,
      pendingChallenges: pendingChallenges,
      completedChallenges: completedChallenges,
      totalInvitationsSent: invitations.where((inv) => inv.inviterId == userId).length,
      totalChallengesSent: challenges.where((ch) => ch.challengerId == userId).length,
    );
  }

  /// Dispose resources
  void dispose() {
    _friendService.dispose();
    _updateController.close();
  }
}

/// Result of invitation operation
class InvitationResult {
  final bool success;
  final String? error;
  final String? message;
  final FriendInvitation? invitation;

  const InvitationResult({
    required this.success,
    this.error,
    this.message,
    this.invitation,
  });
}

/// Result of reward claim operation
class RewardClaimResult {
  final bool success;
  final String? error;
  final String? message;
  final InvitationReward? reward;

  const RewardClaimResult({
    required this.success,
    this.error,
    this.message,
    this.reward,
  });
}

/// Result of challenge operation
class ChallengeResult {
  final bool success;
  final String? error;
  final String? message;
  final FriendChallenge? challenge;

  const ChallengeResult({
    required this.success,
    this.error,
    this.message,
    this.challenge,
  });
}

/// Result of share operation
class ShareResult {
  final bool success;
  final String? error;
  final String? message;
  final SocialShare? share;

  const ShareResult({
    required this.success,
    this.error,
    this.message,
    this.share,
  });
}

/// Social summary for user
class SocialSummary {
  final String userId;
  final int friendsCount;
  final int pendingInvitations;
  final int pendingChallenges;
  final int completedChallenges;
  final int totalInvitationsSent;
  final int totalChallengesSent;

  const SocialSummary({
    required this.userId,
    required this.friendsCount,
    required this.pendingInvitations,
    required this.pendingChallenges,
    required this.completedChallenges,
    required this.totalInvitationsSent,
    required this.totalChallengesSent,
  });
}

/// Social update types
enum SocialUpdateType {
  invitations,
  challenges,
  share,
  friends,
}

/// Social update notification
class SocialUpdate {
  final SocialUpdateType type;
  final List<FriendInvitation>? invitations;
  final List<FriendChallenge>? challenges;
  final SocialShare? share;
  final List<String>? friends;

  const SocialUpdate({
    required this.type,
    this.invitations,
    this.challenges,
    this.share,
    this.friends,
  });
}