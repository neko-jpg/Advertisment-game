import 'dart:convert';
import 'package:flutter/material.dart';

/// Visual themes available in the game
enum VisualTheme {
  classic,
  neon,
  japanese,
  space;

  String get displayName {
    switch (this) {
      case VisualTheme.classic:
        return 'Classic';
      case VisualTheme.neon:
        return 'Neon';
      case VisualTheme.japanese:
        return '和風 (Japanese)';
      case VisualTheme.space:
        return 'Space';
    }
  }

  String get description {
    switch (this) {
      case VisualTheme.classic:
        return 'The original game theme';
      case VisualTheme.neon:
        return 'Bright neon colors and cyberpunk vibes';
      case VisualTheme.japanese:
        return 'Traditional Japanese aesthetic';
      case VisualTheme.space:
        return 'Cosmic space adventure theme';
    }
  }

  /// Number of plays required to unlock this theme
  int get unlockRequirement {
    switch (this) {
      case VisualTheme.classic:
        return 0; // Always unlocked
      case VisualTheme.neon:
        return 25; // Unlock after 25 plays
      case VisualTheme.japanese:
        return 50; // Unlock after 50 plays
      case VisualTheme.space:
        return 100; // Unlock after 100 plays
    }
  }

  /// Color scheme for the theme
  ThemeColorScheme get colorScheme {
    switch (this) {
      case VisualTheme.classic:
        return ThemeColorScheme(
          primary: Colors.blue,
          secondary: Colors.orange,
          background: Colors.white,
          accent: Colors.green,
        );
      case VisualTheme.neon:
        return ThemeColorScheme(
          primary: const Color(0xFF00FFFF), // Cyan
          secondary: const Color(0xFFFF00FF), // Magenta
          background: const Color(0xFF0A0A0A), // Dark
          accent: const Color(0xFF00FF00), // Lime
        );
      case VisualTheme.japanese:
        return ThemeColorScheme(
          primary: const Color(0xFFDC143C), // Crimson
          secondary: const Color(0xFFFFD700), // Gold
          background: const Color(0xFFF5F5DC), // Beige
          accent: const Color(0xFF8B4513), // Saddle Brown
        );
      case VisualTheme.space:
        return ThemeColorScheme(
          primary: const Color(0xFF4B0082), // Indigo
          secondary: const Color(0xFFFFFFFF), // White
          background: const Color(0xFF000000), // Black
          accent: const Color(0xFF9370DB), // Medium Purple
        );
    }
  }
}

