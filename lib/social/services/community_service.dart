/// Community service for managing teams, events, and artwork gallery
library community_service;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/social_models.dart';

/// Service for managing community features
class CommunityService {
  static const String _teamsKey = 'teams';
  static const String _monthlyEventsKey = 'monthly_events';
  static const String _artworkGalleryKey = 'artwork_gallery';
  static const String _communityInteractionsKey = 'community_interactions';
  static const String _playerTeamsKey = 'player_teams';

  final SharedPreferences _prefs;
  final StreamController<List<Team>> _teamsController = StreamController.broadcast();
  final StreamController<List<MonthlyEvent>> _eventsController = StreamController.broadcast();
  final StreamController<List<Artwork>> _artworkController = StreamController.broadcast();

  CommunityService(this._prefs) {
    _initializeCommunityData();
  }

  /// Stream of team updates
  Stream<List<Team>> get teamsStream => _teamsController.stream;

  /// Stream of event updates
  Stream<List<MonthlyEvent>> get eventsStream => _eventsController.stream;

  /// Stream of artwork updates
  Stream<List<Artwork>> get artworkStream => _artworkController.stream;

  /// Initialize community data with sample content
  Future<void> _initializeCommunityData() async {
    await _initializeSampleEvents();
    await _initializeSampleArtwork();
  }

  /// Create a new team
  /// Requirements: 4.5 - Team battle mode implementation
  Future<Team> createTeam({
    required String teamName,
    required String leaderId,
  }) async {
    final team = Team(
      teamId: _generateId(),
      teamName: teamName,
      leaderId: leaderId,
      memberIds: [leaderId],
      createdAt: DateTime.now(),
      status: TeamStatus.active,
    );

    await _saveTeam(team);
    await _addPlayerToTeam(leaderId, team.teamId);
    
    return team;
  }

  /// Join a team
  Future<Team> joinTeam({
    required String teamId,
    required String playerId,
  }) async {
    final teams = await getTeams();
    final teamIndex = teams.indexWhere((t) => t.teamId == teamId);
    
    if (teamIndex == -1) {
      throw Exception('Team not found');
    }

    final team = teams[teamIndex];
    if (team.memberIds.contains(playerId)) {
      throw Exception('Player already in team');
    }

    if (team.memberIds.length >= 5) {
      throw Exception('Team is full');
    }

    final updatedTeam = team.copyWith(
      memberIds: [...team.memberIds, playerId],
    );

    teams[teamIndex] = updatedTeam;
    await _saveAllTeams(teams);
    await _addPlayerToTeam(playerId, teamId);

    return updatedTeam;
  }

  /// Leave a team
  Future<Team> leaveTeam({
    required String teamId,
    required String playerId,
  }) async {
    final teams = await getTeams();
    final teamIndex = teams.indexWhere((t) => t.teamId == teamId);
    
    if (teamIndex == -1) {
      throw Exception('Team not found');
    }

    final team = teams[teamIndex];
    if (!team.memberIds.contains(playerId)) {
      throw Exception('Player not in team');
    }

    final updatedMemberIds = team.memberIds.where((id) => id != playerId).toList();
    
    // If leader leaves and there are other members, assign new leader
    String newLeaderId = team.leaderId;
    if (team.leaderId == playerId && updatedMemberIds.isNotEmpty) {
      newLeaderId = updatedMemberIds.first;
    }

    final updatedTeam = team.copyWith(
      memberIds: updatedMemberIds,
      leaderId: newLeaderId,
      status: updatedMemberIds.isEmpty ? TeamStatus.disbanded : team.status,
    );

    teams[teamIndex] = updatedTeam;
    await _saveAllTeams(teams);
    await _removePlayerFromTeam(playerId, teamId);

    return updatedTeam;
  }

  /// Update team score
  Future<Team> updateTeamScore({
    required String teamId,
    required String playerId,
    required int score,
  }) async {
    final teams = await getTeams();
    final teamIndex = teams.indexWhere((t) => t.teamId == teamId);
    
    if (teamIndex == -1) {
      throw Exception('Team not found');
    }

    final team = teams[teamIndex];
    if (!team.memberIds.contains(playerId)) {
      throw Exception('Player not in team');
    }

    final updatedMemberScores = Map<String, int>.from(team.memberScores);
    updatedMemberScores[playerId] = (updatedMemberScores[playerId] ?? 0) + score;
    
    final totalScore = updatedMemberScores.values.fold(0, (sum, score) => sum + score);

    final updatedTeam = team.copyWith(
      memberScores: updatedMemberScores,
      totalScore: totalScore,
    );

    teams[teamIndex] = updatedTeam;
    await _saveAllTeams(teams);

    return updatedTeam;
  }

