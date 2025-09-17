/// Social feature data models for Quick Draw Dash
library social_models;

import 'package:equatable/equatable.dart';

/// Represents a player's leaderboard entry
class LeaderboardEntry extends Equatable {
  final String playerId;
  final String playerName;
  final int score;
  final int rank;
  final DateTime achievedAt;
  final String? avatarUrl;
  final bool isFriend;

  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.score,
    required this.rank,
    required this.achievedAt,
    this.avatarUrl,
    this.isFriend = false,
  });

  @override
  List<Object?> get props => [
        playerId,
        playerName,
        score,
        rank,
        achievedAt,
        avatarUrl,
        isFriend,
      ];

  LeaderboardEntry copyWith({
    String? playerId,
    String? playerName,
    int? score,
    int? rank,
    DateTime? achievedAt,
    String? avatarUrl,
    bool? isFriend,
  }) {
    return LeaderboardEntry(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      score: score ?? this.score,
      rank: rank ?? this.rank,
      achievedAt: achievedAt ?? this.achievedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isFriend: isFriend ?? this.isFriend,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'score': score,
      'rank': rank,
      'achievedAt': achievedAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'isFriend': isFriend,
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      score: json['score'] as int,
      rank: json['rank'] as int,
      achievedAt: DateTime.parse(json['achievedAt'] as String),
      avatarUrl: json['avatarUrl'] as String?,
      isFriend: json['isFriend'] as bool? ?? false,
    );
  }
}

/// Leaderboard types for different time periods
enum LeaderboardType {
  global,
  friends,
  weekly,
  monthly,
  allTime,
}

/// Represents a complete leaderboard
class Leaderboard extends Equatable {
  final LeaderboardType type;
  final List<LeaderboardEntry> entries;
  final DateTime lastUpdated;
  final int totalPlayers;
  final LeaderboardEntry? currentPlayerEntry;

  const Leaderboard({
    required this.type,
    required this.entries,
    required this.lastUpdated,
    required this.totalPlayers,
    this.currentPlayerEntry,
  });

  @override
  List<Object?> get props => [
        type,
        entries,
        lastUpdated,
        totalPlayers,
        currentPlayerEntry,
      ];

  Leaderboard copyWith({
    LeaderboardType? type,
    List<LeaderboardEntry>? entries,
    DateTime? lastUpdated,
    int? totalPlayers,
    LeaderboardEntry? currentPlayerEntry,
  }) {
    return Leaderboard(
      type: type ?? this.type,
      entries: entries ?? this.entries,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      currentPlayerEntry: currentPlayerEntry ?? this.currentPlayerEntry,
    );
  }
}

/// Achievement badge types
enum BadgeType {
  topPlayer,
  weeklyChampion,
  monthlyChampion,
  streakMaster,
  socialButterfly,
  challenger,
  mentor,
}

/// Represents an achievement badge
class Badge extends Equatable {
  final BadgeType type;
  final String name;
  final String description;
  final String iconUrl;
  final DateTime earnedAt;
  final int rarity; // 1-5, 5 being rarest

  const Badge({
    required this.type,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.earnedAt,
    required this.rarity,
  });

  @override
  List<Object> get props => [type, name, description, iconUrl, earnedAt, rarity];

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'earnedAt': earnedAt.toIso8601String(),
      'rarity': rarity,
    };
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      type: BadgeType.values.firstWhere((e) => e.name == json['type']),
      name: json['name'] as String,
      description: json['description'] as String,
      iconUrl: json['iconUrl'] as String,
      earnedAt: DateTime.parse(json['earnedAt'] as String),
      rarity: json['rarity'] as int,
    );
  }
}

/// Leaderboard reward for ranking achievements
class LeaderboardReward extends Equatable {
  final int minRank;
  final int maxRank;
  final int coinReward;
  final List<Badge> badges;
  final String? specialItem;

  const LeaderboardReward({
    required this.minRank,
    required this.maxRank,
    required this.coinReward,
    required this.badges,
    this.specialItem,
  });

  @override
  List<Object?> get props => [minRank, maxRank, coinReward, badges, specialItem];

  bool isEligible(int rank) {
    return rank >= minRank && rank <= maxRank;
  }
}

/// Friend invitation data
class FriendInvitation extends Equatable {
  final String invitationId;
  final String inviterId;
  final String inviterName;
  final String? inviteeId;
  final String inviteeIdentifier; // Email, phone, or social media handle
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final InvitationReward? reward;

