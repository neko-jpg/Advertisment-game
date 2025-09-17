/// Friend invitation service for managing invitations and rewards
library friend_invitation_service;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/social_models.dart';

/// Service for managing friend invitations and social features
class FriendInvitationService {
  static const String _invitationsKey = 'friend_invitations';
  static const String _challengesKey = 'friend_challenges';
  static const String _friendsListKey = 'friends_list';
  static const String _socialSharesKey = 'social_shares';

  final SharedPreferences _prefs;
  final StreamController<List<FriendInvitation>> _invitationsController = StreamController.broadcast();
  final StreamController<List<FriendChallenge>> _challengesController = StreamController.broadcast();
  final StreamController<SocialShare> _shareController = StreamController.broadcast();

  FriendInvitationService(this._prefs);

  /// Stream of invitation updates
  Stream<List<FriendInvitation>> get invitationsStream => _invitationsController.stream;

  /// Stream of challenge updates
  Stream<List<FriendChallenge>> get challengesStream => _challengesController.stream;

  /// Stream of social share updates
  Stream<SocialShare> get shareStream => _shareController.stream;

  /// Send friend invitation
  /// Requirements: 4.2 - Friend invitation system with rewards
  Future<FriendInvitation> sendInvitation({
    required String inviterId,
    required String inviterName,
    required String inviteeIdentifier,
  }) async {
    final invitation = FriendInvitation(
      invitationId: _generateId(),
      inviterId: inviterId,
      inviterName: inviterName,
      inviteeIdentifier: inviteeIdentifier,
      status: InvitationStatus.pending,
      createdAt: DateTime.now(),
      reward: const InvitationReward(
        coinReward: 500,
        specialSkin: 'Friend Invitation Skin',
      ),
    );

    await _saveInvitation(invitation);
    return invitation;
  }

  /// Accept friend invitation
  Future<FriendInvitation> acceptInvitation({
    required String invitationId,
    required String inviteeId,
  }) async {
    final invitations = await getInvitations();
    final invitationIndex = invitations.indexWhere((inv) => inv.invitationId == invitationId);
    
    if (invitationIndex == -1) {
      throw Exception('Invitation not found');
    }

    final invitation = invitations[invitationIndex];
    if (invitation.status != InvitationStatus.pending) {
      throw Exception('Invitation is not pending');
    }

    final acceptedInvitation = invitation.copyWith(
      inviteeId: inviteeId,
      status: InvitationStatus.accepted,
      acceptedAt: DateTime.now(),
    );

    invitations[invitationIndex] = acceptedInvitation;
    await _saveAllInvitations(invitations);

    // Add both users as friends
    await _addFriend(invitation.inviterId, inviteeId);
    await _addFriend(inviteeId, invitation.inviterId);

    return acceptedInvitation;
  }

  /// Get all invitations for a user
  Future<List<FriendInvitation>> getInvitations({String? userId}) async {
    final data = _prefs.getString(_invitationsKey);
    if (data == null) return [];

    final invitationsJson = jsonDecode(data) as List<dynamic>;
    final invitations = invitationsJson
        .map((json) => FriendInvitation.fromJson(json as Map<String, dynamic>))
        .toList();

    if (userId != null) {
      return invitations.where((inv) => 
        inv.inviterId == userId || inv.inviteeId == userId
      ).toList();
    }

    return invitations;
  }

  /// Get pending invitations for a user
  Future<List<FriendInvitation>> getPendingInvitations(String userId) async {
    final invitations = await getInvitations(userId: userId);
    return invitations.where((inv) => 
      inv.status == InvitationStatus.pending && inv.inviteeId == userId
    ).toList();
  }

  /// Claim invitation reward
  Future<InvitationReward> claimInvitationReward(String invitationId) async {
    final invitations = await getInvitations();
    final invitationIndex = invitations.indexWhere((inv) => inv.invitationId == invitationId);
    
    if (invitationIndex == -1) {
      throw Exception('Invitation not found');
    }

    final invitation = invitations[invitationIndex];
    if (invitation.status != InvitationStatus.accepted) {
      throw Exception('Invitation not accepted');
    }

    if (invitation.reward?.claimed == true) {
      throw Exception('Reward already claimed');
    }

    final claimedReward = invitation.reward!.copyWith(claimed: true);
    final updatedInvitation = invitation.copyWith(reward: claimedReward);
    
    invitations[invitationIndex] = updatedInvitation;
    await _saveAllInvitations(invitations);

    return claimedReward;
  }

