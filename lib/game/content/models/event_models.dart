import 'dart:convert';
import '../../models/game_models.dart' as game_models;

/// Types of events available in the game
enum EventType {
  weekendDoubleCoins,
  speedChallenge,
  dailyMission,
  specialChallenge;

  String get displayName {
    switch (this) {
      case EventType.weekendDoubleCoins:
        return 'Weekend Double Coins';
      case EventType.speedChallenge:
        return 'Speed Challenge';
      case EventType.dailyMission:
        return 'Daily Mission';
      case EventType.specialChallenge:
        return 'Special Challenge';
    }
  }

  String get description {
    switch (this) {
      case EventType.weekendDoubleCoins:
        return 'Earn double coins during weekend play sessions';
      case EventType.speedChallenge:
        return 'Complete levels as fast as possible for bonus rewards';
      case EventType.dailyMission:
        return 'Complete daily objectives for special rewards';
      case EventType.specialChallenge:
        return 'Unique challenge modes with exclusive rewards';
    }
  }
}

/// Challenge difficulty levels
enum ChallengeDifficulty {
  easy,
  medium,
  hard,
  expert;

  String get displayName {
    switch (this) {
      case ChallengeDifficulty.easy:
        return 'Easy';
      case ChallengeDifficulty.medium:
        return 'Medium';
      case ChallengeDifficulty.hard:
        return 'Hard';
      case ChallengeDifficulty.expert:
        return 'Expert';
    }
  }

  /// Reward multiplier for this difficulty
  double get rewardMultiplier {
    switch (this) {
      case ChallengeDifficulty.easy:
        return 1.0;
      case ChallengeDifficulty.medium:
        return 1.5;
      case ChallengeDifficulty.hard:
        return 2.0;
      case ChallengeDifficulty.expert:
        return 3.0;
    }
  }
}

/// Game event with time-based activation
class GameEvent {
  GameEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.rewards,
    this.isActive = false,
    this.progress = 0.0,
    this.completed = false,
    this.claimed = false,
    this.metadata = const {},
  });

  final String id;
  final EventType type;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, int> rewards; // reward type -> amount
  bool isActive;
  double progress; // 0.0 to 1.0
  bool completed;
  bool claimed;
  final Map<String, dynamic> metadata;

  /// Check if event is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime) && isActive;
  }

  /// Check if event has expired
  bool get isExpired {
    return DateTime.now().isAfter(endTime);
  }

  /// Time remaining for the event
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(endTime)) return Duration.zero;
    return endTime.difference(now);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'rewards': rewards,
      'isActive': isActive,
      'progress': progress,
      'completed': completed,
      'claimed': claimed,
      'metadata': metadata,
    };
  }

  static GameEvent fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      type: EventType.values[json['type'] as int],
      title: json['title'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      rewards: Map<String, int>.from(json['rewards'] as Map),
      isActive: json['isActive'] as bool? ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as bool? ?? false,
      claimed: json['claimed'] as bool? ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// Challenge with specific objectives
class Challenge {
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.objectives,
    required this.rewards,
    this.isUnlocked = false,
    Map<String, double>? progress,
    this.completed = false,
    this.claimed = false,
    this.attempts = 0,
    this.bestScore = 0,
  }) : progress = progress ?? {};

  final String id;
  final String title;
  final String description;
  final ChallengeDifficulty difficulty;
  final List<ChallengeObjective> objectives;
  final Map<String, int> rewards;
  bool isUnlocked;
  final Map<String, double> progress; // objective id -> progress (0.0 to 1.0)
  bool completed;
  bool claimed;
  int attempts;
  int bestScore;

  /// Check if all objectives are completed
  bool get allObjectivesCompleted {
    return objectives.every((objective) => 
        (progress[objective.id] ?? 0.0) >= 1.0);
  }

  /// Get overall progress (0.0 to 1.0)
  double get overallProgress {
    if (objectives.isEmpty) return 0.0;
    final totalProgress = objectives.fold<double>(0.0, 
        (sum, objective) => sum + (progress[objective.id] ?? 0.0));
    return totalProgress / objectives.length;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty.index,
      'objectives': objectives.map((o) => o.toJson()).toList(),
      'rewards': rewards,
      'isUnlocked': isUnlocked,
      'progress': progress,
      'completed': completed,
      'claimed': claimed,
      'attempts': attempts,
      'bestScore': bestScore,
    };
  }

  static Challenge fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      difficulty: ChallengeDifficulty.values[json['difficulty'] as int],
      objectives: (json['objectives'] as List<dynamic>)
          .map((o) => ChallengeObjective.fromJson(o as Map<String, dynamic>))
          .toList(),
      rewards: Map<String, int>.from(json['rewards'] as Map),
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      progress: Map<String, double>.from(json['progress'] as Map? ?? {}),
      completed: json['completed'] as bool? ?? false,
      claimed: json['claimed'] as bool? ?? false,
      attempts: json['attempts'] as int? ?? 0,
      bestScore: json['bestScore'] as int? ?? 0,
    );
  }
}

/// Individual objective within a challenge
class ChallengeObjective {
  ChallengeObjective({
    required this.id,
    required this.description,
    required this.target,
    this.currentValue = 0,
  });

  final String id;
  final String description;
  final int target;
  int currentValue;

  /// Progress towards completion (0.0 to 1.0)
  double get progress => (currentValue / target).clamp(0.0, 1.0);

  /// Whether this objective is completed
  bool get isCompleted => currentValue >= target;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'target': target,
      'currentValue': currentValue,
    };
  }

  static ChallengeObjective fromJson(Map<String, dynamic> json) {
    return ChallengeObjective(
      id: json['id'] as String,
      description: json['description'] as String,
      target: json['target'] as int,
      currentValue: json['currentValue'] as int? ?? 0,
    );
  }
}

/// Daily mission system
class DailyMissionSystem {
  DailyMissionSystem({
    this.missions = const [],
    this.lastRefreshDate,
    this.streak = 0,
    this.totalCompleted = 0,
  });

  final List<game_models.DailyMission> missions;
  DateTime? lastRefreshDate;
  int streak;
  int totalCompleted;

  /// Check if missions need to be refreshed
  bool get needsRefresh {
    if (lastRefreshDate == null) return true;
    final now = DateTime.now();
    final lastRefresh = lastRefreshDate!;
    return now.day != lastRefresh.day || 
           now.month != lastRefresh.month || 
           now.year != lastRefresh.year;
  }

  /// Get active missions for today
  List<game_models.DailyMission> get activeMissions {
    return missions.where((mission) => !mission.completed).toList();
  }

  /// Get completed missions for today
  List<game_models.DailyMission> get completedMissions {
    return missions.where((mission) => mission.completed).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'missions': missions.map((m) => m.toJson()).toList(),
      'lastRefreshDate': lastRefreshDate?.toIso8601String(),
      'streak': streak,
      'totalCompleted': totalCompleted,
    };
  }

  static DailyMissionSystem fromJson(Map<String, dynamic> json) {
    return DailyMissionSystem(
      missions: (json['missions'] as List<dynamic>? ?? [])
          .map((m) => game_models.DailyMission.fromJson(m as Map<String, dynamic>))
          .toList(),
      lastRefreshDate: json['lastRefreshDate'] != null 
          ? DateTime.parse(json['lastRefreshDate'] as String)
          : null,
      streak: json['streak'] as int? ?? 0,
      totalCompleted: json['totalCompleted'] as int? ?? 0,
    );
  }
}

