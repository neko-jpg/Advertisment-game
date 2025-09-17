/// Community manager for team battles, events, and artwork gallery
library community_manager;

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/social_models.dart';
import 'services/community_service.dart';

/// Manager for community and collaboration features
class CommunityManager {
  static CommunityManager? _instance;
  static CommunityManager get instance => _instance!;
  
  late final CommunityService _communityService;
  final StreamController<CommunityUpdate> _updateController = StreamController.broadcast();
  
  /// Stream of community updates
  Stream<CommunityUpdate> get updateStream => _updateController.stream;

  CommunityManager._();

  /// Initialize the community manager
  static Future<void> initialize() async {
    _instance = CommunityManager._();
    final prefs = await SharedPreferences.getInstance();
    _instance!._communityService = CommunityService(prefs);
    
    // Listen to team updates
    _instance!._communityService.teamsStream.listen((teams) {
      _instance!._updateController.add(CommunityUpdate(
        type: CommunityUpdateType.teams,
        teams: teams,
      ));
    });
    
    // Listen to event updates
    _instance!._communityService.eventsStream.listen((events) {
      _instance!._updateController.add(CommunityUpdate(
        type: CommunityUpdateType.events,
        events: events,
      ));
    });
    
    // Listen to artwork updates
    _instance!._communityService.artworkStream.listen((artworks) {
      _instance!._updateController.add(CommunityUpdate(
        type: CommunityUpdateType.artwork,
        artworks: artworks,
      ));
    });
  }

  /// Create a new team
  /// Requirements: 4.5 - Team battle mode implementation
  Future<TeamResult> createTeam({
    required String teamName,
    required String leaderId,
  }) async {
    try {
      final team = await _communityService.createTeam(
        teamName: teamName,
        leaderId: leaderId,
      );

      return TeamResult(
        success: true,
        team: team,
        message: 'Team "$teamName" created successfully!',
      );
    } catch (e) {
      return TeamResult(
        success: false,
        error: 'Failed to create team: $e',
      );
    }
  }

  /// Join a team
  Future<TeamResult> joinTeam({
    required String teamId,
    required String playerId,
  }) async {
    try {
      final team = await _communityService.joinTeam(
        teamId: teamId,
        playerId: playerId,
      );

      return TeamResult(
        success: true,
        team: team,
        message: 'Successfully joined ${team.teamName}!',
      );
    } catch (e) {
      return TeamResult(
        success: false,
        error: 'Failed to join team: $e',
      );
    }
  }

  /// Leave a team
  Future<TeamResult> leaveTeam({
    required String teamId,
    required String playerId,
  }) async {
    try {
      final team = await _communityService.leaveTeam(
        teamId: teamId,
        playerId: playerId,
      );

      return TeamResult(
        success: true,
        team: team,
        message: 'Left the team successfully.',
      );
    } catch (e) {
      return TeamResult(
        success: false,
        error: 'Failed to leave team: $e',
      );
    }
  }

  /// Update team score after gameplay
  Future<TeamResult> updateTeamScore({
    required String teamId,
    required String playerId,
    required int score,
  }) async {
    try {
      final team = await _communityService.updateTeamScore(
        teamId: teamId,
        playerId: playerId,
        score: score,
      );

      return TeamResult(
        success: true,
        team: team,
        message: 'Team score updated! +$score points',
      );
    } catch (e) {
      return TeamResult(
        success: false,
        error: 'Failed to update team score: $e',
      );
    }
  }

  /// Get player's teams
  Future<List<Team>> getPlayerTeams(String playerId) async {
    return await _communityService.getPlayerTeams(playerId);
  }

  /// Get team leaderboard
  Future<List<Team>> getTeamLeaderboard() async {
    return await _communityService.getTeamLeaderboard();
  }

  /// Get all teams
  Future<List<Team>> getAllTeams() async {
    return await _communityService.getTeams();
  }

  /// Get active monthly events
  /// Requirements: 4.5 - Monthly event implementation
  Future<List<MonthlyEvent>> getActiveEvents() async {
    return await _communityService.getActiveEvents();
  }

  /// Get all monthly events
  Future<List<MonthlyEvent>> getAllEvents() async {
    return await _communityService.getMonthlyEvents();
  }

  /// Submit artwork to gallery
  /// Requirements: 4.6 - Artwork gallery and community features
  Future<ArtworkResult> submitArtwork({
    required String playerId,
    required String playerName,
    required String title,
    String? description,
    required String imageUrl,
    List<String> tags = const [],
  }) async {
    try {
      final artwork = await _communityService.submitArtwork(
        playerId: playerId,
        playerName: playerName,
        title: title,
        description: description,
        imageUrl: imageUrl,
        tags: tags,
      );

      return ArtworkResult(
        success: true,
        artwork: artwork,
        message: 'Artwork "$title" submitted to gallery!',
      );
    } catch (e) {
      return ArtworkResult(
        success: false,
        error: 'Failed to submit artwork: $e',
      );
    }
  }

