import 'dart:math' as math;

/// Player skill progression levels
enum SkillTier {
  novice,
  apprentice,
  skilled,
  expert,
  master,
}

/// Unlockable features based on skill progression
enum UnlockableFeature {
  basicDrawingTools,
  advancedDrawingTools,
  rainbowPen,
  glowingPen,
  speedBoost,
  doubleJump,
  masterMode,
  challengeMode,
  customThemes,
  leaderboards,
}

/// Player skill metrics for progression calculation
class SkillMetrics {
  const SkillMetrics({
    required this.totalPlayTime,
    required this.averageScore,
    required this.bestScore,
    required this.totalGamesPlayed,
    required this.successfulGames,
    required this.averageAccuracy,
    required this.consistencyRating,
    required this.improvementRate,
  });

  final Duration totalPlayTime;
  final double averageScore;
  final int bestScore;
  final int totalGamesPlayed;
  final int successfulGames;
  final double averageAccuracy;
  final double consistencyRating;
  final double improvementRate;

  double get successRate => totalGamesPlayed > 0 ? successfulGames / totalGamesPlayed : 0.0;
}

/// Represents a skill milestone with requirements and rewards
class SkillMilestone {
  const SkillMilestone({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.requirements,
    required this.rewards,
    required this.experienceRequired,
  });

  final String id;
  final String name;
  final String description;
  final SkillTier tier;
  final Map<String, dynamic> requirements;
  final List<UnlockableFeature> rewards;
  final int experienceRequired;
}

/// Player progression state
class PlayerProgression {
  PlayerProgression({
    this.currentTier = SkillTier.novice,
    this.experience = 0,
    this.unlockedFeatures = const {},
    this.completedMilestones = const {},
    this.skillPoints = 0,
  });

  final SkillTier currentTier;
  final int experience;
  final Set<UnlockableFeature> unlockedFeatures;
  final Set<String> completedMilestones;
  final int skillPoints;

  PlayerProgression copyWith({
    SkillTier? currentTier,
    int? experience,
    Set<UnlockableFeature>? unlockedFeatures,
    Set<String>? completedMilestones,
    int? skillPoints,
  }) {
    return PlayerProgression(
      currentTier: currentTier ?? this.currentTier,
      experience: experience ?? this.experience,
      unlockedFeatures: unlockedFeatures ?? this.unlockedFeatures,
      completedMilestones: completedMilestones ?? this.completedMilestones,
      skillPoints: skillPoints ?? this.skillPoints,
    );
  }
}

/// Challenge mode configuration
class ChallengeMode {
  const ChallengeMode({
    required this.id,
    required this.name,
    required this.description,
    required this.difficultyMultiplier,
    required this.requiredTier,
    required this.timeLimit,
    required this.specialRules,
    required this.rewards,
  });

  final String id;
  final String name;
  final String description;
  final double difficultyMultiplier;
  final SkillTier requiredTier;
  final Duration? timeLimit;
  final Map<String, dynamic> specialRules;
  final Map<String, int> rewards; // reward type -> amount
}

/// Manages player skill progression and feature unlocking
class SkillProgressionSystem {
  static const int _baseExperiencePerLevel = 1000;
  static const double _experienceGrowthRate = 1.5;

  final List<SkillMilestone> _milestones = [];
  final List<ChallengeMode> _challengeModes = [];
  
  PlayerProgression _currentProgression = PlayerProgression();

  SkillProgressionSystem() {
    _initializeMilestones();
    _initializeChallengeModes();
  }

