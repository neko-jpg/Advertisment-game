import 'package:flutter/material.dart';
import '../models/event_models.dart';
import '../event_challenge_system.dart';
import '../../models/game_models.dart' as game_models;

extension DailyMissionExtension on game_models.DailyMission {
  double get progressPercentage => (progress / target).clamp(0.0, 1.0);
  
  String get displayTitle {
    switch (type) {
      case game_models.MissionType.collectCoins:
        return 'Coin Hunter';
      case game_models.MissionType.surviveTime:
        return 'Endurance Runner';
      case game_models.MissionType.jumpCount:
        return 'Jump Master';
      case game_models.MissionType.drawTime:
        return 'Artist';
    }
  }
  
  String get displayDescription {
    switch (type) {
      case game_models.MissionType.collectCoins:
        return 'Collect $target coins';
      case game_models.MissionType.surviveTime:
        return 'Survive for $target seconds total';
      case game_models.MissionType.jumpCount:
        return 'Perform $target jumps';
      case game_models.MissionType.drawTime:
        return 'Draw for $target seconds total';
    }
  }
}

/// Widget for displaying events, challenges, and daily missions
class EventChallengeWidget extends StatefulWidget {
  const EventChallengeWidget({
    super.key,
    required this.system,
    this.onRewardClaimed,
  });

  final EventChallengeSystem system;
  final VoidCallback? onRewardClaimed;

  @override
  State<EventChallengeWidget> createState() => _EventChallengeWidgetState();
}

class _EventChallengeWidgetState extends State<EventChallengeWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Events', icon: Icon(Icons.event)),
              Tab(text: 'Challenges', icon: Icon(Icons.emoji_events)),
              Tab(text: 'Daily', icon: Icon(Icons.today)),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventsTab(),
                _buildChallengesTab(),
                _buildDailyMissionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final activeEvents = widget.system.activeEvents;
    
    if (activeEvents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active events', style: TextStyle(color: Colors.grey)),
            Text('Check back later for special events!', 
                 style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeEvents.length,
      itemBuilder: (context, index) {
        final event = activeEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(GameEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getEventIcon(event.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        event.description,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (event.completed && !event.claimed)
                  ElevatedButton(
                    onPressed: () => _claimEventReward(event),
                    child: const Text('Claim'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: event.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                event.completed ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${(event.progress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Ends in: ${_formatDuration(event.timeRemaining)}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
            if (event.rewards.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: event.rewards.entries.map((reward) {
                  return Chip(
                    label: Text('${reward.value} ${reward.key}'),
                    backgroundColor: Colors.amber.shade100,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesTab() {
    final challenges = widget.system.unlockedChallenges;
    
    if (challenges.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No challenges unlocked', style: TextStyle(color: Colors.grey)),
            Text('Complete more games to unlock challenges!', 
                 style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: challenges.length,
      itemBuilder: (context, index) {
        final challenge = challenges[index];
        return _buildChallengeCard(challenge);
      },
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getDifficultyIcon(challenge.difficulty),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        challenge.description,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (challenge.completed && !challenge.claimed)
                  ElevatedButton(
                    onPressed: () => _claimChallengeReward(challenge),
                    child: const Text('Claim'),
                  )
                else if (!challenge.completed)
                  OutlinedButton(
                    onPressed: () => _startChallenge(challenge),
                    child: const Text('Start'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...challenge.objectives.map((objective) => 
                _buildObjectiveProgress(objective, challenge.progress[objective.id] ?? 0.0)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: challenge.overallProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                challenge.completed ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall: ${(challenge.overallProgress * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Attempts: ${challenge.attempts}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (challenge.rewards.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: challenge.rewards.entries.map((reward) {
                  return Chip(
                    label: Text('${reward.value} ${reward.key}'),
                    backgroundColor: _getDifficultyColor(challenge.difficulty).withOpacity(0.2),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildObjectiveProgress(ChallengeObjective objective, double progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            objective.description,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              objective.isCompleted ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${objective.currentValue}/${objective.target}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMissionsTab() {
    final missions = widget.system.getTodaysMissions();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Daily Streak: ${widget.system.dailyMissionSystem.streak} days',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Total: ${widget.system.dailyMissionSystem.totalCompleted}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final mission = missions[index];
              return _buildMissionCard(mission);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMissionCard(game_models.DailyMission mission) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getMissionIcon(mission.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.displayTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        mission.displayDescription,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (mission.completed && !mission.claimed)
                  ElevatedButton(
                    onPressed: () => _claimMissionReward(mission),
                    child: const Text('Claim'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: mission.progressPercentage,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                mission.completed ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${mission.progress}/${mission.target}',
                  style: const TextStyle(fontSize: 12),
                ),
                Chip(
                  label: Text('${mission.reward} coins'),
                  backgroundColor: Colors.amber.shade100,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getEventIcon(EventType type) {
    switch (type) {
      case EventType.weekendDoubleCoins:
        return const Icon(Icons.weekend, color: Colors.green);
      case EventType.speedChallenge:
        return const Icon(Icons.speed, color: Colors.red);
      case EventType.dailyMission:
        return const Icon(Icons.today, color: Colors.blue);
      case EventType.specialChallenge:
        return const Icon(Icons.star, color: Colors.purple);
    }
  }

  Widget _getDifficultyIcon(ChallengeDifficulty difficulty) {
    final color = _getDifficultyColor(difficulty);
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return Icon(Icons.sentiment_satisfied, color: color);
      case ChallengeDifficulty.medium:
        return Icon(Icons.sentiment_neutral, color: color);
      case ChallengeDifficulty.hard:
        return Icon(Icons.sentiment_dissatisfied, color: color);
      case ChallengeDifficulty.expert:
        return Icon(Icons.sentiment_very_dissatisfied, color: color);
    }
  }

  Color _getDifficultyColor(ChallengeDifficulty difficulty) {
    switch (difficulty) {
      case ChallengeDifficulty.easy:
        return Colors.green;
      case ChallengeDifficulty.medium:
        return Colors.orange;
      case ChallengeDifficulty.hard:
        return Colors.red;
      case ChallengeDifficulty.expert:
        return Colors.purple;
    }
  }

  Widget _getMissionIcon(game_models.MissionType type) {
    switch (type) {
      case game_models.MissionType.collectCoins:
        return const Icon(Icons.monetization_on, color: Colors.amber);
      case game_models.MissionType.surviveTime:
        return const Icon(Icons.timer, color: Colors.blue);
      case game_models.MissionType.jumpCount:
        return const Icon(Icons.jump_to_element, color: Colors.orange);
      case game_models.MissionType.drawTime:
        return const Icon(Icons.brush, color: Colors.purple);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _claimEventReward(GameEvent event) {
    if (widget.system.claimEventRewards(event.id)) {
      widget.onRewardClaimed?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claimed rewards from ${event.title}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _claimChallengeReward(Challenge challenge) {
    if (widget.system.claimChallengeRewards(challenge.id)) {
      widget.onRewardClaimed?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claimed rewards from ${challenge.title}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _claimMissionReward(DailyMission mission) {
    if (widget.system.claimDailyMissionRewards(mission.id)) {
      widget.onRewardClaimed?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Claimed ${mission.reward} coins from ${mission.displayTitle}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _startChallenge(Challenge challenge) {
    widget.system.startChallenge(challenge.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Started challenge: ${challenge.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}