/// Color scheme for a visual theme
class ThemeColorScheme {
  const ThemeColorScheme({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color background;
  final Color accent;
}

/// Player's theme preferences and unlock status
class ThemePreferences {
  ThemePreferences({
    this.selectedTheme = VisualTheme.classic,
    Set<VisualTheme>? unlockedThemes,
    this.autoSwitchEnabled = false,
    List<VisualTheme>? personalizedRecommendations,
  }) : unlockedThemes = unlockedThemes ?? {VisualTheme.classic},
       personalizedRecommendations = personalizedRecommendations ?? [];

  VisualTheme selectedTheme;
  final Set<VisualTheme> unlockedThemes;
  bool autoSwitchEnabled;
  final List<VisualTheme> personalizedRecommendations;

  Map<String, dynamic> toJson() {
    return {
      'selectedTheme': selectedTheme.index,
      'unlockedThemes': unlockedThemes.map((t) => t.index).toList(),
      'autoSwitchEnabled': autoSwitchEnabled,
      'personalizedRecommendations': personalizedRecommendations.map((t) => t.index).toList(),
    };
  }

  static ThemePreferences fromJson(Map<String, dynamic> json) {
    return ThemePreferences(
      selectedTheme: VisualTheme.values[json['selectedTheme'] as int? ?? 0],
      unlockedThemes: (json['unlockedThemes'] as List<dynamic>? ?? [0])
          .map((index) => VisualTheme.values[index as int])
          .toSet(),
      autoSwitchEnabled: json['autoSwitchEnabled'] as bool? ?? false,
      personalizedRecommendations: (json['personalizedRecommendations'] as List<dynamic>? ?? [])
          .map((index) => VisualTheme.values[index as int])
          .toList(),
    );
  }
}

/// Drawing tools available in the game
enum DrawingTool {
  basic,
  rainbow,
  glowing,
  sparkle,
  fire,
  ice;

  String get displayName {
    switch (this) {
      case DrawingTool.basic:
        return 'Basic Pen';
      case DrawingTool.rainbow:
        return 'Rainbow Pen';
      case DrawingTool.glowing:
        return 'Glowing Pen';
      case DrawingTool.sparkle:
        return 'Sparkle Pen';
      case DrawingTool.fire:
        return 'Fire Pen';
      case DrawingTool.ice:
        return 'Ice Pen';
    }
  }

  String get description {
    switch (this) {
      case DrawingTool.basic:
        return 'Standard drawing tool';
      case DrawingTool.rainbow:
        return 'Creates colorful rainbow lines';
      case DrawingTool.glowing:
        return 'Lines that glow with energy';
      case DrawingTool.sparkle:
        return 'Sparkling magical lines';
      case DrawingTool.fire:
        return 'Fiery lines that burn bright';
      case DrawingTool.ice:
        return 'Cool icy crystalline lines';
    }
  }

  /// Skill level required to unlock this tool
  int get skillRequirement {
    switch (this) {
      case DrawingTool.basic:
        return 0; // Always unlocked
      case DrawingTool.rainbow:
        return 10; // Skill level 10
      case DrawingTool.glowing:
        return 25; // Skill level 25
      case DrawingTool.sparkle:
        return 50; // Skill level 50
      case DrawingTool.fire:
        return 75; // Skill level 75
      case DrawingTool.ice:
        return 100; // Skill level 100
    }
  }
}

/// Player's drawing tool preferences and unlock status
class DrawingToolPreferences {
  DrawingToolPreferences({
    this.selectedTool = DrawingTool.basic,
    Set<DrawingTool>? unlockedTools,
  }) : unlockedTools = unlockedTools ?? {DrawingTool.basic};

  DrawingTool selectedTool;
  final Set<DrawingTool> unlockedTools;

  Map<String, dynamic> toJson() {
    return {
      'selectedTool': selectedTool.index,
      'unlockedTools': unlockedTools.map((t) => t.index).toList(),
    };
  }

  static DrawingToolPreferences fromJson(Map<String, dynamic> json) {
    return DrawingToolPreferences(
      selectedTool: DrawingTool.values[json['selectedTool'] as int? ?? 0],
      unlockedTools: (json['unlockedTools'] as List<dynamic>? ?? [0])
          .map((index) => DrawingTool.values[index as int])
          .toSet(),
    );
  }
}

/// Content variation state tracking
class ContentVariationState {
  ContentVariationState({
    this.totalPlays = 0,
    this.currentSkillLevel = 0,
    ThemePreferences? themePreferences,
    DrawingToolPreferences? drawingToolPreferences,
    DateTime? lastThemeSwitch,
    Map<VisualTheme, int>? themeUsageStats,
  }) : themePreferences = themePreferences ?? ThemePreferences(),
       drawingToolPreferences = drawingToolPreferences ?? DrawingToolPreferences(),
       lastThemeSwitch = lastThemeSwitch ?? DateTime.now(),
       themeUsageStats = themeUsageStats ?? {};

  int totalPlays;
  int currentSkillLevel;
  final ThemePreferences themePreferences;
  final DrawingToolPreferences drawingToolPreferences;
  DateTime lastThemeSwitch;
  final Map<VisualTheme, int> themeUsageStats;

  Map<String, dynamic> toJson() {
    return {
      'totalPlays': totalPlays,
      'currentSkillLevel': currentSkillLevel,
      'themePreferences': themePreferences.toJson(),
      'drawingToolPreferences': drawingToolPreferences.toJson(),
      'lastThemeSwitch': lastThemeSwitch.toIso8601String(),
      'themeUsageStats': themeUsageStats.map((k, v) => MapEntry(k.index.toString(), v)),
    };
  }

  static ContentVariationState fromJson(Map<String, dynamic> json) {
    final themeUsageMap = <VisualTheme, int>{};
    final usageStats = json['themeUsageStats'] as Map<String, dynamic>? ?? {};
    for (final entry in usageStats.entries) {
      final themeIndex = int.tryParse(entry.key);
      if (themeIndex != null && themeIndex < VisualTheme.values.length) {
        themeUsageMap[VisualTheme.values[themeIndex]] = entry.value as int;
      }
    }

    return ContentVariationState(
      totalPlays: json['totalPlays'] as int? ?? 0,
      currentSkillLevel: json['currentSkillLevel'] as int? ?? 0,
      themePreferences: ThemePreferences.fromJson(
        json['themePreferences'] as Map<String, dynamic>? ?? {},
      ),
      drawingToolPreferences: DrawingToolPreferences.fromJson(
        json['drawingToolPreferences'] as Map<String, dynamic>? ?? {},
      ),
      lastThemeSwitch: DateTime.tryParse(json['lastThemeSwitch'] as String? ?? '') ?? DateTime.now(),
      themeUsageStats: themeUsageMap,
    );
  }
}