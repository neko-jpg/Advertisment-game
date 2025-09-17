import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/engine/difficulty_adjustment_engine.dart';

void main() {
  group('DifficultyAdjustmentEngine Basic Tests', () {
    late DifficultyAdjustmentEngine engine;

    setUp(() {
      engine = DifficultyAdjustmentEngine();
    });

    test('can be instantiated', () {
      expect(engine, isNotNull);
    });

    test('calculateDifficultyMultiplier works correctly', () {
      expect(engine.calculateDifficultyMultiplier(0), equals(1.0));
      expect(engine.calculateDifficultyMultiplier(1), equals(1.0));
      expect(engine.calculateDifficultyMultiplier(2), equals(1.0));
      expect(engine.calculateDifficultyMultiplier(3), equals(0.8));
      expect(engine.calculateDifficultyMultiplier(4), equals(0.6));
      expect(engine.calculateDifficultyMultiplier(5), equals(0.5));
      expect(engine.calculateDifficultyMultiplier(10), equals(0.5));
    });

    test('assessPlayerSkill returns beginner for empty sessions', () {
      expect(engine.assessPlayerSkill([]), equals(SkillLevel.beginner));
    });

    test('currentConfig returns base configuration initially', () {
      final config = engine.currentConfig;
      expect(config.speedMultiplier, equals(1.0));
      expect(config.densityMultiplier, equals(1.0));
      expect(config.safeWindowPx, equals(180.0));
    });

    test('currentSkillLevel returns beginner initially', () {
      expect(engine.currentSkillLevel, equals(SkillLevel.beginner));
    });
  });
}