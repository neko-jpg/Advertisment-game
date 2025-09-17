import 'package:flutter/material.dart';
import '../progression/skill_progression_system.dart';

/// Widget for displaying player skill progression and unlocked features
class SkillProgressionWidget extends StatelessWidget {
  const SkillProgressionWidget({
    super.key,
    required this.progression,
    required this.skillMetrics,
    required this.progressionSystem,
    this.onFeatureSelected,
    this.onChallengeSelected,
  });

  final PlayerProgression progression;
  final SkillMetrics skillMetrics;
  final SkillProgressionSystem progressionSystem;
  final Function(UnlockableFeature)? onFeatureSelected;
  final Function(ChallengeMode)? onChallengeSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkillTierSection(context),
          const SizedBox(height: 24),
          _buildProgressSection(context),
          const SizedBox(height: 24),
          _buildUnlockedFeaturesSection(context),
          const SizedBox(height: 24),
          _buildChallengeModesSection(context),
          const SizedBox(height: 24),
          _buildMilestonesSection(context),
        ],
      ),
    );
  }

  Widget _buildSkillTierSection(BuildContext context) {
    final tierName = progressionSystem.getSkillTierDisplayName(progression.currentTier);
    final tierColor = _getTierColor(progression.currentTier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getTierIcon(progression.currentTier),
                  color: tierColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'スキルレベル',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      tierName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSkillMetricsDisplay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillMetricsDisplay(BuildContext context) {
    return Column(
      children: [
        _buildMetricRow(context, '平均スコア', skillMetrics.averageScore.toStringAsFixed(0)),
        _buildMetricRow(context, '最高スコア', skillMetrics.bestScore.toString()),
        _buildMetricRow(context, '成功率', '${(skillMetrics.successRate * 100).toStringAsFixed(1)}%'),
        _buildMetricRow(context, '精度', '${(skillMetrics.averageAccuracy * 100).toStringAsFixed(1)}%'),
        _buildMetricRow(context, '一貫性', '${(skillMetrics.consistencyRating * 100).toStringAsFixed(1)}%'),
        _buildMetricRow(context, 'プレイ時間', _formatDuration(skillMetrics.totalPlayTime)),
      ],
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final progress = progressionSystem.getProgressToNextTier();
    final nextMilestone = progressionSystem.getNextMilestone();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '進歩状況',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Progress to next tier
            Text('次のレベルまで', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getTierColor(progression.currentTier)),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            
            if (nextMilestone != null) ...[
              const SizedBox(height: 16),
              Text('次のマイルストーン', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nextMilestone.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextMilestone.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedFeaturesSection(BuildContext context) {
    final unlockedFeatures = progression.unlockedFeatures.toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'アンロック済み機能',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (unlockedFeatures.isEmpty)
              Text(
                'まだ機能がアンロックされていません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: unlockedFeatures.map((feature) {
                  return _buildFeatureChip(context, feature);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, UnlockableFeature feature) {
    final displayName = progressionSystem.getFeatureDisplayName(feature);
    
    return ActionChip(
      avatar: Icon(
        _getFeatureIcon(feature),
        size: 18,
        color: Colors.white,
      ),
      label: Text(
        displayName,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: _getFeatureColor(feature),
      onPressed: () => onFeatureSelected?.call(feature),
    );
  }

  Widget _buildChallengeModesSection(BuildContext context) {
    final availableChallenges = progressionSystem.getAvailableChallengeModes();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'チャレンジモード',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (availableChallenges.isEmpty)
              Text(
                'チャレンジモードはまだ利用できません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              )
            else
              ...availableChallenges.map((challenge) {
                return _buildChallengeCard(context, challenge);
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, ChallengeMode challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onChallengeSelected?.call(challenge),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '難易度: ${challenge.difficultyMultiplier}x',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        if (challenge.timeLimit != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(challenge.timeLimit!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestonesSection(BuildContext context) {
    final completedMilestones = progressionSystem.milestones
        .where((m) => progression.completedMilestones.contains(m.id))
        .toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '達成済みマイルストーン',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (completedMilestones.isEmpty)
              Text(
                'まだマイルストーンを達成していません',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              )
            else
              ...completedMilestones.map((milestone) {
                return _buildMilestoneItem(context, milestone);
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem(BuildContext context, SkillMilestone milestone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  milestone.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '+${milestone.experienceRequired} XP',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(SkillTier tier) {
    switch (tier) {
      case SkillTier.novice:
        return Colors.grey;
      case SkillTier.apprentice:
        return Colors.blue;
      case SkillTier.skilled:
        return Colors.green;
      case SkillTier.expert:
        return Colors.orange;
      case SkillTier.master:
        return Colors.purple;
    }
  }

  IconData _getTierIcon(SkillTier tier) {
    switch (tier) {
      case SkillTier.novice:
        return Icons.school;
      case SkillTier.apprentice:
        return Icons.build;
      case SkillTier.skilled:
        return Icons.star;
      case SkillTier.expert:
        return Icons.diamond;
      case SkillTier.master:
        return Icons.emoji_events;
    }
  }

  IconData _getFeatureIcon(UnlockableFeature feature) {
    switch (feature) {
      case UnlockableFeature.basicDrawingTools:
        return Icons.brush;
      case UnlockableFeature.advancedDrawingTools:
        return Icons.palette;
      case UnlockableFeature.rainbowPen:
        return Icons.color_lens;
      case UnlockableFeature.glowingPen:
        return Icons.auto_awesome;
      case UnlockableFeature.speedBoost:
        return Icons.speed;
      case UnlockableFeature.doubleJump:
        return Icons.keyboard_double_arrow_up;
      case UnlockableFeature.masterMode:
        return Icons.military_tech;
      case UnlockableFeature.challengeMode:
        return Icons.emoji_events;
      case UnlockableFeature.customThemes:
        return Icons.color_lens;
      case UnlockableFeature.leaderboards:
        return Icons.leaderboard;
    }
  }

  Color _getFeatureColor(UnlockableFeature feature) {
    switch (feature) {
      case UnlockableFeature.basicDrawingTools:
        return Colors.blue;
      case UnlockableFeature.advancedDrawingTools:
        return Colors.indigo;
      case UnlockableFeature.rainbowPen:
        return Colors.rainbow;
      case UnlockableFeature.glowingPen:
        return Colors.amber;
      case UnlockableFeature.speedBoost:
        return Colors.red;
      case UnlockableFeature.doubleJump:
        return Colors.green;
      case UnlockableFeature.masterMode:
        return Colors.purple;
      case UnlockableFeature.challengeMode:
        return Colors.orange;
      case UnlockableFeature.customThemes:
        return Colors.pink;
      case UnlockableFeature.leaderboards:
        return Colors.teal;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}時間${minutes}分';
    } else if (minutes > 0) {
      return '${minutes}分${seconds}秒';
    } else {
      return '${seconds}秒';
    }
  }
}

// Extension to add rainbow color
extension on Colors {
  static const Color rainbow = Color(0xFF9C27B0); // Purple as fallback
}