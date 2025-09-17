import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'models/event_models.dart';
import '../models/game_models.dart' as game_models;

/// System for managing events, challenges, and daily missions
class EventChallengeSystem {
  EventChallengeSystem({
    required this.onStateChanged,
  });

  final VoidCallback onStateChanged;
  
  final List<GameEvent> _activeEvents = [];
  final List<Challenge> _challenges = [];
  DailyMissionSystem _dailyMissionSystem = DailyMissionSystem();
  
  final math.Random _random = math.Random();

  /// Current active events
  List<GameEvent> get activeEvents => _activeEvents.where((e) => e.isCurrentlyActive).toList();

  /// All challenges
  List<Challenge> get challenges => _challenges;

  /// Unlocked challenges
  List<Challenge> get unlockedChallenges => _challenges.where((c) => c.isUnlocked).toList();

  /// Daily mission system
  DailyMissionSystem get dailyMissionSystem => _dailyMissionSystem;

  /// Initialize the system
  void initialize() {
    _initializeDefaultChallenges();
    _refreshDailyMissions();
    _checkForWeekendEvents();
    onStateChanged();
  }

  /// Update system state after a game session
  void onGameCompleted(game_models.RunStats runStats) {
    _updateEventProgress(runStats);
    _updateChallengeProgress(runStats);
    _updateDailyMissionProgress(runStats);
    _checkForNewEvents();
    onStateChanged();
  }

  /// Get today's missions
  List<game_models.DailyMission> getTodaysMissions() {
    if (_dailyMissionSystem.needsRefresh) {
      _refreshDailyMissions();
    }
    return _dailyMissionSystem.activeMissions;
  }

  /// Claim event rewards
  bool claimEventRewards(String eventId) {
    final event = _activeEvents.firstWhere(
      (e) => e.id == eventId,
      orElse: () => throw ArgumentError('Event not found: $eventId'),
    );

    if (event.completed && !event.claimed) {
      event.claimed = true;
      onStateChanged();
      return true;
    }
    return false;
  }

  /// Claim challenge rewards
  bool claimChallengeRewards(String challengeId) {
    final challenge = _challenges.firstWhere(
      (c) => c.id == challengeId,
      orElse: () => throw ArgumentError('Challenge not found: $challengeId'),
    );

    if (challenge.completed && !challenge.claimed) {
      challenge.claimed = true;
      onStateChanged();
      return true;
    }
    return false;
  }

  /// Claim daily mission rewards
  bool claimDailyMissionRewards(String missionId) {
    final mission = _dailyMissionSystem.missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => throw ArgumentError('Mission not found: $missionId'),
    );