  /// Initialize skill milestones and their requirements
  void _initializeMilestones() {
    _milestones.addAll([
      // Novice tier milestones
      const SkillMilestone(
        id: 'first_steps',
        name: '最初の一歩',
        description: '初回ゲームを完了する',
        tier: SkillTier.novice,
        requirements: {'gamesPlayed': 1},
        rewards: [UnlockableFeature.basicDrawingTools],
        experienceRequired: 100,
      ),
      const SkillMilestone(
        id: 'getting_started',
        name: 'スタートライン',
        description: '10回ゲームをプレイする',
        tier: SkillTier.novice,
        requirements: {'gamesPlayed': 10, 'averageScore': 50},
        rewards: [UnlockableFeature.advancedDrawingTools],
        experienceRequired: 500,
      ),

      // Apprentice tier milestones
      const SkillMilestone(
        id: 'apprentice_skills',
        name: '見習いの技',
        description: '平均スコア200を達成し、成功率60%を維持する',
        tier: SkillTier.apprentice,
        requirements: {'averageScore': 200, 'successRate': 0.6, 'gamesPlayed': 25},
        rewards: [UnlockableFeature.rainbowPen, UnlockableFeature.speedBoost],
        experienceRequired: 1500,
      ),
      const SkillMilestone(
        id: 'consistency_master',
        name: '安定性の達人',
        description: '一貫性評価80%以上を達成する',
        tier: SkillTier.apprentice,
        requirements: {'consistencyRating': 0.8, 'gamesPlayed': 50},
        rewards: [UnlockableFeature.glowingPen],
        experienceRequired: 2000,
      ),

      // Skilled tier milestones
      const SkillMilestone(
        id: 'skilled_player',
        name: '熟練プレイヤー',
        description: '平均スコア500、成功率75%を達成する',
        tier: SkillTier.skilled,
        requirements: {'averageScore': 500, 'successRate': 0.75, 'bestScore': 800},
        rewards: [UnlockableFeature.doubleJump, UnlockableFeature.customThemes],
        experienceRequired: 4000,
      ),
      const SkillMilestone(
        id: 'accuracy_expert',
        name: '精度エキスパート',
        description: '平均精度85%以上を達成する',
        tier: SkillTier.skilled,
        requirements: {'averageAccuracy': 0.85, 'gamesPlayed': 100},
        rewards: [UnlockableFeature.challengeMode],
        experienceRequired: 5000,
      ),

      // Expert tier milestones
      const SkillMilestone(
        id: 'expert_level',
        name: 'エキスパートレベル',
        description: '平均スコア800、最高スコア1200を達成する',
        tier: SkillTier.expert,
        requirements: {'averageScore': 800, 'bestScore': 1200, 'successRate': 0.85},
        rewards: [UnlockableFeature.leaderboards],
        experienceRequired: 8000,
      ),
      const SkillMilestone(
        id: 'improvement_champion',
        name: '向上チャンピオン',
        description: '継続的な改善率を示す',
        tier: SkillTier.expert,
        requirements: {'improvementRate': 0.2, 'totalPlayTime': 7200}, // 2 hours
        rewards: [UnlockableFeature.masterMode],
        experienceRequired: 10000,
      ),

      // Master tier milestones
      const SkillMilestone(
        id: 'master_achievement',
        name: 'マスターの証',
        description: '全ての技能で最高レベルを達成する',
        tier: SkillTier.master,
        requirements: {
          'averageScore': 1000,
          'bestScore': 1500,
          'successRate': 0.9,
          'averageAccuracy': 0.9,
          'consistencyRating': 0.9,
          'totalPlayTime': 14400, // 4 hours
        },
        rewards: [], // Master tier unlocks all features
        experienceRequired: 15000,
      ),
    ]);
  }

  /// Initialize challenge modes
  void _initializeChallengeModes() {
    _challengeModes.addAll([
      const ChallengeMode(
        id: 'speed_challenge',
        name: 'スピードチャレンジ',
        description: '制限時間内でできるだけ高いスコアを目指す',
        difficultyMultiplier: 1.2,
        requiredTier: SkillTier.apprentice,
        timeLimit: Duration(minutes: 2),
        specialRules: {'speedMultiplier': 1.5, 'timeBonus': true},
        rewards: {'experience': 200, 'coins': 100},
      ),
      const ChallengeMode(
        id: 'precision_challenge',
        name: '精密チャレンジ',
        description: '完璧な精度でプレイする',
        difficultyMultiplier: 1.5,
        requiredTier: SkillTier.skilled,
        timeLimit: null,
        specialRules: {'perfectAccuracyRequired': true, 'noMistakes': true},
        rewards: {'experience': 300, 'coins': 150},
      ),
      const ChallengeMode(
        id: 'endurance_challenge',
        name: '持久力チャレンジ',
        description: '長時間のプレイで持久力を試す',
        difficultyMultiplier: 1.3,
        requiredTier: SkillTier.skilled,
        timeLimit: Duration(minutes: 10),
        specialRules: {'increasingDifficulty': true, 'noBreaks': true},
        rewards: {'experience': 400, 'coins': 200},
      ),
      const ChallengeMode(
        id: 'master_challenge',
        name: 'マスターチャレンジ',
        description: '最高難易度での究極の挑戦',
        difficultyMultiplier: 2.0,
        requiredTier: SkillTier.expert,
        timeLimit: Duration(minutes: 5),
        specialRules: {
          'maxDifficulty': true,
          'limitedLives': 3,
          'perfectScoreRequired': 1000,
        },
        rewards: {'experience': 1000, 'coins': 500, 'masterBadge': 1},
      ),
    ]);
  }

