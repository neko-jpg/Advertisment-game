import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/behavior_models.dart';
import 'player_behavior_analyzer.dart';
import '../../game/models/game_models.dart';

/// Service that tracks user behavior and integrates with the game
class BehaviorTrackingService {
  BehaviorTrackingService._({
    required PlayerBehaviorAnalyzer analyzer,
    required DeviceInfo deviceInfo,
  }) : _analyzer = analyzer, _deviceInfo = deviceInfo;

  static BehaviorTrackingService? _instance;
  
  final PlayerBehaviorAnalyzer _analyzer;
  final DeviceInfo _deviceInfo;
  UserSession? _currentSession;
  String? _currentUserId;

  /// Initialize the behavior tracking service
  static Future<BehaviorTrackingService> initialize() async {
    if (_instance != null) return _instance!;

    final prefs = await SharedPreferences.getInstance();
    final analyzer = PlayerBehaviorAnalyzer(prefs: prefs);
    final deviceInfo = await _getDeviceInfo();

    _instance = BehaviorTrackingService._(
      analyzer: analyzer,
      deviceInfo: deviceInfo,
    );

    return _instance!;
  }

  /// Get the singleton instance
  static BehaviorTrackingService get instance {
    if (_instance == null) {
      throw StateError('BehaviorTrackingService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  /// Start tracking for a user
  Future<void> startTracking(String userId) async {
    try {
      _currentUserId = userId;
      _currentSession = await _analyzer.startSession(userId, _deviceInfo);
      
      // Record session start
      await _recordAction(GameActionType.gameStart, {
        'session_start': true,
        'device_platform': _deviceInfo.platform,
      });
      
      debugPrint('Started behavior tracking for user: $userId');
    } catch (error, stackTrace) {
      debugPrint('Failed to start behavior tracking: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Stop tracking for current user
  Future<void> stopTracking() async {
    try {
      if (_currentSession != null) {
        await _recordAction(GameActionType.gameEnd, {
          'session_end': true,
          'session_duration': _currentSession!.duration.inSeconds,
        });
        
        await _analyzer.endSession(_currentSession!.sessionId);
        _currentSession = null;
      }
      _currentUserId = null;
      
      debugPrint('Stopped behavior tracking');
    } catch (error, stackTrace) {
      debugPrint('Failed to stop behavior tracking: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Record game start event
  Future<void> recordGameStart({
    required bool tutorialActive,
    required int revivesUnlocked,
    required double inkMultiplier,
    required int totalCoins,
    required bool missionsAvailable,
  }) async {
    await _recordAction(GameActionType.gameStart, {
      'tutorial_active': tutorialActive,
      'revives_unlocked': revivesUnlocked,
      'ink_multiplier': inkMultiplier,
      'total_coins': totalCoins,
      'missions_available': missionsAvailable,
    });
  }

  /// Record game end event
  Future<void> recordGameEnd({
    required RunStats stats,
    required int revivesUsed,
    required int totalCoins,
    required int missionsCompletedDelta,
  }) async {
    await _recordAction(GameActionType.gameEnd, {
      'score': stats.score,
      'duration_ms': stats.duration.inMilliseconds,
      'coins_gained': stats.coins,
      'jumps': stats.jumpsPerformed,
      'draw_time_ms': stats.drawTimeMs,
      'used_line': stats.usedLine,
      'accident_death': stats.accidentDeath,
      'revives_used': revivesUsed,
      'missions_completed_delta': missionsCompletedDelta,
      'total_coins': totalCoins,
    });
  }

  /// Record jump action
  Future<void> recordJump({
    required double jumpHeight,
    required bool successful,
  }) async {
    await _recordAction(GameActionType.jump, {
      'jump_height': jumpHeight,
      'successful': successful,
    });
  }

  /// Record drawing action
  Future<void> recordDraw({
    required int strokeCount,
    required double drawTime,
    required bool lineUsed,
  }) async {
    await _recordAction(GameActionType.draw, {
      'stroke_count': strokeCount,
      'draw_time': drawTime,
      'line_used': lineUsed,
    });
  }

  /// Record coin collection
  Future<void> recordCoinCollect({
    required int amount,
    required int totalCoins,
    String source = 'gameplay',
  }) async {
    await _recordAction(GameActionType.coinCollect, {
      'amount': amount,
      'total_coins': totalCoins,
      'source': source,
    });
  }

  /// Record ad view
  Future<void> recordAdView({
    required String placement,
    required String adType,
    required bool rewardEarned,
    required Duration watchTime,
  }) async {
    await _recordAction(GameActionType.adView, {
      'placement': placement,
      'ad_type': adType,
      'reward_earned': rewardEarned,
      'watch_time_ms': watchTime.inMilliseconds,
    });
  }

  /// Record purchase
  Future<void> recordPurchase({
    required String productId,
    required double price,
    required String currency,
    required bool successful,
  }) async {
    await _recordAction(GameActionType.purchase, {
      'product_id': productId,
      'price': price,
      'currency': currency,
      'successful': successful,
    });
  }

  /// Record menu navigation
  Future<void> recordMenuOpen({
    required String menuType,
    required String source,
  }) async {
    await _recordAction(GameActionType.menuOpen, {
      'menu_type': menuType,
      'source': source,
    });
  }

  /// Record settings change
  Future<void> recordSettingsChange({
    required String setting,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    await _recordAction(GameActionType.settingsChange, {
      'setting': setting,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }

  /// Record tutorial step completion
  Future<void> recordTutorialStep({
    required int stepNumber,
    required String stepName,
    required bool completed,
    required Duration timeSpent,
  }) async {
    await _recordAction(GameActionType.tutorialStep, {
      'step_number': stepNumber,
      'step_name': stepName,
      'completed': completed,
      'time_spent_ms': timeSpent.inMilliseconds,
    });
  }

  /// Record revive usage
  Future<void> recordReviveUsed({
    required String reviveType, // 'ad', 'coins', 'premium'
    required int cost,
    required int remainingRevives,
  }) async {
    await _recordAction(GameActionType.reviveUsed, {
      'revive_type': reviveType,
      'cost': cost,
      'remaining_revives': remainingRevives,
    });
  }

  /// Record mission completion
  Future<void> recordMissionComplete({
    required String missionId,
    required MissionType missionType,
    required int reward,
    required Duration timeToComplete,
  }) async {
    await _recordAction(GameActionType.missionComplete, {
      'mission_id': missionId,
      'mission_type': missionType.name,
      'reward': reward,
      'time_to_complete_ms': timeToComplete.inMilliseconds,
    });
  }

  /// Record upgrade unlock
  Future<void> recordUpgradeUnlock({
    required UpgradeType upgradeType,
    required int level,
    required int cost,
  }) async {
    await _recordAction(GameActionType.upgradeUnlock, {
      'upgrade_type': upgradeType.name,
      'level': level,
      'cost': cost,
    });
  }

  /// Record social share
  Future<void> recordSocialShare({
    required String platform,
    required String contentType,
    required bool successful,
  }) async {
    await _recordAction(GameActionType.socialShare, {
      'platform': platform,
      'content_type': contentType,
      'successful': successful,
    });
  }

  /// Get behavior pattern for current user
  Future<BehaviorPattern?> getCurrentUserBehaviorPattern() async {
    if (_currentUserId == null) return null;
    
    try {
      return await _analyzer.analyzeBehaviorPattern(_currentUserId!);
    } catch (error) {
      debugPrint('Failed to get behavior pattern: $error');
      return null;
    }
  }

  /// Get churn risk for current user
  Future<ChurnRisk?> getCurrentUserChurnRisk() async {
    if (_currentUserId == null) return null;
    
    try {
      return await _analyzer.predictChurnRisk(_currentUserId!);
    } catch (error) {
      debugPrint('Failed to get churn risk: $error');
      return null;
    }
  }

  /// Check if current user is at risk of churning
  Future<bool> isCurrentUserAtRisk() async {
    final churnRisk = await getCurrentUserChurnRisk();
    return churnRisk?.riskLevel == ChurnRiskLevel.high || 
           churnRisk?.riskLevel == ChurnRiskLevel.critical;
  }

  /// Clean up old tracking data
  Future<void> cleanupOldData() async {
    await _analyzer.cleanupOldData();
  }

  /// Record a generic action
  Future<void> _recordAction(GameActionType type, Map<String, dynamic> metadata) async {
    if (_currentSession == null || _currentUserId == null) {
      debugPrint('Cannot record action: no active session');
      return;
    }

    try {
      final action = GameAction(
        type: type,
        timestamp: DateTime.now(),
        sessionId: _currentSession!.sessionId,
        metadata: metadata,
      );

      await _analyzer.recordAction(action);
    } catch (error, stackTrace) {
      debugPrint('Failed to record action $type: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Get device information
  static Future<DeviceInfo> _getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      String platform = 'unknown';
      String osVersion = 'unknown';
      String screenSize = 'unknown';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        platform = 'android';
        osVersion = 'Android ${androidInfo.version.release}';
        screenSize = '${androidInfo.displayMetrics.widthPx}x${androidInfo.displayMetrics.heightPx}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        platform = 'ios';
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        screenSize = 'iOS Device'; // iOS doesn't provide screen size easily
      }

      return DeviceInfo(
        platform: platform,
        osVersion: osVersion,
        appVersion: packageInfo.version,
        screenSize: screenSize,
        locale: Platform.localeName,
      );
    } catch (error) {
      debugPrint('Failed to get device info: $error');
      return const DeviceInfo(
        platform: 'unknown',
        osVersion: 'unknown',
        appVersion: '1.0.0',
        screenSize: 'unknown',
        locale: 'en_US',
      );
    }
  }
}