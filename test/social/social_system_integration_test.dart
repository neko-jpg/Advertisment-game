/// Integration tests for the complete social system
library social_system_integration_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/social/models/social_models.dart';
import '../lib/social/services/leaderboard_service.dart';
import '../lib/social/services/friend_invitation_service.dart';
import '../lib/social/services/community_service.dart';
import '../lib/social/leaderboard_manager.dart';
import '../lib/social/social_sharing_manager.dart';
import '../lib/social/community_manager.dart';

void main() {
  group('Social System Integration Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
    });

    group('Complete Social Flow', () {
      test('should handle complete social interaction flow', () async {
        // Initialize all managers
        await LeaderboardManager.initialize();
        await SocialSharingManager.initialize();
        await CommunityManager.initialize();

        // 1. Submit scores and check leaderboard
        final scoreResult = await LeaderboardManager.instance.submitScore(
          playerId: 'player_1',
          playerName: 'SocialPlayer1',
          score: 25000,
        );
        expect(scoreResult.success, true);
        expect(scoreResult.globalRank, 1);

        // 2. Send friend invitation
        final invitationResult = await SocialSharingManager.instance.sendFriendInvitation(
          inviterId: 'player_1',
          inviterName: 'SocialPlayer1',
          inviteeIdentifier: 'friend@example.com',
        );
        expect(invitationResult.success, true);
        expect(invitationResult.invitation, isNotNull);

        // 3. Accept invitation (simulate friend joining)
        final acceptResult = await SocialSharingManager.instance.acceptFriendInvitation(
          invitationId: invitationResult.invitation!.invitationId,
          inviteeId: 'player_2',
        );
        expect(acceptResult.success, true);

        // 4. Create team
        final teamResult = await CommunityManager.instance.createTeam(
          teamName: 'Social Warriors',
          leaderId: 'player_1',
        );
        expect(teamResult.success, true);
        expect(teamResult.team!.teamName, 'Social Warriors');

        // 5. Add friend to team
        final joinResult = await CommunityManager.instance.joinTeam(
          teamId: teamResult.team!.teamId,
          playerId: 'player_2',
        );
        expect(joinResult.success, true);

        // 6. Submit artwork
        final artworkResult = await CommunityManager.instance.submitArtwork(
          playerId: 'player_1',
          playerName: 'SocialPlayer1',
          title: 'Team Spirit',
          description: 'Artwork celebrating our team',
          imageUrl: 'assets/team_spirit.png',
          tags: ['team', 'friendship'],
        );
        expect(artworkResult.success, true);

        // 7. Like artwork
        final likeResult = await CommunityManager.instance.likeArtwork(
          artworkId: artworkResult.artwork!.artworkId,
          playerId: 'player_2',
        );
        expect(likeResult.success, true);
        expect(likeResult.artwork!.likes, 1);

        // 8. Send challenge
        final challengeResult = await SocialSharingManager.instance.sendChallenge(
          challengerId: 'player_1',
          challengerName: 'SocialPlayer1',
          challengeeId: 'player_2',
          challengeeName: 'SocialPlayer2',
          type: ChallengeType.beatScore,
          targetScore: 25000,
        );
        expect(challengeResult.success, true);

        // 9. Share high score
        final shareResult = await SocialSharingManager.instance.shareHighScore(
          playerId: 'player_1',
          playerName: 'SocialPlayer1',
          score: 25000,
          rank: 1,
          platforms: ['twitter', 'facebook'],
        );
        expect(shareResult.success, true);

        // Verify final state
        final socialSummary = await SocialSharingManager.instance.getSocialSummary('player_1');
        expect(socialSummary.friendsCount, 1);
        expect(socialSummary.totalChallengesSent, 1);

        final communitySummary = await CommunityManager.instance.getCommunitySummary('player_1');
        expect(communitySummary.teamsCount, 1);
        expect(communitySummary.artworkCount, 1);
      });
    });

    group('Friend Invitation System', () {
      late FriendInvitationService service;

      setUp(() {
        service = FriendInvitationService(prefs);
      });

      tearDown(() {
        service.dispose();
      });

      test('Requirements 4.2: Friend invitation with 500 coins + limited skin', () async {
        // Send invitation
        final invitation = await service.sendInvitation(
          inviterId: 'inviter_1',
          inviterName: 'InviterPlayer',
          inviteeIdentifier: 'invitee@example.com',
        );

        expect(invitation.inviterId, 'inviter_1');
        expect(invitation.inviterName, 'InviterPlayer');
        expect(invitation.inviteeIdentifier, 'invitee@example.com');
        expect(invitation.status, InvitationStatus.pending);
        expect(invitation.reward, isNotNull);
        expect(invitation.reward!.coinReward, 500);
        expect(invitation.reward!.specialSkin, 'Friend Invitation Skin');

        // Accept invitation
        final acceptedInvitation = await service.acceptInvitation(
          invitationId: invitation.invitationId,
          inviteeId: 'invitee_1',
        );

        expect(acceptedInvitation.status, InvitationStatus.accepted);
        expect(acceptedInvitation.inviteeId, 'invitee_1');
        expect(acceptedInvitation.acceptedAt, isNotNull);

        // Verify friends are added
        final inviterFriends = await service.getFriends('inviter_1');
        final inviteeFriends = await service.getFriends('invitee_1');
        
        expect(inviterFriends.contains('invitee_1'), true);
        expect(inviteeFriends.contains('inviter_1'), true);

        // Claim reward
        final reward = await service.claimInvitationReward(invitation.invitationId);
        expect(reward.coinReward, 500);
        expect(reward.specialSkin, 'Friend Invitation Skin');
        expect(reward.claimed, true);
      });

      test('Requirements 4.3: Challenge system implementation', () async {
        // Send challenge
        final challenge = await service.sendChallenge(
          challengerId: 'challenger_1',
          challengerName: 'ChallengerPlayer',
          challengeeId: 'challengee_1',
          challengeeName: 'ChallengeePlayer',
          type: ChallengeType.beatScore,
          targetScore: 15000,
        );

        expect(challenge.challengerId, 'challenger_1');
        expect(challenge.challengeeId, 'challengee_1');
        expect(challenge.type, ChallengeType.beatScore);
        expect(challenge.targetScore, 15000);
        expect(challenge.status, ChallengeStatus.pending);

        // Accept challenge
        final acceptedChallenge = await service.acceptChallenge(challenge.challengeId);
        expect(acceptedChallenge.status, ChallengeStatus.accepted);

        // Complete challenge successfully
        final completedChallenge = await service.completeChallenge(
          challengeId: challenge.challengeId,
          score: 16000,
        );
        expect(completedChallenge.status, ChallengeStatus.completed);
        expect(completedChallenge.challengeeScore, 16000);

        // Test failed challenge
        final failedChallenge = await service.sendChallenge(
          challengerId: 'challenger_1',
          challengerName: 'ChallengerPlayer',
          challengeeId: 'challengee_1',
          challengeeName: 'ChallengeePlayer',
          type: ChallengeType.beatScore,
          targetScore: 20000,
        );

        await service.acceptChallenge(failedChallenge.challengeId);
        final failedResult = await service.completeChallenge(
          challengeId: failedChallenge.challengeId,
          score: 18000,
        );
        expect(failedResult.status, ChallengeStatus.failed);
      });

      test('should generate proper share content', () async {
        // High score share content
        final highScoreContent = service.generateHighScoreShareContent(
          score: 25000,
          rank: 3,
        );
        
        expect(highScoreContent['score'], 25000);
        expect(highScoreContent['rank'], 3);
        expect(highScoreContent['message'], contains('25000 points'));
        expect(highScoreContent['hashtags'], contains('#QuickDrawDash'));

        // Achievement share content
        final badge = Badge(
          type: BadgeType.topPlayer,
          name: 'Champion',
          description: 'Reached the top',
          iconUrl: 'champion.png',
          earnedAt: DateTime.now(),
          rarity: 5,
        );

        final achievementContent = service.generateAchievementShareContent(badge: badge);
        expect(achievementContent['badgeName'], 'Champion');
        expect(achievementContent['rarity'], 5);
        expect(achievementContent['message'], contains('Champion'));

        // Challenge share content
        final challengeContent = service.generateChallengeShareContent(
          challengerName: 'TestPlayer',
          targetScore: 15000,
          type: ChallengeType.speedRun,
        );
        
        expect(challengeContent['challengerName'], 'TestPlayer');
        expect(challengeContent['targetScore'], 15000);
        expect(challengeContent['message'], contains('TestPlayer'));
      });
    });

    group('Community System', () {
      late CommunityService service;

      setUp(() {
        service = CommunityService(prefs);
      });

      tearDown(() {
        service.dispose();
      });

      test('Requirements 4.5: Team battle mode and monthly events', () async {
        // Create team
        final team = await service.createTeam(
          teamName: 'Battle Warriors',
          leaderId: 'leader_1',
        );

        expect(team.teamName, 'Battle Warriors');
        expect(team.leaderId, 'leader_1');
        expect(team.memberIds, contains('leader_1'));
        expect(team.status, TeamStatus.active);

        // Add members
        final updatedTeam = await service.joinTeam(
          teamId: team.teamId,
          playerId: 'member_1',
        );
        expect(updatedTeam.memberIds.length, 2);
        expect(updatedTeam.memberIds, contains('member_1'));

        // Update team scores
        final scoredTeam = await service.updateTeamScore(
          teamId: team.teamId,
          playerId: 'leader_1',
          score: 5000,
        );
        expect(scoredTeam.totalScore, 5000);
        expect(scoredTeam.memberScores['leader_1'], 5000);

        await service.updateTeamScore(
          teamId: team.teamId,
          playerId: 'member_1',
          score: 3000,
        );

        final finalTeam = await service.getTeams();
        final updatedFinalTeam = finalTeam.first;
        expect(updatedFinalTeam.totalScore, 8000);

        // Test team leaderboard
        final leaderboard = await service.getTeamLeaderboard();
        expect(leaderboard.isNotEmpty, true);
        expect(leaderboard.first.totalScore, 8000);

        // Test monthly events (should be initialized with sample data)
        final events = await service.getMonthlyEvents();
        expect(events.isNotEmpty, true);
        
        final activeEvents = await service.getActiveEvents();
        // Note: Active events depend on current date vs sample event dates
      });

      test('Requirements 4.6: Artwork gallery and community features', () async {
        // Submit artwork
        final artwork = await service.submitArtwork(
          playerId: 'artist_1',
          playerName: 'ArtistPlayer',
          title: 'Digital Masterpiece',
          description: 'A beautiful digital creation',
          imageUrl: 'masterpiece.png',
          tags: ['digital', 'colorful'],
        );

        expect(artwork.playerId, 'artist_1');
        expect(artwork.playerName, 'ArtistPlayer');
        expect(artwork.title, 'Digital Masterpiece');
        expect(artwork.tags, contains('digital'));
        expect(artwork.status, ArtworkStatus.public);

        // Like artwork
        final likedArtwork = await service.likeArtwork(
          artworkId: artwork.artworkId,
          playerId: 'liker_1',
        );
        expect(likedArtwork.likes, 1);
        expect(likedArtwork.likedBy, contains('liker_1'));

        // Test double like prevention
        expect(
          () => service.likeArtwork(
            artworkId: artwork.artworkId,
            playerId: 'liker_1',
          ),
          throwsException,
        );

        // Unlike artwork
        final unlikedArtwork = await service.unlikeArtwork(
          artworkId: artwork.artworkId,
          playerId: 'liker_1',
        );
        expect(unlikedArtwork.likes, 0);
        expect(unlikedArtwork.likedBy, isEmpty);

        // Comment on artwork
        final comment = await service.commentOnArtwork(
          artworkId: artwork.artworkId,
          playerId: 'commenter_1',
          playerName: 'CommenterPlayer',
          comment: 'Amazing artwork!',
        );
        expect(comment.type, InteractionType.comment);
        expect(comment.content, 'Amazing artwork!');

        // Get comments
        final comments = await service.getArtworkComments(artwork.artworkId);
        expect(comments.length, 1);
        expect(comments.first.content, 'Amazing artwork!');

        // Test gallery filtering
        final publicArtwork = await service.getArtworkGallery(status: ArtworkStatus.public);
        expect(publicArtwork.isNotEmpty, true);

        final playerArtwork = await service.getArtworkGallery(playerId: 'artist_1');
        expect(playerArtwork.length, 1);
        expect(playerArtwork.first.playerId, 'artist_1');

        final taggedArtwork = await service.getArtworkGallery(tags: ['digital']);
        expect(taggedArtwork.isNotEmpty, true);
      });

      test('should handle team member management correctly', () async {
        // Create team
        final team = await service.createTeam(
          teamName: 'Management Test',
          leaderId: 'leader_1',
        );

        // Add multiple members
        await service.joinTeam(teamId: team.teamId, playerId: 'member_1');
        await service.joinTeam(teamId: team.teamId, playerId: 'member_2');
        await service.joinTeam(teamId: team.teamId, playerId: 'member_3');

        var updatedTeam = await service.getTeams();
        expect(updatedTeam.first.memberIds.length, 4);

        // Test team full (max 5 members)
        await service.joinTeam(teamId: team.teamId, playerId: 'member_4');
        
        expect(
          () => service.joinTeam(teamId: team.teamId, playerId: 'member_5'),
          throwsException,
        );

        // Test leader leaving (should assign new leader)
        final leaderLeftTeam = await service.leaveTeam(
          teamId: team.teamId,
          playerId: 'leader_1',
        );
        expect(leaderLeftTeam.leaderId, isNot('leader_1'));
        expect(leaderLeftTeam.memberIds, isNot(contains('leader_1')));

        // Test last member leaving (should disband team)
        await service.leaveTeam(teamId: team.teamId, playerId: 'member_1');
        await service.leaveTeam(teamId: team.teamId, playerId: 'member_2');
        await service.leaveTeam(teamId: team.teamId, playerId: 'member_3');
        
        final disbandedTeam = await service.leaveTeam(
          teamId: team.teamId,
          playerId: 'member_4',
        );
        expect(disbandedTeam.status, TeamStatus.disbanded);
        expect(disbandedTeam.memberIds, isEmpty);
      });
    });

    group('Requirements Verification', () {
      test('Requirement 4.1: Global leaderboard with friend rankings', () async {
        await LeaderboardManager.initialize();
        
        // Submit scores for multiple players
        await LeaderboardManager.instance.submitScore(
          playerId: 'player_1',
          playerName: 'Player1',
          score: 20000,
        );
        
        await LeaderboardManager.instance.submitScore(
          playerId: 'player_2',
          playerName: 'Player2',
          score: 15000,
        );

        // Get global leaderboard
        final globalLeaderboard = await LeaderboardManager.instance.getLeaderboard(LeaderboardType.global);
        expect(globalLeaderboard, isNotNull);
        expect(globalLeaderboard!.entries.length, greaterThanOrEqualTo(2));
        
        // Verify ranking order
        expect(globalLeaderboard.entries.first.score, greaterThanOrEqualTo(globalLeaderboard.entries.last.score));
      });

      test('Requirement 4.2: Friend invitation system with rewards', () async {
        await SocialSharingManager.initialize();
        
        final result = await SocialSharingManager.instance.sendFriendInvitation(
          inviterId: 'inviter',
          inviterName: 'InviterName',
          inviteeIdentifier: 'invitee@test.com',
        );
        
        expect(result.success, true);
        expect(result.invitation!.reward!.coinReward, 500);
        expect(result.invitation!.reward!.specialSkin, isNotNull);
      });

      test('Requirement 4.3: Challenge sending and receiving', () async {
        await SocialSharingManager.initialize();
        
        final result = await SocialSharingManager.instance.sendChallenge(
          challengerId: 'challenger',
          challengerName: 'ChallengerName',
          challengeeId: 'challengee',
          challengeeName: 'ChallengeeName',
          type: ChallengeType.beatScore,
          targetScore: 10000,
        );
        
        expect(result.success, true);
        expect(result.challenge!.type, ChallengeType.beatScore);
        expect(result.challenge!.targetScore, 10000);
      });

      test('Requirement 4.4: Badge system for achievements', () async {
        await LeaderboardManager.initialize();
        
        // Submit high score to earn badge
        final result = await LeaderboardManager.instance.submitScore(
          playerId: 'badge_player',
          playerName: 'BadgePlayer',
          score: 50000,
        );
        
        expect(result.success, true);
        expect(result.newBadges.isNotEmpty, true);
        
        final badges = await LeaderboardManager.instance.getPlayerBadges('badge_player');
        expect(badges.isNotEmpty, true);
      });

      test('Requirement 4.5: Team battle mode and monthly events', () async {
        await CommunityManager.initialize();
        
        // Create team
        final teamResult = await CommunityManager.instance.createTeam(
          teamName: 'Battle Team',
          leaderId: 'leader',
        );
        expect(teamResult.success, true);
        
        // Check monthly events
        final events = await CommunityManager.instance.getAllEvents();
        expect(events.isNotEmpty, true);
      });

      test('Requirement 4.6: Artwork gallery and community features', () async {
        await CommunityManager.initialize();
        
        // Submit artwork
        final artworkResult = await CommunityManager.instance.submitArtwork(
          playerId: 'artist',
          playerName: 'ArtistName',
          title: 'Test Art',
          imageUrl: 'test.png',
        );
        expect(artworkResult.success, true);
        
        // Like artwork
        final likeResult = await CommunityManager.instance.likeArtwork(
          artworkId: artworkResult.artwork!.artworkId,
          playerId: 'liker',
        );
        expect(likeResult.success, true);
        expect(likeResult.artwork!.likes, 1);
      });
    });
  });
}