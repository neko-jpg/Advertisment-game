import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/engine/difficulty_adjustment_engine_simple.dart';

void main() {
  test('DifficultyAdjustmentEngine can be instantiated', () {
    final engine = DifficultyAdjustmentEngine();
    expect(engine, isNotNull);
  });

  test('calculateDifficultyMultiplier works', () {
    final engine = DifficultyAdjustmentEngine();
    expect(engine.calculateDifficultyMultiplier(0), equals(1.0));
    expect(engine.calculateDifficultyMultiplier(3), equals(0.8));
  });
}