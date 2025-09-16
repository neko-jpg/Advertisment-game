library constants.game_constants;

class GameConstants {
  const GameConstants._();

  static const double playerStartX = 100.0;
  static const double playerStartY = 380.0;
  static const double baseCoyoteDurationMs = 120.0;
  static const double jumpBufferDurationMs = 100.0;
  static const double restIntervalMs = 30000.0;
  static const double restDurationMs = 6000.0;
  static const double absoluteMinSpeedMultiplier = 0.6;
  static const double tutorialMaxSpeedMultiplier = 0.85;
  static const int maxRecentRunsTracked = 5;
  static const int difficultySampleSize = 3;
  static const int accidentStreakGraceThreshold = 2;
  static const Duration accidentGraceDuration = Duration(seconds: 5);
  static const int scoreBonusStep = 400;
  static const int baseBonusReward = 20;
  static const int bonusRewardIncrement = 10;
}

class DifficultyConstants {
  const DifficultyConstants._();

  static const double defaultSafeWindowPx = 180.0;
  static const double emptyHistorySafeWindowPx = 200.0;
  static const double minSpeedMultiplier = 0.7;
  static const double maxSpeedMultiplier = 1.6;
  static const double minDensityMultiplier = 0.6;
  static const double maxDensityMultiplier = 1.8;
  static const double minCoinMultiplier = 0.7;
  static const double maxCoinMultiplier = 1.8;
  static const double minSafeWindowPx = 140.0;
  static const double maxSafeWindowPx = 260.0;

  static const int longRunDurationSeconds = 45;
  static const int shortRunDurationSeconds = 20;
  static const int consistentRunDurationSeconds = 30;
  static const double highAccidentRate = 0.66;
  static const double lowAccidentRate = 0.2;
  static const int highScoreThreshold = 900;
  static const int lowScoreThreshold = 300;

  static const double longRunSpeedDelta = 0.18;
  static const double longRunDensityDelta = 0.12;
  static const double longRunCoinDelta = -0.12;

  static const double shortRunSpeedDelta = -0.12;
  static const double shortRunDensityDelta = -0.18;
  static const double shortRunCoinDelta = 0.18;

  static const double highAccidentSpeedDelta = -0.15;
  static const double highAccidentDensityDelta = -0.18;
  static const double highAccidentSafeWindowDelta = 60.0;
  static const double highAccidentCoinDelta = 0.15;

  static const double lowAccidentSpeedDelta = 0.08;
  static const double lowAccidentDensityDelta = 0.1;

  static const double highScoreDensityDelta = 0.08;
  static const double highScoreCoinDelta = -0.08;
  static const double lowScoreDensityDelta = -0.1;
  static const double lowScoreCoinDelta = 0.12;
}