  /// Send challenge to friend
  /// Requirements: 4.3 - Challenge system implementation
  Future<FriendChallenge> sendChallenge({
    required String challengerId,
    required String challengerName,
    required String challengeeId,
    required String challengeeName,
    required ChallengeType type,
    required int targetScore,
  }) async {
    final challenge = FriendChallenge(
      challengeId: _generateId(),
      challengerId: challengerId,
      challengerName: challengerName,
      challengeeId: challengeeId,
      challengeeName: challengeeName,
      type: type,
      targetScore: targetScore,
      status: ChallengeStatus.pending,
      createdAt: DateTime.now(),
    );

    await _saveChallenge(challenge);
    return challenge;
  }

  /// Accept challenge
  Future<FriendChallenge> acceptChallenge(String challengeId) async {
    final challenges = await getChallenges();
    final challengeIndex = challenges.indexWhere((ch) => ch.challengeId == challengeId);
    
    if (challengeIndex == -1) {
      throw Exception('Challenge not found');
    }

    final challenge = challenges[challengeIndex];
    if (challenge.status != ChallengeStatus.pending) {
      throw Exception('Challenge is not pending');
    }

    final acceptedChallenge = challenge.copyWith(status: ChallengeStatus.accepted);
    challenges[challengeIndex] = acceptedChallenge;
    await _saveAllChallenges(challenges);

    return acceptedChallenge;
  }

  /// Complete challenge with score
  Future<FriendChallenge> completeChallenge({
    required String challengeId,
    required int score,
  }) async {
    final challenges = await getChallenges();
    final challengeIndex = challenges.indexWhere((ch) => ch.challengeId == challengeId);
    
    if (challengeIndex == -1) {
      throw Exception('Challenge not found');
    }

    final challenge = challenges[challengeIndex];
    if (challenge.status != ChallengeStatus.accepted) {
      throw Exception('Challenge not accepted');
    }

    final status = _evaluateChallengeResult(challenge.type, score, challenge.targetScore);
    final completedChallenge = challenge.copyWith(
      status: status,
      challengeeScore: score,
      completedAt: DateTime.now(),
    );

    challenges[challengeIndex] = completedChallenge;
    await _saveAllChallenges(challenges);

    return completedChallenge;
  }

  /// Get challenges for a user
  Future<List<FriendChallenge>> getChallenges({String? userId}) async {
    final data = _prefs.getString(_challengesKey);
    if (data == null) return [];

    final challengesJson = jsonDecode(data) as List<dynamic>;
    final challenges = challengesJson
        .map((json) => FriendChallenge.fromJson(json as Map<String, dynamic>))
        .toList();

    if (userId != null) {
      return challenges.where((ch) => 
        ch.challengerId == userId || ch.challengeeId == userId
      ).toList();
    }

    return challenges;
  }

  /// Get pending challenges for a user
  Future<List<FriendChallenge>> getPendingChallenges(String userId) async {
    final challenges = await getChallenges(userId: userId);
    return challenges.where((ch) => 
      ch.status == ChallengeStatus.pending && ch.challengeeId == userId
    ).toList();
  }

  /// Share content to social media
  /// Requirements: 4.2 - Social media sharing functionality
  Future<SocialShare> shareContent({
    required String playerId,
    required String playerName,
    required ShareType type,
    required Map<String, dynamic> content,
    required List<String> platforms,
  }) async {
    final share = SocialShare(
      shareId: _generateId(),
      playerId: playerId,
      playerName: playerName,
      type: type,
      content: content,
      createdAt: DateTime.now(),
      platforms: platforms,
    );

    await _saveShare(share);
    _shareController.add(share);

    return share;
  }

  /// Generate share content for high score
  Map<String, dynamic> generateHighScoreShareContent({
    required int score,
    required int rank,
  }) {
    return {
      'score': score,
      'rank': rank,
      'message': 'Just scored $score points in Quick Draw Dash! Can you beat my score?',
      'hashtags': ['#QuickDrawDash', '#HighScore', '#MobileGaming'],
      'imageUrl': 'assets/share/high_score_template.png',
    };
  }

