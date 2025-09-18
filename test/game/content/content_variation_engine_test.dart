import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/game/content/content_variation_engine.dart';
import 'package:myapp/game/content/models/content_models.dart';
import 'package:myapp/game/models/game_models.dart';

void main() {
  group('ContentVariationEngine', () {
    late ContentVariationEngine engine;
    bool stateChanged = false;

    setUp(() {
      stateChanged = false;
      engine = ContentVariationEngine(
        onStateChanged: () => stateChanged = true,
      );
    });

    test('initializes with default state', () {
      expect(engine.state.totalPlays, equals(0));
      expect(engine.state.currentSkillLevel, equals(0));
      expect(engine.state.themePreferences.selectedTheme, equals(VisualTheme.classic));
      expect(engine.state.themePreferences.unlockedThemes, contains(VisualTheme.classic));
      expect(engine.state.drawingToolPreferences.selectedTool, equals(DrawingTool.basic));
      expect(engine.state.drawingToolPreferences.unlockedTools, contains(DrawingTool.basic));
    });

    test('unlocks themes based on play count', () {
      // Simulate 25 plays to unlock neon theme
      for (int i = 0; i < 25; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      expect(engine.state.totalPlays, equals(25));
      expect(engine.isThemeUnlocked(VisualTheme.neon), isTrue);
      expect(engine.isThemeUnlocked(VisualTheme.japanese), isFalse);
      expect(engine.isThemeUnlocked(VisualTheme.space), isFalse);
    });

    test('unlocks drawing tools based on skill level', () {
      // Set skill level to 25 to unlock glowing pen
      engine.onSkillLevelChanged(25);

      expect(engine.state.currentSkillLevel, equals(25));
      expect(engine.isDrawingToolUnlocked(DrawingTool.rainbow), isTrue);
      expect(engine.isDrawingToolUnlocked(DrawingTool.glowing), isTrue);
      expect(engine.isDrawingToolUnlocked(DrawingTool.sparkle), isFalse);
    });

    test('calculates unlock progress correctly', () {
      // Test theme unlock progress
      engine.onGameCompleted(const RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 10,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 1000,
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));

      expect(engine.getThemeUnlockProgress(VisualTheme.neon), equals(1.0 / 25.0));
      expect(engine.getThemeUnlockProgress(VisualTheme.classic), equals(1.0));

      // Test tool unlock progress
      engine.onSkillLevelChanged(5);
      expect(engine.getToolUnlockProgress(DrawingTool.rainbow), equals(5.0 / 10.0));
      expect(engine.getToolUnlockProgress(DrawingTool.basic), equals(1.0));
    });

    test('allows theme selection for unlocked themes', () {
      // Unlock neon theme
      for (int i = 0; i < 25; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      // Select neon theme
      engine.selectTheme(VisualTheme.neon);
      expect(engine.state.themePreferences.selectedTheme, equals(VisualTheme.neon));
      expect(stateChanged, isTrue);

      // Try to select locked theme (should not change)
      stateChanged = false;
      engine.selectTheme(VisualTheme.space);
      expect(engine.state.themePreferences.selectedTheme, equals(VisualTheme.neon));
    });

    test('allows drawing tool selection for unlocked tools', () {
      // Unlock rainbow tool
      engine.onSkillLevelChanged(10);

      // Select rainbow tool
      engine.selectDrawingTool(DrawingTool.rainbow);
      expect(engine.state.drawingToolPreferences.selectedTool, equals(DrawingTool.rainbow));
      expect(stateChanged, isTrue);

      // Try to select locked tool (should not change)
      stateChanged = false;
      engine.selectDrawingTool(DrawingTool.sparkle);
      expect(engine.state.drawingToolPreferences.selectedTool, equals(DrawingTool.rainbow));
    });

    test('auto-switch functionality works correctly', () {
      // Enable auto-switch
      engine.setAutoSwitchEnabled(true);
      expect(engine.state.themePreferences.autoSwitchEnabled, isTrue);

      // Unlock multiple themes
      for (int i = 0; i < 50; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      // Should have unlocked neon and japanese themes
      expect(engine.isThemeUnlocked(VisualTheme.neon), isTrue);
      expect(engine.isThemeUnlocked(VisualTheme.japanese), isTrue);

      // Auto-switch should occur every 5 plays
      final initialTheme = engine.state.themePreferences.selectedTheme;
      
      // Play 5 more times to trigger auto-switch
      for (int i = 0; i < 5; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      // Theme might have changed due to auto-switch
      final optimalTheme = engine.selectOptimalTheme();
      expect(engine.state.themePreferences.unlockedThemes.contains(optimalTheme), isTrue);
    });

    test('tracks theme usage statistics', () {
      // Unlock neon theme
      for (int i = 0; i < 25; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      // Classic theme should have usage stats
      expect(engine.state.themeUsageStats[VisualTheme.classic], equals(25));

      // Switch to neon and play more
      engine.selectTheme(VisualTheme.neon);
      for (int i = 0; i < 10; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      expect(engine.state.themeUsageStats[VisualTheme.neon], equals(10));
    });

    test('generates personalized recommendations', () {
      // Unlock multiple themes
      for (int i = 0; i < 50; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }

      // Should have recommendations for underused themes
      expect(engine.state.themePreferences.personalizedRecommendations.isNotEmpty, isTrue);
      
      // All recommendations should be unlocked themes
      for (final theme in engine.state.themePreferences.personalizedRecommendations) {
        expect(engine.isThemeUnlocked(theme), isTrue);
      }
    });

    test('serialization works correctly', () {
      // Set up some state
      engine.onSkillLevelChanged(25);
      for (int i = 0; i < 30; i++) {
        engine.onGameCompleted(const RunStats(
          duration: Duration(seconds: 30),
          score: 100,
          coins: 10,
          usedLine: true,
          jumpsPerformed: 5,
          drawTimeMs: 1000,
          accidentDeath: false,
          nearMisses: 0,
          inkEfficiency: 1.0,
        ));
      }
      engine.selectTheme(VisualTheme.neon);
      engine.selectDrawingTool(DrawingTool.rainbow);
      engine.setAutoSwitchEnabled(true);

      // Serialize and deserialize
      final json = engine.toJson();
      final newEngine = ContentVariationEngine(onStateChanged: () {});
      newEngine.fromJson(json);

      // Verify state is preserved
      expect(newEngine.state.totalPlays, equals(30));
      expect(newEngine.state.currentSkillLevel, equals(25));
      expect(newEngine.state.themePreferences.selectedTheme, equals(VisualTheme.neon));
      expect(newEngine.state.drawingToolPreferences.selectedTool, equals(DrawingTool.rainbow));
      expect(newEngine.state.themePreferences.autoSwitchEnabled, isTrue);
      expect(newEngine.isThemeUnlocked(VisualTheme.neon), isTrue);
      expect(newEngine.isDrawingToolUnlocked(DrawingTool.rainbow), isTrue);
    });

    test('handles edge cases gracefully', () {
      // Test with null/empty initialization
      engine.initialize(null);
      expect(engine.state.totalPlays, equals(0));

      // Test selecting themes/tools that don't exist (should not crash)
      engine.selectTheme(VisualTheme.space); // Not unlocked
      expect(engine.state.themePreferences.selectedTheme, equals(VisualTheme.classic));

      // Test with very high skill levels
      engine.onSkillLevelChanged(1000);
      expect(engine.isDrawingToolUnlocked(DrawingTool.ice), isTrue);
    });
  });
}
