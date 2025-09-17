import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/engine/difficulty_adjustment_engine.dart';

void main() {
  test('DifficultyAdjustmentEngine can be instantiated', () {
    final engine = DifficultyAdjustmentEngine();
    expect(engine, isNotNull);
  });
}