  const FriendInvitation({
    required this.invitationId,
    required this.inviterId,
    required this.inviterName,
    this.inviteeId,
    required this.inviteeIdentifier,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.reward,
  });

  @override
  List<Object?> get props => [
        invitationId,
        inviterId,
        inviterName,
        inviteeId,
        inviteeIdentifier,
        status,
        createdAt,
        acceptedAt,
        reward,
      ];

  FriendInvitation copyWith({
    String? invitationId,
    String? inviterId,
    String? inviterName,
    String? inviteeId,
    String? inviteeIdentifier,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    InvitationReward? reward,
  }) {
    return FriendInvitation(
      invitationId: invitationId ?? this.invitationId,
      inviterId: inviterId ?? this.inviterId,
      inviterName: inviterName ?? this.inviterName,
      inviteeId: inviteeId ?? this.inviteeId,
      inviteeIdentifier: inviteeIdentifier ?? this.inviteeIdentifier,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      reward: reward ?? this.reward,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invitationId': invitationId,
      'inviterId': inviterId,
      'inviterName': inviterName,
      'inviteeId': inviteeId,
      'inviteeIdentifier': inviteeIdentifier,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'reward': reward?.toJson(),
    };
  }

  factory FriendInvitation.fromJson(Map<String, dynamic> json) {
    return FriendInvitation(
      invitationId: json['invitationId'] as String,
      inviterId: json['inviterId'] as String,
      inviterName: json['inviterName'] as String,
      inviteeId: json['inviteeId'] as String?,
      inviteeIdentifier: json['inviteeIdentifier'] as String,
      status: InvitationStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt'] as String) : null,
      reward: json['reward'] != null ? InvitationReward.fromJson(json['reward'] as Map<String, dynamic>) : null,
    );
  }
}

/// Status of friend invitation
enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
}

/// Reward for friend invitation
class InvitationReward extends Equatable {
  final int coinReward;
  final String? specialSkin;
  final List<Badge> badges;
  final bool claimed;

  const InvitationReward({
    required this.coinReward,
    this.specialSkin,
    this.badges = const [],
    this.claimed = false,
  });

  @override
  List<Object?> get props => [coinReward, specialSkin, badges, claimed];

  InvitationReward copyWith({
    int? coinReward,
    String? specialSkin,
    List<Badge>? badges,
    bool? claimed,
  }) {
    return InvitationReward(
      coinReward: coinReward ?? this.coinReward,
      specialSkin: specialSkin ?? this.specialSkin,
      badges: badges ?? this.badges,
      claimed: claimed ?? this.claimed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coinReward': coinReward,
      'specialSkin': specialSkin,
      'badges': badges.map((b) => b.toJson()).toList(),
      'claimed': claimed,
    };
  }

  factory InvitationReward.fromJson(Map<String, dynamic> json) {
    return InvitationReward(
      coinReward: json['coinReward'] as int,
      specialSkin: json['specialSkin'] as String?,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((b) => Badge.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      claimed: json['claimed'] as bool? ?? false,
    );
  }
}

/// Challenge sent between friends
class FriendChallenge extends Equatable {
  final String challengeId;
  final String challengerId;
  final String challengerName;
  final String challengeeId;
  final String challengeeName;
  final ChallengeType type;
  final int targetScore;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? challengeeScore;

  const FriendChallenge({
    required this.challengeId,
    required this.challengerId,
    required this.challengerName,
    required this.challengeeId,
    required this.challengeeName,
    required this.type,
    required this.targetScore,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.challengeeScore,
  });

  @override
  List<Object?> get props => [
        challengeId,
        challengerId,
        challengerName,
        challengeeId,
        challengeeName,
        type,
        targetScore,
        status,
        createdAt,
        completedAt,
        challengeeScore,
      ];

  FriendChallenge copyWith({
    String? challengeId,
    String? challengerId,
    String? challengerName,
    String? challengeeId,
    String? challengeeName,
    ChallengeType? type,
    int? targetScore,
    ChallengeStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    int? challengeeScore,
  }) {
    return FriendChallenge(
      challengeId: challengeId ?? this.challengeId,
      challengerId: challengerId ?? this.challengerId,
      challengerName: challengerName ?? this.challengerName,
      challengeeId: challengeeId ?? this.challengeeId,
      challengeeName: challengeeName ?? this.challengeeName,
      type: type ?? this.type,
      targetScore: targetScore ?? this.targetScore,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      challengeeScore: challengeeScore ?? this.challengeeScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challengeId': challengeId,
      'challengerId': challengerId,
      'challengerName': challengerName,
      'challengeeId': challengeeId,
      'challengeeName': challengeeName,
      'type': type.name,
      'targetScore': targetScore,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'challengeeScore': challengeeScore,
    };
  }