  /// Get all teams
  Future<List<Team>> getTeams() async {
    final data = _prefs.getString(_teamsKey);
    if (data == null) return [];

    final teamsJson = jsonDecode(data) as List<dynamic>;
    return teamsJson.map((json) => Team.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get teams for a player
  Future<List<Team>> getPlayerTeams(String playerId) async {
    final teams = await getTeams();
    return teams.where((team) => team.memberIds.contains(playerId)).toList();
  }

  /// Get team leaderboard
  Future<List<Team>> getTeamLeaderboard() async {
    final teams = await getTeams();
    final activeTeams = teams.where((team) => team.status == TeamStatus.active).toList();
    activeTeams.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return activeTeams;
  }

  /// Create monthly event
  /// Requirements: 4.5 - Monthly event implementation
  Future<MonthlyEvent> createMonthlyEvent({
    required String eventName,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required EventType type,
    required Map<String, dynamic> rules,
    required List<EventReward> rewards,
  }) async {
    final event = MonthlyEvent(
      eventId: _generateId(),
      eventName: eventName,
      description: description,
      startDate: startDate,
      endDate: endDate,
      type: type,
      rules: rules,
      rewards: rewards,
      status: EventStatus.upcoming,
    );

    await _saveEvent(event);
    return event;
  }

  /// Get active monthly events
  Future<List<MonthlyEvent>> getActiveEvents() async {
    final events = await getMonthlyEvents();
    return events.where((event) => event.isActive).toList();
  }

  /// Get all monthly events
  Future<List<MonthlyEvent>> getMonthlyEvents() async {
    final data = _prefs.getString(_monthlyEventsKey);
    if (data == null) return [];

    final eventsJson = jsonDecode(data) as List<dynamic>;
    return eventsJson.map((json) => MonthlyEvent.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Submit artwork to gallery
  /// Requirements: 4.6 - Artwork gallery and community features
  Future<Artwork> submitArtwork({
    required String playerId,
    required String playerName,
    required String title,
    String? description,
    required String imageUrl,
    List<String> tags = const [],
  }) async {
    final artwork = Artwork(
      artworkId: _generateId(),
      playerId: playerId,
      playerName: playerName,
      title: title,
      description: description,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      tags: tags,
    );

    await _saveArtwork(artwork);
    return artwork;
  }

  /// Like artwork
  Future<Artwork> likeArtwork({
    required String artworkId,
    required String playerId,
  }) async {
    final artworks = await getArtworkGallery();
    final artworkIndex = artworks.indexWhere((art) => art.artworkId == artworkId);
    
    if (artworkIndex == -1) {
      throw Exception('Artwork not found');
    }

    final artwork = artworks[artworkIndex];
    if (artwork.likedBy.contains(playerId)) {
      throw Exception('Already liked');
    }

    final updatedArtwork = artwork.copyWith(
      likes: artwork.likes + 1,
      likedBy: [...artwork.likedBy, playerId],
    );

    artworks[artworkIndex] = updatedArtwork;
    await _saveAllArtwork(artworks);

    // Record interaction
    await _recordInteraction(
      playerId: playerId,
      targetId: artworkId,
      type: InteractionType.like,
    );

    return updatedArtwork;
  }

  /// Unlike artwork
  Future<Artwork> unlikeArtwork({
    required String artworkId,
    required String playerId,
  }) async {
    final artworks = await getArtworkGallery();
    final artworkIndex = artworks.indexWhere((art) => art.artworkId == artworkId);
    
    if (artworkIndex == -1) {
      throw Exception('Artwork not found');
    }

    final artwork = artworks[artworkIndex];
    if (!artwork.likedBy.contains(playerId)) {
      throw Exception('Not liked');
    }

    final updatedArtwork = artwork.copyWith(
      likes: artwork.likes - 1,
      likedBy: artwork.likedBy.where((id) => id != playerId).toList(),
    );

    artworks[artworkIndex] = updatedArtwork;
    await _saveAllArtwork(artworks);

    return updatedArtwork;
  }

  /// Get artwork gallery
  Future<List<Artwork>> getArtworkGallery({
    ArtworkStatus? status,
    String? playerId,
    List<String>? tags,
  }) async {
    final data = _prefs.getString(_artworkGalleryKey);
    if (data == null) return [];

    final artworksJson = jsonDecode(data) as List<dynamic>;
    var artworks = artworksJson
        .map((json) => Artwork.fromJson(json as Map<String, dynamic>))
        .toList();

    // Apply filters
    if (status != null) {
      artworks = artworks.where((art) => art.status == status).toList();
    }

    if (playerId != null) {
      artworks = artworks.where((art) => art.playerId == playerId).toList();
    }

    if (tags != null && tags.isNotEmpty) {
      artworks = artworks.where((art) => 
        tags.any((tag) => art.tags.contains(tag))
      ).toList();
    }

    // Sort by creation date (newest first)
    artworks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return artworks;
  }

  /// Get featured artwork
  Future<List<Artwork>> getFeaturedArtwork() async {
    return await getArtworkGallery(status: ArtworkStatus.featured);
  }

  /// Get popular artwork (most liked)
  Future<List<Artwork>> getPopularArtwork({int limit = 10}) async {
    final artworks = await getArtworkGallery(status: ArtworkStatus.public);
    artworks.sort((a, b) => b.likes.compareTo(a.likes));
    return artworks.take(limit).toList();
  }

  /// Comment on artwork
  Future<CommunityInteraction> commentOnArtwork({
    required String artworkId,
    required String playerId,
    required String playerName,
    required String comment,
  }) async {
    final interaction = await _recordInteraction(
      playerId: playerId,
      targetId: artworkId,
      type: InteractionType.comment,
      content: comment,
      playerName: playerName,
    );

    return interaction;
  }

  /// Get comments for artwork
  Future<List<CommunityInteraction>> getArtworkComments(String artworkId) async {
    final interactions = await _getCommunityInteractions();
    return interactions.where((interaction) => 
      interaction.targetId == artworkId && interaction.type == InteractionType.comment
    ).toList();
  }

  /// Initialize sample monthly events
  Future<void> _initializeSampleEvents() async {
    final existingEvents = await getMonthlyEvents();
    if (existingEvents.isNotEmpty) return;

    final now = DateTime.now();
    final sampleEvents = [
      MonthlyEvent(
        eventId: _generateId(),
        eventName: 'Team Art Battle',
        description: 'Teams compete to create the most liked artwork',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        type: EventType.artContest,
        rules: {
          'maxTeamSize': 5,
          'submissionsPerTeam': 3,
          'votingPeriod': 7,
        },
        rewards: [
          EventReward(
            rank: 1,
            coinReward: 2000,
            badges: [
              Badge(
                type: BadgeType.monthlyChampion,
                name: 'Art Battle Champion',
                description: 'Won the monthly art battle',
                iconUrl: 'assets/badges/art_champion.png',
                earnedAt: DateTime.now(),
                rarity: 5,
              ),
            ],
            specialItem: 'Golden Brush',
          ),
          EventReward(
            rank: 2,
            coinReward: 1000,
            badges: [],
            specialItem: 'Silver Palette',
          ),
          EventReward(
            rank: 3,
            coinReward: 500,
            badges: [],
            specialItem: 'Bronze Easel',
          ),
        ],
        status: EventStatus.active,
      ),
    ];

    for (final event in sampleEvents) {
      await _saveEvent(event);
    }
  }

  /// Initialize sample artwork
  Future<void> _initializeSampleArtwork() async {
    final existingArtwork = await getArtworkGallery();
    if (existingArtwork.isNotEmpty) return;

    final sampleArtworks = [
      Artwork(
        artworkId: _generateId(),
        playerId: 'artist_1',
        playerName: 'CreativePlayer',
        title: 'Neon Dreams',
        description: 'A vibrant neon-themed drawing',
        imageUrl: 'assets/artwork/neon_dreams.png',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        tags: ['neon', 'colorful', 'abstract'],
        likes: 15,
        likedBy: ['player_1', 'player_2', 'player_3'],
        status: ArtworkStatus.featured,
      ),
      Artwork(
        artworkId: _generateId(),
        playerId: 'artist_2',
        playerName: 'ZenArtist',
        title: 'Peaceful Garden',
        description: 'A serene Japanese garden scene',
        imageUrl: 'assets/artwork/zen_garden.png',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        tags: ['zen', 'nature', 'peaceful'],
        likes: 12,
        likedBy: ['player_4', 'player_5'],
        status: ArtworkStatus.public,
      ),
    ];

    for (final artwork in sampleArtworks) {
      await _saveArtwork(artwork);
    }
  }

  /// Record community interaction
  Future<CommunityInteraction> _recordInteraction({
    required String playerId,
    required String targetId,
    required InteractionType type,
    String? content,
    String? playerName,
  }) async {
    final interaction = CommunityInteraction(
      interactionId: _generateId(),
      playerId: playerId,
      playerName: playerName ?? 'Player',
      targetId: targetId,
      type: type,
      content: content,
      createdAt: DateTime.now(),
    );

    final interactions = await _getCommunityInteractions();
    interactions.add(interaction);
    
    // Keep only last 1000 interactions
    if (interactions.length > 1000) {
      interactions.removeRange(0, interactions.length - 1000);
    }

    final interactionsJson = interactions.map((i) => i.toJson()).toList();
    await _prefs.setString(_communityInteractionsKey, jsonEncode(interactionsJson));

    return interaction;
  }

  /// Get community interactions
  Future<List<CommunityInteraction>> _getCommunityInteractions() async {
    final data = _prefs.getString(_communityInteractionsKey);
    if (data == null) return [];

    final interactionsJson = jsonDecode(data) as List<dynamic>;
    return interactionsJson
        .map((json) => CommunityInteraction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Add player to team mapping
  Future<void> _addPlayerToTeam(String playerId, String teamId) async {
    final playerTeams = await _getPlayerTeams(playerId);
    if (!playerTeams.contains(teamId)) {
      playerTeams.add(teamId);
      await _prefs.setString('${_playerTeamsKey}_$playerId', jsonEncode(playerTeams));
    }
  }

  /// Remove player from team mapping
  Future<void> _removePlayerFromTeam(String playerId, String teamId) async {
    final playerTeams = await _getPlayerTeams(playerId);
    playerTeams.remove(teamId);
    await _prefs.setString('${_playerTeamsKey}_$playerId', jsonEncode(playerTeams));
  }

  /// Get player's teams
  Future<List<String>> _getPlayerTeams(String playerId) async {
    final data = _prefs.getString('${_playerTeamsKey}_$playerId');
    if (data == null) return [];
    return (jsonDecode(data) as List<dynamic>).cast<String>();
  }

  /// Save team
  Future<void> _saveTeam(Team team) async {
    final teams = await getTeams();
    teams.add(team);
    await _saveAllTeams(teams);
  }

  /// Save all teams
  Future<void> _saveAllTeams(List<Team> teams) async {
    final teamsJson = teams.map((team) => team.toJson()).toList();
    await _prefs.setString(_teamsKey, jsonEncode(teamsJson));
    _teamsController.add(teams);
  }

  /// Save event
  Future<void> _saveEvent(MonthlyEvent event) async {
    final events = await getMonthlyEvents();
    events.add(event);
    await _saveAllEvents(events);
  }

  /// Save all events
  Future<void> _saveAllEvents(List<MonthlyEvent> events) async {
    final eventsJson = events.map((event) => event.toJson()).toList();
    await _prefs.setString(_monthlyEventsKey, jsonEncode(eventsJson));
    _eventsController.add(events);
  }

  /// Save artwork
  Future<void> _saveArtwork(Artwork artwork) async {
    final artworks = await getArtworkGallery();
    artworks.add(artwork);
    await _saveAllArtwork(artworks);
  }

  /// Save all artwork
  Future<void> _saveAllArtwork(List<Artwork> artworks) async {
    final artworksJson = artworks.map((artwork) => artwork.toJson()).toList();
    await _prefs.setString(_artworkGalleryKey, jsonEncode(artworksJson));
    _artworkController.add(artworks);
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
    _teamsController.close();
    _eventsController.close();
    _artworkController.close();
  }
}