  /// Generate share content for achievement
  Map<String, dynamic> generateAchievementShareContent({
    required Badge badge,
  }) {
    return {
      'badgeName': badge.name,
      'badgeDescription': badge.description,
      'rarity': badge.rarity,
      'message': 'Just earned the "${badge.name}" badge in Quick Draw Dash!',
      'hashtags': ['#QuickDrawDash', '#Achievement', '#Gaming'],
      'imageUrl': 'assets/share/achievement_template.png',
    };
  }

  /// Generate share content for challenge
  Map<String, dynamic> generateChallengeShareContent({
    required String challengerName,
    required int targetScore,
    required ChallengeType type,
  }) {
    final typeText = _getChallengeTypeText(type);
    return {
      'challengerName': challengerName,
      'targetScore': targetScore,
      'challengeType': typeText,
      'message': '$challengerName challenged you to $typeText with a target of $targetScore points!',
      'hashtags': ['#QuickDrawDash', '#Challenge', '#FriendChallenge'],
      'imageUrl': 'assets/share/challenge_template.png',
    };
  }

  /// Get friends list for a user
  Future<List<String>> getFriends(String userId) async {
    final data = _prefs.getString('${_friendsListKey}_$userId');
    if (data == null) return [];

    final friendsJson = jsonDecode(data) as List<dynamic>;
    return friendsJson.cast<String>();
  }

  /// Add friend to user's friends list
  Future<void> _addFriend(String userId, String friendId) async {
    final friends = await getFriends(userId);
    if (!friends.contains(friendId)) {
      friends.add(friendId);
      await _prefs.setString('${_friendsListKey}_$userId', jsonEncode(friends));
    }
  }

  /// Save invitation
  Future<void> _saveInvitation(FriendInvitation invitation) async {
    final invitations = await getInvitations();
    invitations.add(invitation);
    await _saveAllInvitations(invitations);
  }

  /// Save all invitations
  Future<void> _saveAllInvitations(List<FriendInvitation> invitations) async {
    final invitationsJson = invitations.map((inv) => inv.toJson()).toList();
    await _prefs.setString(_invitationsKey, jsonEncode(invitationsJson));
    _invitationsController.add(invitations);
  }

  /// Save challenge
  Future<void> _saveChallenge(FriendChallenge challenge) async {
    final challenges = await getChallenges();
    challenges.add(challenge);
    await _saveAllChallenges(challenges);
  }

  /// Save all challenges
  Future<void> _saveAllChallenges(List<FriendChallenge> challenges) async {
    final challengesJson = challenges.map((ch) => ch.toJson()).toList();
    await _prefs.setString(_challengesKey, jsonEncode(challengesJson));
    _challengesController.add(challenges);
  }

  /// Save social share
  Future<void> _saveShare(SocialShare share) async {
    final shares = await _getShares();
    shares.add(share);
    
    // Keep only last 100 shares
    if (shares.length > 100) {
      shares.removeRange(0, shares.length - 100);
    }
    
    final sharesJson = shares.map((s) => s.toJson()).toList();
    await _prefs.setString(_socialSharesKey, jsonEncode(sharesJson));
  }

  /// Get all shares
  Future<List<SocialShare>> _getShares() async {
    final data = _prefs.getString(_socialSharesKey);
    if (data == null) return [];

    final sharesJson = jsonDecode(data) as List<dynamic>;
    return sharesJson
        .map((json) => SocialShare.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Evaluate challenge result
  ChallengeStatus _evaluateChallengeResult(ChallengeType type, int score, int targetScore) {
    switch (type) {
      case ChallengeType.beatScore:
        return score > targetScore ? ChallengeStatus.completed : ChallengeStatus.failed;
      case ChallengeType.speedRun:
      case ChallengeType.perfectRun:
      case ChallengeType.coinCollection:
        return score >= targetScore ? ChallengeStatus.completed : ChallengeStatus.failed;
    }
  }

  /// Get challenge type text
  String _getChallengeTypeText(ChallengeType type) {
    switch (type) {
      case ChallengeType.beatScore:
        return 'beat their high score';
      case ChallengeType.speedRun:
        return 'complete a speed run';
      case ChallengeType.perfectRun:
        return 'achieve a perfect run';
      case ChallengeType.coinCollection:
        return 'collect coins';
    }
  }

  /// Generate unique ID
  String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(999999);
    return '${timestamp}_$randomNum';
  }

  /// Dispose resources
  void dispose() {
    _invitationsController.close();
    _challengesController.close();
    _shareController.close();
  }
}