/// Defines the canonical analytics event and parameter keys used across the
/// game. Keeping the constants centralized helps us align the runtime logs with
/// the measurement specification documented in AGENTS.md.
class AnalyticsEventKeys {
  const AnalyticsEventKeys._();

  static const String gameStart = 'game_start';
  static const String gameEnd = 'game_end';
  static const String adShow = 'ad_show';
  static const String adWatched = 'ad_watched';
  static const String coinsCollected = 'coins_collected';
  static const String obstacleHit = 'obstacle_hit';
  static const String missionComplete = 'mission_complete';
  static const String kpiSnapshot = 'kpi_snapshot';
}

class AnalyticsParamKeys {
  const AnalyticsParamKeys._();

  static const String sessionId = 'session_id';
  static const String tutorialActive = 'tutorial_active';
  static const String revivesUnlocked = 'revives_unlocked';
  static const String inkMultiplier = 'ink_multiplier';
  static const String missionsAvailable = 'missions_available';
  static const String totalCoins = 'total_coins';

  static const String score = 'score';
  static const String duration = 'duration';
  static const String durationMs = 'duration_ms';
  static const String coinsGained = 'coins_gained';
  static const String jumps = 'jumps';
  static const String drawTimeMs = 'draw_time_ms';
  static const String usedLine = 'used_line';
  static const String accidentDeath = 'accident_death';
  static const String revivesUsed = 'revives_used';
  static const String missionsCompletedDelta = 'missions_completed_delta';
  static const String nearMisses = 'near_misses';
  static const String inkEfficiency = 'ink_efficiency';

  static const String amount = 'amount';
  static const String source = 'source';

  static const String obstacleType = 'obstacle_type';
  static const String elapsedSeconds = 'elapsed_seconds';

  static const String trigger = 'trigger';
  static const String adType = 'ad_type';
  static const String rewardEarned = 'reward_earned';
  static const String elapsedSinceLast = 'elapsed_since_last';
  static const String policyBlockedFlags = 'policy_blocked_flags';

  static const String missionId = 'mission_id';
  static const String missionType = 'mission_type';
  static const String reward = 'reward';
  static const String totalSessions = 'total_sessions';
  static const String completedSessions = 'completed_sessions';
  static const String averageSessionMinutes = 'avg_session_minutes';
  static const String sessionsPerDay = 'sessions_per_day';
  static const String sessionsToday = 'sessions_today';
  static const String rewardedViewRate = 'rewarded_view_rate';
  static const String retentionD1 = 'retention_d1';
  static const String retentionD7 = 'retention_d7';
  static const String retentionD30 = 'retention_d30';
}
