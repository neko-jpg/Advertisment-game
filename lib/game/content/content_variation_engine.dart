import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models/content_models.dart';
import '../models/game_models.dart';

/// Engine responsible for managing content variation, theme switching, and tool unlocking
class ContentVariationEngine {
  ContentVariationEngine({
    required this.onStateChanged,
  });

  final VoidCallback onStateChanged;
  ContentVariationState _state = ContentVariationState();

  /// Current content variation state
  ContentVariationState get state => _state;

  /// Initialize the engine with saved state
  void initialize(ContentVariationState? savedState) {
    _state = savedState ?? ContentVariationState();
    _checkForNewUnlocks();
    onStateChanged();
  }

  /// Update play count and check for theme unlocks
  void onGameCompleted(RunStats runStats) {
    _state.totalPlays++;
    _updateThemeUsageStats();
    _checkForThemeUnlocks();
    _updatePersonalizedRecommendations();
    
    // Auto-switch theme if enabled and conditions are met
    if (_state.themePreferences.autoSwitchEnabled) {
      _considerAutoThemeSwitch();
    }
    
    onStateChanged();
  }

  /// Update skill level and check for tool unlocks
  void onSkillLevelChanged(int newSkillLevel) {
    _state.currentSkillLevel = newSkillLevel;
    _checkForToolUnlocks();
    onStateChanged();
  }

  /// Select optimal theme based on user preferences and play patterns
  VisualTheme selectOptimalTheme() {
    if (!_state.themePreferences.autoSwitchEnabled) {
      return _state.themePreferences.selectedTheme;
    }

    // Check if it's time for a theme switch (every 5 plays minimum)
    final playsSinceLastSwitch = _state.totalPlays % 5;
    if (playsSinceLastSwitch != 0) {
      return _state.themePreferences.selectedTheme;
    }

    // Get personalized recommendations
    final recommendations = _state.themePreferences.personalizedRecommendations;
    if (recommendations.isNotEmpty) {
      // Select from recommendations based on usage stats
      final leastUsedRecommendation = _getLeastUsedTheme(recommendations);
      if (leastUsedRecommendation != null) {
        return leastUsedRecommendation;
      }
    }

    // Fallback to least used unlocked theme
    return _getLeastUsedTheme(_state.themePreferences.unlockedThemes.toList()) 
        ?? _state.themePreferences.selectedTheme;
  }

  /// Manually select a theme
  void selectTheme(VisualTheme theme) {
    if (_state.themePreferences.unlockedThemes.contains(theme)) {
      _state.themePreferences.selectedTheme = theme;
      _state.lastThemeSwitch = DateTime.now();
      onStateChanged();
    }
  }

  /// Toggle auto-switch functionality
  void setAutoSwitchEnabled(bool enabled) {
    _state.themePreferences.autoSwitchEnabled = enabled;
    onStateChanged();
  }

  /// Select a drawing tool
  void selectDrawingTool(DrawingTool tool) {
    if (_state.drawingToolPreferences.unlockedTools.contains(tool)) {
      _state.drawingToolPreferences.selectedTool = tool;
      onStateChanged();
    }
  }

  /// Get list of unlockable themes based on current progress
  List<VisualTheme> getUnlockableThemes() {
    return VisualTheme.values
        .where((theme) => 
            !_state.themePreferences.unlockedThemes.contains(theme) &&
            _state.totalPlays >= theme.unlockRequirement)
        .toList();
  }

  /// Get list of unlockable drawing tools based on current skill level
  List<DrawingTool> getUnlockableTools() {
    return DrawingTool.values
        .where((tool) => 
            !_state.drawingToolPreferences.unlockedTools.contains(tool) &&
            _state.currentSkillLevel >= tool.skillRequirement)
        .toList();
  }

  /// Check if a specific theme is unlocked
  bool isThemeUnlocked(VisualTheme theme) {
    return _state.themePreferences.unlockedThemes.contains(theme);
  }

  /// Check if a specific drawing tool is unlocked
  bool isDrawingToolUnlocked(DrawingTool tool) {
    return _state.drawingToolPreferences.unlockedTools.contains(tool);
  }

  /// Get progress towards unlocking a theme (0.0 to 1.0)
  double getThemeUnlockProgress(VisualTheme theme) {
    if (isThemeUnlocked(theme)) return 1.0;
    return (_state.totalPlays / theme.unlockRequirement).clamp(0.0, 1.0);
  }

  /// Get progress towards unlocking a drawing tool (0.0 to 1.0)
  double getToolUnlockProgress(DrawingTool tool) {
    if (isDrawingToolUnlocked(tool)) return 1.0;
    return (_state.currentSkillLevel / tool.skillRequirement).clamp(0.0, 1.0);
  }

  /// Private methods

  void _checkForThemeUnlocks() {
    final unlockableThemes = getUnlockableThemes();
    for (final theme in unlockableThemes) {
      _state.themePreferences.unlockedThemes.add(theme);
      debugPrint('Theme unlocked: ${theme.displayName}');
    }
  }

  void _checkForToolUnlocks() {
    final unlockableTools = getUnlockableTools();
    for (final tool in unlockableTools) {
      _state.drawingToolPreferences.unlockedTools.add(tool);
      debugPrint('Drawing tool unlocked: ${tool.displayName}');
    }
  }

  void _checkForNewUnlocks() {
    _checkForThemeUnlocks();
    _checkForToolUnlocks();
  }

  void _updateThemeUsageStats() {
    final currentTheme = _state.themePreferences.selectedTheme;
    _state.themeUsageStats[currentTheme] = 
        (_state.themeUsageStats[currentTheme] ?? 0) + 1;
  }

  void _updatePersonalizedRecommendations() {
    // Simple algorithm: recommend themes that are unlocked but underused
    final unlockedThemes = _state.themePreferences.unlockedThemes.toList();
    final averageUsage = _state.themeUsageStats.values.isEmpty 
        ? 0 
        : _state.themeUsageStats.values.reduce((a, b) => a + b) / _state.themeUsageStats.length;

    final underusedThemes = unlockedThemes
        .where((theme) => (_state.themeUsageStats[theme] ?? 0) < averageUsage)
        .toList();

    _state.themePreferences.personalizedRecommendations.clear();
    _state.themePreferences.personalizedRecommendations.addAll(underusedThemes);
  }

  void _considerAutoThemeSwitch() {
    // Switch theme every 5 plays if auto-switch is enabled
    if (_state.totalPlays % 5 == 0) {
      final newTheme = selectOptimalTheme();
      if (newTheme != _state.themePreferences.selectedTheme) {
        _state.themePreferences.selectedTheme = newTheme;
        _state.lastThemeSwitch = DateTime.now();
        debugPrint('Auto-switched to theme: ${newTheme.displayName}');
      }
    }
  }

  VisualTheme? _getLeastUsedTheme(List<VisualTheme> themes) {
    if (themes.isEmpty) return null;

    VisualTheme? leastUsed;
    int minUsage = double.maxFinite.toInt();

    for (final theme in themes) {
      final usage = _state.themeUsageStats[theme] ?? 0;
      if (usage < minUsage) {
        minUsage = usage;
        leastUsed = theme;
      }
    }

    return leastUsed;
  }

  /// Serialization methods

  Map<String, dynamic> toJson() {
    return _state.toJson();
  }

  void fromJson(Map<String, dynamic> json) {
    _state = ContentVariationState.fromJson(json);
    _checkForNewUnlocks();
    onStateChanged();
  }
}