  factory FriendChallenge.fromJson(Map<String, dynamic> json) {
    return FriendChallenge(
      challengeId: json['challengeId'] as String,
      challengerId: json['challengerId'] as String,
      challengerName: json['challengerName'] as String,
      challengeeId: json['challengeeId'] as String,
      challengeeName: json['challengeeName'] as String,
      type: ChallengeType.values.firstWhere((e) => e.name == json['type']),
      targetScore: json['targetScore'] as int,
      status: ChallengeStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      challengeeScore: json['challengeeScore'] as int?,
    );
  }
}

/// Types of challenges
enum ChallengeType {
  beatScore,
  speedRun,
  perfectRun,
  coinCollection,
}

/// Status of friend challenge
enum ChallengeStatus {
  pending,
  accepted,
  completed,
  failed,
  expired,
}

/// Social sharing content
class SocialShare extends Equatable {
  final String shareId;
  final String playerId;
  final String playerName;
  final ShareType type;
  final Map<String, dynamic> content;
  final DateTime createdAt;
  final List<String> platforms;

  const SocialShare({
    required this.shareId,
    required this.playerId,
    required this.playerName,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.platforms,
  });

  @override
  List<Object> get props => [shareId, playerId, playerName, type, content, createdAt, platforms];

  Map<String, dynamic> toJson() {
    return {
      'shareId': shareId,
      'playerId': playerId,
      'playerName': playerName,
      'type': type.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'platforms': platforms,
    };
  }

  factory SocialShare.fromJson(Map<String, dynamic> json) {
    return SocialShare(
      shareId: json['shareId'] as String,
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      type: ShareType.values.firstWhere((e) => e.name == json['type']),
      content: json['content'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      platforms: (json['platforms'] as List<dynamic>).cast<String>(),
    );
  }
}

/// Types of social sharing content
enum ShareType {
  highScore,
  achievement,
  challenge,
  artwork,
  milestone,
}

/// Team for collaborative gameplay
class Team extends Equatable {
  final String teamId;
  final String teamName;
  final String leaderId;
  final List<String> memberIds;
  final DateTime createdAt;
  final TeamStatus status;
  final int totalScore;
  final Map<String, int> memberScores;

  const Team({
    required this.teamId,
    required this.teamName,
    required this.leaderId,
    required this.memberIds,
    required this.createdAt,
    required this.status,
    this.totalScore = 0,
    this.memberScores = const {},
  });

  @override
  List<Object> get props => [
        teamId,
        teamName,
        leaderId,
        memberIds,
        createdAt,
        status,
        totalScore,
        memberScores,
      ];

  Team copyWith({
    String? teamId,
    String? teamName,
    String? leaderId,
    List<String>? memberIds,
    DateTime? createdAt,
    TeamStatus? status,
    int? totalScore,
    Map<String, int>? memberScores,
  }) {
    return Team(
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      leaderId: leaderId ?? this.leaderId,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      totalScore: totalScore ?? this.totalScore,
      memberScores: memberScores ?? this.memberScores,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'leaderId': leaderId,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'totalScore': totalScore,
      'memberScores': memberScores,
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId: json['teamId'] as String,
      teamName: json['teamName'] as String,
      leaderId: json['leaderId'] as String,
      memberIds: (json['memberIds'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: TeamStatus.values.firstWhere((e) => e.name == json['status']),
      totalScore: json['totalScore'] as int? ?? 0,
      memberScores: Map<String, int>.from(json['memberScores'] as Map? ?? {}),
    );
  }
}

/// Team status
enum TeamStatus {
  active,
  inactive,
  disbanded,
}

/// Monthly team event
class MonthlyEvent extends Equatable {
  final String eventId;
  final String eventName;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final EventType type;
  final Map<String, dynamic> rules;
  final List<EventReward> rewards;
  final EventStatus status;

  const MonthlyEvent({
    required this.eventId,
    required this.eventName,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.rules,
    required this.rewards,
    required this.status,
  });

  @override
  List<Object> get props => [
        eventId,
        eventName,
        description,
        startDate,
        endDate,
        type,
        rules,
        rewards,
        status,
      ];

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate) && status == EventStatus.active;
  }

  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'eventName': eventName,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'type': type.name,
      'rules': rules,
      'rewards': rewards.map((r) => r.toJson()).toList(),
      'status': status.name,
    };
  }

