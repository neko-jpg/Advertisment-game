/// Visual guide and haptic feedback system for onboarding
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'models/onboarding_models.dart';
import '../core/analytics/analytics_service.dart';

/// Manages visual guides and haptic feedback during onboarding
class VisualGuideSystem extends ChangeNotifier {
  VisualGuideSystem({
    required AnalyticsService analytics,
  }) : _analytics = analytics;

  final AnalyticsService _analytics;
  
  VisualGuide? _currentGuide;
  Timer? _guideTimer;
  Timer? _confusionTimer;
  bool _isConfused = false;
  int _helpShownCount = 0;
  DateTime? _lastInteraction;

  // Progress tracking
  final Map<String, double> _skillProgress = {};
  final List<String> _achievements = [];

  // Getters
  VisualGuide? get currentGuide => _currentGuide;
  bool get isConfused => _isConfused;
  Map<String, double> get skillProgress => Map.unmodifiable(_skillProgress);
  List<String> get achievements => List.unmodifiable(_achievements);

  /// Show a visual guide at the specified position
  Future<void> showGuide({
    required GuideType type,
    required Offset position,
    required String message,
    Duration duration = const Duration(seconds: 3),
    bool useHaptic = true,
    bool animated = true,
  }) async {
    _currentGuide = VisualGuide(
      type: type,
      position: position,
      message: message,
      duration: duration,
      useHaptic: useHaptic,
      animated: animated,
    );

    // Provide haptic feedback based on guide type
    if (useHaptic) {
      await _provideHapticFeedback(type);
    }

    // Track guide shown
    await _analytics.trackEvent('visual_guide_shown', parameters: {
      'type': type.name,
      'message': message,
      'help_count': _helpShownCount,
    });

    _helpShownCount++;

    // Auto-hide guide after duration
    _guideTimer?.cancel();
    _guideTimer = Timer(duration, () {
      hideGuide();
    });

    notifyListeners();
  }

  /// Hide the current visual guide
  void hideGuide() {
    if (_currentGuide == null) return;

    _currentGuide = null;
    _guideTimer?.cancel();
    notifyListeners();
  }

  /// Record user interaction to detect confusion
  void recordInteraction(String action, {bool successful = false}) {
    _lastInteraction = DateTime.now();
    
    // Reset confusion state on successful interaction
    if (successful && _isConfused) {
      _isConfused = false;
      _confusionTimer?.cancel();
      notifyListeners();
    }

    // Update skill progress
    _updateSkillProgress(action, successful);

    // Start confusion detection timer
    _startConfusionDetection();
  }

  /// Start confusion detection timer
  void _startConfusionDetection() {
    _confusionTimer?.cancel();
    _confusionTimer = Timer(const Duration(seconds: 8), () {
      if (!_isConfused) {
        _detectConfusion();
      }
    });
  }

  /// Detect if user is confused and needs help
  void _detectConfusion() {
    final now = DateTime.now();
    final timeSinceLastInteraction = _lastInteraction != null 
        ? now.difference(_lastInteraction!).inSeconds 
        : 0;

    // User is confused if no interaction for 8+ seconds
    if (timeSinceLastInteraction >= 8) {
      _isConfused = true;
      _showAutoHelp();
      notifyListeners();
    }
  }

  /// Show automatic help when confusion is detected
  Future<void> _showAutoHelp() async {
    await _analytics.trackEvent('confusion_detected', parameters: {
      'help_count': _helpShownCount,
      'time_since_interaction': _lastInteraction != null 
          ? DateTime.now().difference(_lastInteraction!).inSeconds 
          : 0,
    });

    // Show contextual help based on current situation
    await showGuide(
      type: GuideType.highlight,
      position: const Offset(0.5, 0.5), // Center of screen
      message: 'Need help? Try tapping or drawing!',
      duration: const Duration(seconds: 5),
      useHaptic: true,
    );
  }

  /// Update skill progress based on user actions
  void _updateSkillProgress(String action, bool successful) {
    final currentProgress = _skillProgress[action] ?? 0.0;
    
    if (successful) {
      // Increase progress on success
      _skillProgress[action] = math.min(1.0, currentProgress + 0.2);
      
      // Check for achievements
      _checkAchievements(action);
    } else {
      // Slight decrease on failure, but never below 0
      _skillProgress[action] = math.max(0.0, currentProgress - 0.05);
    }
  }

  /// Check and award achievements
  void _checkAchievements(String action) {
    final progress = _skillProgress[action] ?? 0.0;
    
    // Award achievement at 50% progress
    if (progress >= 0.5 && !_achievements.contains('${action}_learner')) {
      _achievements.add('${action}_learner');
      _showAchievementEffect('${action}_learner');
    }
    
    // Award mastery achievement at 100% progress
    if (progress >= 1.0 && !_achievements.contains('${action}_master')) {
      _achievements.add('${action}_master');
      _showAchievementEffect('${action}_master');
    }
  }