  /// Calculate experience required for a specific tier
  int getExperienceRequiredForTier(SkillTier tier) {
    switch (tier) {
      case SkillTier.novice:
        return 0;
      case SkillTier.apprentice:
        return 1000;
      case SkillTier.skilled:
        return 3000;
      case SkillTier.expert:
        return 7000;
      case SkillTier.master:
        return 15000;
    }
  }

  /// Calculate player's skill tier based on metrics
  SkillTier calculateSkillTier(SkillMetrics metrics) {
    // Advanced tier calculation based on multiple factors
    int score = 0;

    // Score contribution (40% weight)
    if (metrics.averageScore >= 1000) score += 400;
    else if (metrics.averageScore >= 800) score += 350;
    else if (metrics.averageScore >= 500) score += 250;
    else if (metrics.averageScore >= 200) score += 150;
    else if (metrics.averageScore >= 50) score += 50;

    // Success rate contribution (25% weight)
    score += (metrics.successRate * 250).round();

    // Accuracy contribution (20% weight)
    score += (metrics.averageAccuracy * 200).round();

    // Consistency contribution (10% weight)
    score += (metrics.consistencyRating * 100).round();

    // Experience contribution (5% weight)
    final hoursPlayed = metrics.totalPlayTime.inHours;
    if (hoursPlayed >= 4) score += 50;
    else if (hoursPlayed >= 2) score += 30;
    else if (hoursPlayed >= 1) score += 20;
    else if (hoursPlayed >= 0.5) score += 10;

    // Determine tier based on total score
    if (score >= 900) return SkillTier.master;
    if (score >= 700) return SkillTier.expert;
    if (score >= 500) return SkillTier.skilled;
    if (score >= 250) return SkillTier.apprentice;
    return SkillTier.novice;
  }

  /// Check if player meets requirements for a milestone
  bool checkMilestoneRequirements(SkillMilestone milestone, SkillMetrics metrics) {
    for (final entry in milestone.requirements.entries) {
      switch (entry.key) {
        case 'gamesPlayed':
          if (metrics.totalGamesPlayed < entry.value) return false;
          break;
        case 'averageScore':
          if (metrics.averageScore < entry.value) return false;
          break;
        case 'bestScore':
          if (metrics.bestScore < entry.value) return false;
          break;
        case 'successRate':
          if (metrics.successRate < entry.value) return false;
          break;
        case 'averageAccuracy':
          if (metrics.averageAccuracy < entry.value) return false;
          break;
        case 'consistencyRating':
          if (metrics.consistencyRating < entry.value) return false;
          break;
        case 'improvementRate':
          if (metrics.improvementRate < entry.value) return false;
          break;
        case 'totalPlayTime':
          if (metrics.totalPlayTime.inSeconds < entry.value) return false;
          break;
      }
    }
    return true;
  }

  /// Update player progression based on current metrics
  PlayerProgression updateProgression(SkillMetrics metrics) {
    final newTier = calculateSkillTier(metrics);
    int newExperience = _currentProgression.experience;
    final newUnlockedFeatures = Set<UnlockableFeature>.from(_currentProgression.unlockedFeatures);
    final newCompletedMilestones = Set<String>.from(_currentProgression.completedMilestones);
    int newSkillPoints = _currentProgression.skillPoints;

    // Check for completed milestones
    for (final milestone in _milestones) {
      if (!newCompletedMilestones.contains(milestone.id) &&
          checkMilestoneRequirements(milestone, metrics)) {
        newCompletedMilestones.add(milestone.id);
        newExperience += milestone.experienceRequired;
        newUnlockedFeatures.addAll(milestone.rewards);
        newSkillPoints += _calculateSkillPointsForMilestone(milestone);
      }
    }

    // Unlock tier-based features
    _unlockTierFeatures(newTier, newUnlockedFeatures);

    _currentProgression = PlayerProgression(
      currentTier: newTier,
      experience: newExperience,
      unlockedFeatures: newUnlockedFeatures,
      completedMilestones: newCompletedMilestones,
      skillPoints: newSkillPoints,
    );

    return _currentProgression;
  }

