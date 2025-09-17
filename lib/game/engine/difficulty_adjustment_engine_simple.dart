import 'dart:math' as math;

/// Skill levels for player classification
enum SkillLevel {
  beginner,
  intermediate,
  advanced,
  expert,
}

/// Engine for dynamic difficulty adjustment based on player performance
class DifficultyAdjustmentEngine {
  static const int _consecutiveFailureThreshold = 3;
  static const double _difficultyReductionRate = 0.2;
  static const double _minDifficultyMultiplier = 0.5;

  /// Calculate difficulty multiplier based on consecutive failures
  double calculateDifficultyMultiplier(int consecutiveFailures) {
    if (consecutiveFailures < _consecutiveFailureThreshold) {
      return 1.0;
    }

    final reductionSteps = consecutiveFailures - _consecutiveFailureThreshold + 1;
    final multiplier = 1.0 - (reductionSteps * _difficultyReductionRate);
    
    return math.max(multiplier, _minDifficultyMultiplier);
  }
}