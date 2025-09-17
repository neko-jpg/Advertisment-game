import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_models.dart';
import '../content_variation_engine.dart';

/// Service for persisting and loading content variation data
class ContentVariationService {
  static const String _stateKey = 'content_variation_state';
  
  ContentVariationEngine? _engine;
  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Set the content variation engine
  void setEngine(ContentVariationEngine engine) {
    _engine = engine;
  }

  /// Load saved content variation state
  Future<ContentVariationState?> loadState() async {
    if (_prefs == null) await initialize();
    
    final stateJson = _prefs!.getString(_stateKey);
    if (stateJson == null) return null;

    try {
      final stateMap = json.decode(stateJson) as Map<String, dynamic>;
      return ContentVariationState.fromJson(stateMap);
    } catch (e) {
      // If there's an error loading the state, return null to use defaults
      return null;
    }
  }

  /// Save current content variation state
  Future<void> saveState(ContentVariationState state) async {
    if (_prefs == null) await initialize();
    
    try {
      final stateJson = json.encode(state.toJson());
      await _prefs!.setString(_stateKey, stateJson);
    } catch (e) {
      // Handle save errors gracefully
      print('Error saving content variation state: $e');
    }
  }

  /// Auto-save when engine state changes
  void setupAutoSave() {
    if (_engine != null) {
      // The engine will call onStateChanged when state updates
      // We can save the state in response to those changes
      saveState(_engine!.state);
    }
  }

  /// Clear all saved data (for testing or reset purposes)
  Future<void> clearState() async {
    if (_prefs == null) await initialize();
    await _prefs!.remove(_stateKey);
  }

  /// Get theme unlock notifications that should be shown to the user
  List<String> getThemeUnlockNotifications(ContentVariationState state) {
    final notifications = <String>[];
    
    for (final theme in state.themePreferences.unlockedThemes) {
      if (theme != VisualTheme.classic) {
        // Check if this is a recent unlock (within last few plays)
        final progress = state.totalPlays / theme.unlockRequirement;
        if (progress >= 1.0 && progress < 1.2) { // Recently unlocked
          notifications.add('New theme unlocked: ${theme.displayName}!');
        }
      }
    }
    
    return notifications;
  }

  /// Get drawing tool unlock notifications
  List<String> getToolUnlockNotifications(ContentVariationState state) {
    final notifications = <String>[];
    
    for (final tool in state.drawingToolPreferences.unlockedTools) {
      if (tool != DrawingTool.basic) {
        // Check if this is a recent unlock
        final progress = state.currentSkillLevel / tool.skillRequirement;
        if (progress >= 1.0 && progress < 1.2) { // Recently unlocked
          notifications.add('New drawing tool unlocked: ${tool.displayName}!');
        }
      }
    }
    
    return notifications;
  }

  /// Get personalized theme recommendations
  List<VisualTheme> getPersonalizedThemeRecommendations(ContentVariationState state) {
    return state.themePreferences.personalizedRecommendations;
  }

  /// Update theme preferences
  Future<void> updateThemePreferences({
    VisualTheme? selectedTheme,
    bool? autoSwitchEnabled,
  }) async {
    if (_engine == null) return;

    if (selectedTheme != null) {
      _engine!.selectTheme(selectedTheme);
    }

    if (autoSwitchEnabled != null) {
      _engine!.setAutoSwitchEnabled(autoSwitchEnabled);
    }

    await saveState(_engine!.state);
  }

  /// Update drawing tool preferences
  Future<void> updateDrawingToolPreferences({
    DrawingTool? selectedTool,
  }) async {
    if (_engine == null) return;

    if (selectedTool != null) {
      _engine!.selectDrawingTool(selectedTool);
    }

    await saveState(_engine!.state);
  }
}