  /// Calculate skill points awarded for completing a milestone
  int _calculateSkillPointsForMilestone(SkillMilestone milestone) {
    switch (milestone.tier) {
      case SkillTier.novice:
        return 10;
      case SkillTier.apprentice:
        return 25;
      case SkillTier.skilled:
        return 50;
      case SkillTier.expert:
        return 100;
      case SkillTier.master:
        return 200;
    }
  }

  /// Unlock features based on skill tier
  void _unlockTierFeatures(SkillTier tier, Set<UnlockableFeature> unlockedFeatures) {
    switch (tier) {
      case SkillTier.novice:
        unlockedFeatures.add(UnlockableFeature.basicDrawingTools);
        break;
      case SkillTier.apprentice:
        unlockedFeatures.addAll([
          UnlockableFeature.basicDrawingTools,
          UnlockableFeature.advancedDrawingTools,
        ]);
        break;
      case SkillTier.skilled:
        unlockedFeatures.addAll([
          UnlockableFeature.basicDrawingTools,
          UnlockableFeature.advancedDrawingTools,
          UnlockableFeature.rainbowPen,
          UnlockableFeature.speedBoost,
        ]);
        break;
      case SkillTier.expert:
        unlockedFeatures.addAll([
          UnlockableFeature.basicDrawingTools,
          UnlockableFeature.advancedDrawingTools,
          UnlockableFeature.rainbowPen,
          UnlockableFeature.glowingPen,
          UnlockableFeature.speedBoost,
          UnlockableFeature.doubleJump,
          UnlockableFeature.challengeMode,
          UnlockableFeature.customThemes,
        ]);
        break;
      case SkillTier.master:
        unlockedFeatures.addAll(UnlockableFeature.values);
        break;
    }
  }

  /// Get available challenge modes for current skill tier
  List<ChallengeMode> getAvailableChallengeModes() {
    return _challengeModes
        .where((mode) => _currentProgression.currentTier.index >= mode.requiredTier.index)
        .toList();
  }

  /// Get next milestone for current progression
  SkillMilestone? getNextMilestone() {
    for (final milestone in _milestones) {
      if (!_currentProgression.completedMilestones.contains(milestone.id)) {
        return milestone;
      }
    }
    return null; // All milestones completed
  }

  /// Get progress towards next tier
  double getProgressToNextTier() {
    final currentTierExp = getExperienceRequiredForTier(_currentProgression.currentTier);
    final nextTier = SkillTier.values[math.min(_currentProgression.currentTier.index + 1, SkillTier.values.length - 1)];
    final nextTierExp = getExperienceRequiredForTier(nextTier);
    
    if (nextTierExp == currentTierExp) return 1.0; // Already at max tier
    
    final progress = (_currentProgression.experience - currentTierExp) / (nextTierExp - currentTierExp);
    return math.max(0.0, math.min(1.0, progress));
  }

  /// Check if a feature is unlocked
  bool isFeatureUnlocked(UnlockableFeature feature) {
    return _currentProgression.unlockedFeatures.contains(feature);
  }

  /// Get current progression state
  PlayerProgression get currentProgression => _currentProgression;

  /// Get all milestones
  List<SkillMilestone> get milestones => List.unmodifiable(_milestones);

  /// Get all challenge modes
  List<ChallengeMode> get challengeModes => List.unmodifiable(_challengeModes);

  /// Get skill tier display name
  String getSkillTierDisplayName(SkillTier tier) {
    switch (tier) {
      case SkillTier.novice:
        return '初心者';
      case SkillTier.apprentice:
        return '見習い';
      case SkillTier.skilled:
        return '熟練者';
      case SkillTier.expert:
        return 'エキスパート';
      case SkillTier.master:
        return 'マスター';
    }
  }

  /// Get feature display name
  String getFeatureDisplayName(UnlockableFeature feature) {
    switch (feature) {
      case UnlockableFeature.basicDrawingTools:
        return '基本描画ツール';
      case UnlockableFeature.advancedDrawingTools:
        return '高度描画ツール';
      case UnlockableFeature.rainbowPen:
        return '虹ペン';
      case UnlockableFeature.glowingPen:
        return '光るペン';
      case UnlockableFeature.speedBoost:
        return 'スピードブースト';
      case UnlockableFeature.doubleJump:
        return 'ダブルジャンプ';
      case UnlockableFeature.masterMode:
        return 'マスターモード';
      case UnlockableFeature.challengeMode:
        return 'チャレンジモード';
      case UnlockableFeature.customThemes:
        return 'カスタムテーマ';
      case UnlockableFeature.leaderboards:
        return 'リーダーボード';
    }
  }
}