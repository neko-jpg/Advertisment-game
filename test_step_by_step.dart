import 'lib/game/engine/difficulty_step_by_step.dart';

void main() {
  final engine = DifficultyAdjustmentEngine();
  print('Engine created: ${engine.runtimeType}');
  print('Multiplier for 3 failures: ${engine.calculateDifficultyMultiplier(3)}');
}