  factory MonthlyEvent.fromJson(Map<String, dynamic> json) {
    return MonthlyEvent(
      eventId: json['eventId'] as String,
      eventName: json['eventName'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      rules: json['rules'] as Map<String, dynamic>,
      rewards: (json['rewards'] as List<dynamic>)
          .map((r) => EventReward.fromJson(r as Map<String, dynamic>))
          .toList(),
      status: EventStatus.values.firstWhere((e) => e.name == json['status']),
    );
  }
}

/// Event types
enum EventType {
  teamBattle,
  artContest,
  speedChallenge,
  collectathon,
}

/// Event status
enum EventStatus {
  upcoming,
  active,
  ended,
  cancelled,
}

/// Event reward
class EventReward extends Equatable {
  final int rank;
  final int coinReward;
  final List<Badge> badges;
  final String? specialItem;

  const EventReward({
    required this.rank,
    required this.coinReward,
    required this.badges,
    this.specialItem,
  });

  @override
  List<Object?> get props => [rank, coinReward, badges, specialItem];

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'coinReward': coinReward,
      'badges': badges.map((b) => b.toJson()).toList(),
      'specialItem': specialItem,
    };
  }

  factory EventReward.fromJson(Map<String, dynamic> json) {
    return EventReward(
      rank: json['rank'] as int,
      coinReward: json['coinReward'] as int,
      badges: (json['badges'] as List<dynamic>)
          .map((b) => Badge.fromJson(b as Map<String, dynamic>))
          .toList(),
      specialItem: json['specialItem'] as String?,
    );
  }
}

/// Artwork created by players
class Artwork extends Equatable {
  final String artworkId;
  final String playerId;
  final String playerName;
  final String title;
  final String? description;
  final String imageUrl;
  final DateTime createdAt;
  final List<String> tags;
  final int likes;
  final List<String> likedBy;
  final ArtworkStatus status;

  const Artwork({
    required this.artworkId,
    required this.playerId,
    required this.playerName,
    required this.title,
    this.description,
    required this.imageUrl,
    required this.createdAt,
    this.tags = const [],
    this.likes = 0,
    this.likedBy = const [],
    this.status = ArtworkStatus.public,
  });

  @override
  List<Object?> get props => [
        artworkId,
        playerId,
        playerName,
        title,
        description,
        imageUrl,
        createdAt,
        tags,
        likes,
        likedBy,
        status,
      ];

  Artwork copyWith({
    String? artworkId,
    String? playerId,
    String? playerName,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    List<String>? tags,
    int? likes,
    List<String>? likedBy,
    ArtworkStatus? status,
  }) {
    return Artwork(
      artworkId: artworkId ?? this.artworkId,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'artworkId': artworkId,
      'playerId': playerId,
      'playerName': playerName,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'tags': tags,
      'likes': likes,
      'likedBy': likedBy,
      'status': status.name,
    };
  }

  factory Artwork.fromJson(Map<String, dynamic> json) {
    return Artwork(
      artworkId: json['artworkId'] as String,
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      likes: json['likes'] as int? ?? 0,
      likedBy: (json['likedBy'] as List<dynamic>?)?.cast<String>() ?? [],
      status: ArtworkStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ArtworkStatus.public,
      ),
    );
  }
}

/// Artwork status
enum ArtworkStatus {
  public,
  private,
  featured,
  reported,
}

/// Community interaction (comment, like, etc.)
class CommunityInteraction extends Equatable {
  final String interactionId;
  final String playerId;
  final String playerName;
  final String targetId; // artwork, post, etc.
  final InteractionType type;
  final String? content;
  final DateTime createdAt;

  const CommunityInteraction({
    required this.interactionId,
    required this.playerId,
    required this.playerName,
    required this.targetId,
    required this.type,
    this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        interactionId,
        playerId,
        playerName,
        targetId,
        type,
        content,
        createdAt,
      ];

  Map<String, dynamic> toJson() {
    return {
      'interactionId': interactionId,
      'playerId': playerId,
      'playerName': playerName,
      'targetId': targetId,
      'type': type.name,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CommunityInteraction.fromJson(Map<String, dynamic> json) {
    return CommunityInteraction(
      interactionId: json['interactionId'] as String,
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      targetId: json['targetId'] as String,
      type: InteractionType.values.firstWhere((e) => e.name == json['type']),
      content: json['content'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Types of community interactions
enum InteractionType {
  like,
  comment,
  share,
  report,
}