  /// Like artwork
  Future<ArtworkResult> likeArtwork({
    required String artworkId,
    required String playerId,
  }) async {
    try {
      final artwork = await _communityService.likeArtwork(
        artworkId: artworkId,
        playerId: playerId,
      );

      return ArtworkResult(
        success: true,
        artwork: artwork,
        message: 'Artwork liked!',
      );
    } catch (e) {
      return ArtworkResult(
        success: false,
        error: 'Failed to like artwork: $e',
      );
    }
  }

  /// Unlike artwork
  Future<ArtworkResult> unlikeArtwork({
    required String artworkId,
    required String playerId,
  }) async {
    try {
      final artwork = await _communityService.unlikeArtwork(
        artworkId: artworkId,
        playerId: playerId,
      );

      return ArtworkResult(
        success: true,
        artwork: artwork,
        message: 'Artwork unliked.',
      );
    } catch (e) {
      return ArtworkResult(
        success: false,
        error: 'Failed to unlike artwork: $e',
      );
    }
  }

  /// Get artwork gallery
  Future<List<Artwork>> getArtworkGallery({
    ArtworkStatus? status,
    String? playerId,
    List<String>? tags,
  }) async {
    return await _communityService.getArtworkGallery(
      status: status,
      playerId: playerId,
      tags: tags,
    );
  }

  /// Get featured artwork
  Future<List<Artwork>> getFeaturedArtwork() async {
    return await _communityService.getFeaturedArtwork();
  }

  /// Get popular artwork
  Future<List<Artwork>> getPopularArtwork({int limit = 10}) async {
    return await _communityService.getPopularArtwork(limit: limit);
  }

  /// Comment on artwork
  Future<CommentResult> commentOnArtwork({
    required String artworkId,
    required String playerId,
    required String playerName,
    required String comment,
  }) async {
    try {
      final interaction = await _communityService.commentOnArtwork(
        artworkId: artworkId,
        playerId: playerId,
        playerName: playerName,
        comment: comment,
      );

      return CommentResult(
        success: true,
        interaction: interaction,
        message: 'Comment posted!',
      );
    } catch (e) {
      return CommentResult(
        success: false,
        error: 'Failed to post comment: $e',
      );
    }
  }

  /// Get comments for artwork
  Future<List<CommunityInteraction>> getArtworkComments(String artworkId) async {
    return await _communityService.getArtworkComments(artworkId);
  }

  /// Get community summary for player
  Future<CommunitySummary> getCommunitySummary(String playerId) async {
    final playerTeams = await getPlayerTeams(playerId);
    final playerArtwork = await getArtworkGallery(playerId: playerId);
    final activeEvents = await getActiveEvents();
    
    final totalTeamScore = playerTeams.fold(0, (sum, team) => sum + team.totalScore);
    final totalArtworkLikes = playerArtwork.fold(0, (sum, artwork) => sum + artwork.likes);
    
    return CommunitySummary(
      playerId: playerId,
      teamsCount: playerTeams.length,
      artworkCount: playerArtwork.length,
      totalTeamScore: totalTeamScore,
      totalArtworkLikes: totalArtworkLikes,
      activeEventsCount: activeEvents.length,
      featuredArtworkCount: playerArtwork.where((art) => art.status == ArtworkStatus.featured).length,
    );
  }

  /// Dispose resources
  void dispose() {
    _communityService.dispose();
    _updateController.close();
  }
}

/// Result of team operation
class TeamResult {
  final bool success;
  final String? error;
  final String? message;
  final Team? team;

  const TeamResult({
    required this.success,
    this.error,
    this.message,
    this.team,
  });
}

/// Result of artwork operation
class ArtworkResult {
  final bool success;
  final String? error;
  final String? message;
  final Artwork? artwork;

  const ArtworkResult({
    required this.success,
    this.error,
    this.message,
    this.artwork,
  });
}

/// Result of comment operation
class CommentResult {
  final bool success;
  final String? error;
  final String? message;
  final CommunityInteraction? interaction;

  const CommentResult({
    required this.success,
    this.error,
    this.message,
    this.interaction,
  });
}

/// Community summary for player
class CommunitySummary {
  final String playerId;
  final int teamsCount;
  final int artworkCount;
  final int totalTeamScore;
  final int totalArtworkLikes;
  final int activeEventsCount;
  final int featuredArtworkCount;

  const CommunitySummary({
    required this.playerId,
    required this.teamsCount,
    required this.artworkCount,
    required this.totalTeamScore,
    required this.totalArtworkLikes,
    required this.activeEventsCount,
    required this.featuredArtworkCount,
  });
}

/// Community update types
enum CommunityUpdateType {
  teams,
  events,
  artwork,
  interactions,
}

/// Community update notification
class CommunityUpdate {
  final CommunityUpdateType type;
  final List<Team>? teams;
  final List<MonthlyEvent>? events;
  final List<Artwork>? artworks;
  final List<CommunityInteraction>? interactions;

  const CommunityUpdate({
    required this.type,
    this.teams,
    this.events,
    this.artworks,
    this.interactions,
  });
}