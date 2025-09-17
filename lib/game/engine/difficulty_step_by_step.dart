import 'dart:math' as math;

enum SkillLevel {
  beginner,
  intermediate,
  advanced,
  expert,
}

class DifficultyAdjustmentEngine {
  double calculateDifficultyMultiplier(int consecutiveFailures) {
    if (consecutiveFailures < 3) {
      return 1.0;
    }
    final reductionSteps = consecutiveFailures - 3 + 1;
    final multiplier = 1.0 - (reductionSteps * 0.2);
    return math.max(multiplier, 0.5);
  }
}