    if (mission.completed && !mission.claimed) {
      mission.claimed = true;
      _dailyMissionSystem.totalCompleted++;
      onStateChanged();
      return true;
    }
    return false;
  }

  /// Start a specific challenge
  void startChallenge(String challengeId) {
    final challenge = _challenges.firstWhere(
      (c) => c.id == challengeId,
      orElse: () => throw ArgumentError('Challenge not found: $challengeId'),
    );

    if (challenge.isUnlocked) {
      challenge.attempts++;
      onStateChanged();
    }
  }

  /// Private methods

  void _initializeDefaultChallenges() {
    _challenges.clear();
    
    // Speed Challenge
    _challenges.add(Challenge(
      id: 'speed_master',
      title: 'Speed Master',
      description: 'Complete levels in record time',
      difficulty: ChallengeDifficulty.medium,
      objectives: [
        ChallengeObjective(
          id: 'fast_completion',
          description: 'Complete 5 levels in under 30 seconds each',
          target: 5,
        ),
      ],
      rewards: {'coins': 500, 'xp': 100},
      isUnlocked: true,
    ));

    // Coin Collector Challenge
    _challenges.add(Challenge(
      id: 'coin_collector',
      title: 'Coin Collector',
      description: 'Collect massive amounts of coins',
      difficulty: ChallengeDifficulty.easy,
      objectives: [
        ChallengeObjective(
          id: 'collect_coins',
          description: 'Collect 1000 coins in total',
          target: 1000,
        ),
      ],
      rewards: {'coins': 200, 'xp': 50},
      isUnlocked: true,
    ));

    // Perfect Run Challenge
    _challenges.add(Challenge(
      id: 'perfect_run',
      title: 'Perfect Run',
      description: 'Complete levels without any accidents',
      difficulty: ChallengeDifficulty.hard,
      objectives: [
        ChallengeObjective(
          id: 'no_accidents',
          description: 'Complete 10 levels without accidents',
          target: 10,
        ),
      ],
      rewards: {'coins': 1000, 'xp': 200, 'special_skin': 1},
      isUnlocked: false, // Unlocked after completing easier challenges
    ));

    // Drawing Master Challenge
    _challenges.add(Challenge(
      id: 'drawing_master',
      title: 'Drawing Master',
      description: 'Master the art of drawing',
      difficulty: ChallengeDifficulty.expert,
      objectives: [
        ChallengeObjective(
          id: 'drawing_time',
          description: 'Spend 30 minutes total drawing',
          target: 1800000, // 30 minutes in milliseconds
        ),
        ChallengeObjective(
          id: 'efficient_drawing',
          description: 'Complete 20 levels using minimal drawing',
          target: 20,
        ),
      ],
      rewards: {'coins': 2000, 'xp': 500, 'drawing_tool': 1},
      isUnlocked: false,
    ));
  }

  void _refreshDailyMissions() {
    final now = DateTime.now();
    
    // Check if we need to update streak
    if (_dailyMissionSystem.lastRefreshDate != null) {
      final daysDiff = now.difference(_dailyMissionSystem.lastRefreshDate!).inDays;
      if (daysDiff == 1) {
        // Consecutive day - maintain or increase streak
        if (_dailyMissionSystem.completedMissions.isNotEmpty) {
          _dailyMissionSystem.streak++;
        } else {
          _dailyMissionSystem.streak = 0; // Reset if no missions completed yesterday
        }
      } else if (daysDiff > 1) {
        // Missed days - reset streak
        _dailyMissionSystem.streak = 0;
      }
    }

    // Generate new missions
    final newMissions = _generateDailyMissions();
    _dailyMissionSystem = DailyMissionSystem(
      missions: newMissions,
      lastRefreshDate: now,
      streak: _dailyMissionSystem.streak,
      totalCompleted: _dailyMissionSystem.totalCompleted,
    );
  }

  List<game_models.DailyMission> _generateDailyMissions() {
    final missions = <game_models.DailyMission>[];
    final missionTemplates = [
      {'type': game_models.MissionType.collectCoins, 'title': 'Coin Hunter', 'description': 'Collect {target} coins', 'baseTarget': 100},
      {'type': game_models.MissionType.surviveTime, 'title': 'Endurance Runner', 'description': 'Survive for {target} seconds total', 'baseTarget': 300},
      {'type': game_models.MissionType.jumpCount, 'title': 'Jump Master', 'description': 'Perform {target} jumps', 'baseTarget': 50},
      {'type': game_models.MissionType.drawTime, 'title': 'Artist', 'description': 'Draw for {target} seconds total', 'baseTarget': 120},
    ];

    // Generate 3 random missions
    final shuffledTemplates = List.from(missionTemplates)..shuffle(_random);
    for (int i = 0; i < 3 && i < shuffledTemplates.length; i++) {
      final template = shuffledTemplates[i];
      final baseTarget = template['baseTarget'] as int;
      final target = baseTarget + _random.nextInt(baseTarget ~/ 2); // Add some variation
      final missionType = template['type'] as game_models.MissionType;
      
      missions.add(game_models.DailyMission(
        id: 'daily_${missionType.name}_${DateTime.now().millisecondsSinceEpoch}',
        type: missionType,
        target: target,
        reward: 50 + (target ~/ 10), // Scale reward with difficulty
      ));
    }

    return missions;
  }

  void _checkForWeekendEvents() {
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    
    if (isWeekend) {
      // Check if weekend double coins event already exists
      final existingWeekendEvent = _activeEvents.any((e) => 
          e.type == EventType.weekendDoubleCoins && e.isCurrentlyActive);
      
      if (!existingWeekendEvent) {
        final weekendStart = DateTime(now.year, now.month, now.day);
        final weekendEnd = weekendStart.add(const Duration(days: 2));
        
        _activeEvents.add(GameEvent(
          id: 'weekend_${now.millisecondsSinceEpoch}',
          type: EventType.weekendDoubleCoins,
          title: 'Weekend Double Coins',
          description: 'Earn double coins from all activities this weekend!',
          startTime: weekendStart,
          endTime: weekendEnd,
          rewards: {'coin_multiplier': 2},
          isActive: true,
        ));
      }
    }
  }

  void _updateEventProgress(game_models.RunStats runStats) {
    for (final event in _activeEvents) {
      if (!event.isCurrentlyActive || event.completed) continue;

      switch (event.type) {
        case EventType.weekendDoubleCoins:
          // This event is automatically active, no progress needed
          event.progress = 1.0;
          event.completed = true;
          break;
        case EventType.speedChallenge:
          // Update based on completion time
          if (runStats.duration.inSeconds < 30) {
            event.progress = (event.progress + 0.2).clamp(0.0, 1.0);
            if (event.progress >= 1.0) {
              event.completed = true;
            }
          }
          break;
        case EventType.dailyMission:
        case EventType.specialChallenge:
          // These are handled separately
          break;
      }
    }
  }

  void _updateChallengeProgress(game_models.RunStats runStats) {
    for (final challenge in _challenges) {
      if (!challenge.isUnlocked || challenge.completed) continue;

      for (final objective in challenge.objectives) {
        switch (objective.id) {
          case 'fast_completion':
            if (runStats.duration.inSeconds < 30) {
              objective.currentValue++;
            }
            break;
          case 'collect_coins':
            objective.currentValue += runStats.coins;
            break;
          case 'no_accidents':
            if (!runStats.accidentDeath) {
              objective.currentValue++;
            } else {
              objective.currentValue = 0; // Reset on accident
            }
            break;
          case 'drawing_time':
            objective.currentValue += runStats.drawTimeMs;
            break;
          case 'efficient_drawing':
            if (runStats.drawTimeMs < 5000) { // Less than 5 seconds drawing
              objective.currentValue++;
            }
            break;
        }

        // Update challenge progress
        challenge.progress[objective.id] = objective.progress;
      }

      // Check if challenge is completed
      if (challenge.allObjectivesCompleted && !challenge.completed) {
        challenge.completed = true;
        _unlockNextChallenges(challenge);
      }
    }
  }

  void _updateDailyMissionProgress(game_models.RunStats runStats) {
    for (final mission in _dailyMissionSystem.missions) {
      if (mission.completed) continue;

      switch (mission.type) {
        case game_models.MissionType.collectCoins:
          mission.progress += runStats.coins;
          break;
        case game_models.MissionType.surviveTime:
          mission.progress += runStats.duration.inSeconds;
          break;
        case game_models.MissionType.jumpCount:
          mission.progress += runStats.jumpsPerformed;
          break;
        case game_models.MissionType.drawTime:
          mission.progress += runStats.drawTimeMs ~/ 1000; // Convert to seconds
          break;
      }

      if (mission.progress >= mission.target && !mission.completed) {
        mission.completed = true;
      }
    }
  }

  void _unlockNextChallenges(Challenge completedChallenge) {
    // Unlock harder challenges based on completed ones
    if (completedChallenge.id == 'coin_collector') {
      final perfectRun = _challenges.firstWhere((c) => c.id == 'perfect_run');
      perfectRun.isUnlocked = true;
    }
    
    if (completedChallenge.id == 'perfect_run') {
      final drawingMaster = _challenges.firstWhere((c) => c.id == 'drawing_master');
      drawingMaster.isUnlocked = true;
    }
  }

  void _checkForNewEvents() {
    // Remove expired events
    _activeEvents.removeWhere((event) => event.isExpired);
    
    // Add new events based on conditions
    final now = DateTime.now();
    
    // Speed challenge event (random chance)
    if (_random.nextDouble() < 0.1) { // 10% chance per game
      final existingSpeedEvent = _activeEvents.any((e) => 
          e.type == EventType.speedChallenge && e.isCurrentlyActive);
      
      if (!existingSpeedEvent) {
        _activeEvents.add(GameEvent(
          id: 'speed_${now.millisecondsSinceEpoch}',
          type: EventType.speedChallenge,
          title: 'Speed Challenge',
          description: 'Complete 5 levels in under 30 seconds each for bonus rewards!',
          startTime: now,
          endTime: now.add(const Duration(hours: 2)),
          rewards: {'coins': 300, 'xp': 75},
          isActive: true,
        ));
      }
    }
  }

  /// Serialization methods

  Map<String, dynamic> toJson() {
    return {
      'activeEvents': _activeEvents.map((e) => e.toJson()).toList(),
      'challenges': _challenges.map((c) => c.toJson()).toList(),
      'dailyMissionSystem': _dailyMissionSystem.toJson(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _activeEvents.clear();
    _activeEvents.addAll(
      (json['activeEvents'] as List<dynamic>? ?? [])
          .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
    );

    _challenges.clear();
    _challenges.addAll(
      (json['challenges'] as List<dynamic>? ?? [])
          .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
    );

    _dailyMissionSystem = DailyMissionSystem.fromJson(
      json['dailyMissionSystem'] as Map<String, dynamic>? ?? {}
    );

    // Initialize if no data was loaded
    if (_challenges.isEmpty) {
      _initializeDefaultChallenges();
    }

    onStateChanged();
  }
}