  /// Show achievement effect
  Future<void> _showAchievementEffect(String achievement) async {
    await HapticFeedback.mediumImpact();
    
    await _analytics.trackEvent('achievement_unlocked', parameters: {
      'achievement': achievement,
    });

    // Show achievement guide
    await showGuide(
      type: GuideType.highlight,
      position: const Offset(0.5, 0.3),
      message: 'Achievement unlocked: ${_getAchievementName(achievement)}!',
      duration: const Duration(seconds: 2),
      useHaptic: false, // Already provided haptic above
    );
  }

  /// Get user-friendly achievement name
  String _getAchievementName(String achievement) {
    switch (achievement) {
      case 'jump_learner':
        return 'Jump Learner';
      case 'jump_master':
        return 'Jump Master';
      case 'draw_learner':
        return 'Draw Learner';
      case 'draw_master':
        return 'Draw Master';
      case 'collect_learner':
        return 'Coin Collector';
      case 'collect_master':
        return 'Coin Master';
      default:
        return achievement.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Provide haptic feedback based on guide type
  Future<void> _provideHapticFeedback(GuideType type) async {
    switch (type) {
      case GuideType.tap:
        await HapticFeedback.lightImpact();
        break;
      case GuideType.hold:
        await HapticFeedback.mediumImpact();
        break;
      case GuideType.swipe:
        await HapticFeedback.lightImpact();
        // Follow up with another impact after delay
        Timer(const Duration(milliseconds: 200), () {
          HapticFeedback.lightImpact();
        });
        break;
      case GuideType.draw:
        await HapticFeedback.mediumImpact();
        break;
      case GuideType.highlight:
        await HapticFeedback.selectionClick();
        break;
    }
  }

  /// Get progress visualization data
  Map<String, dynamic> getProgressVisualization() {
    final totalProgress = _skillProgress.values.isEmpty 
        ? 0.0 
        : _skillProgress.values.reduce((a, b) => a + b) / _skillProgress.length;
    
    return {
      'overall_progress': totalProgress,
      'skill_breakdown': Map.from(_skillProgress),
      'achievements_count': _achievements.length,
      'help_shown_count': _helpShownCount,
      'is_confused': _isConfused,
    };
  }

  /// Show progress celebration effect
  Future<void> showProgressCelebration(double newProgress) async {
    await HapticFeedback.heavyImpact();
    
    await showGuide(
      type: GuideType.highlight,
      position: const Offset(0.5, 0.4),
      message: 'Great progress! ${(newProgress * 100).toInt()}% mastered!',
      duration: const Duration(seconds: 2),
      useHaptic: false,
    );
  }

  /// Get contextual hint based on current situation
  String getContextualHint(String currentAction) {
    final progress = _skillProgress[currentAction] ?? 0.0;
    
    if (progress < 0.3) {
      return _getBeginnerHint(currentAction);
    } else if (progress < 0.7) {
      return _getIntermediateHint(currentAction);
    } else {
      return _getAdvancedHint(currentAction);
    }
  }

  String _getBeginnerHint(String action) {
    switch (action) {
      case 'jump':
        return 'Tap anywhere on the screen to jump';
      case 'draw':
        return 'Hold and drag your finger to draw a line';
      case 'collect':
        return 'Touch the golden coins to collect them';
      default:
        return 'Try different gestures to learn!';
    }
  }

  String _getIntermediateHint(String action) {
    switch (action) {
      case 'jump':
        return 'Time your jumps to clear obstacles';
      case 'draw':
        return 'Draw platforms to reach higher areas';
      case 'collect':
        return 'Plan your path to collect all coins';
      default:
        return 'You\'re getting better! Keep practicing!';
    }
  }

  String _getAdvancedHint(String action) {
    switch (action) {
      case 'jump':
        return 'Master precise timing for perfect jumps';
      case 'draw':
        return 'Create strategic platforms for optimal paths';
      case 'collect':
        return 'Maximize coin collection with efficient routes';
      default:
        return 'Excellent skills! Try advanced techniques!';
    }
  }

  /// Reset the visual guide system
  void reset() {
    _currentGuide = null;
    _isConfused = false;
    _helpShownCount = 0;
    _lastInteraction = null;
    _skillProgress.clear();
    _achievements.clear();
    
    _guideTimer?.cancel();
    _confusionTimer?.cancel();
    
    notifyListeners();
  }

  @override
  void dispose() {
    _guideTimer?.cancel();
    _confusionTimer?.cancel();
    super.dispose();
  }
}