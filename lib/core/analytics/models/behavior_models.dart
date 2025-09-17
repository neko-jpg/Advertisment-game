import 'dart:convert';

/// Represents a single user action within the game
class GameAction {
  const GameAction({
    required this.type,
    required this.timestamp,
    required this.sessionId,
    this.metadata = const {},
  });

  final GameActionType type;
  final DateTime timestamp;
  final String sessionId;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'metadata': metadata,
    };
  }

  static GameAction fromJson(Map<String, dynamic> json) {
    return GameAction(
      type: GameActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GameActionType.unknown,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionId: json['sessionId'] as String,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}

/// Types of actions that can be tracked in the game
enum GameActionType {
  gameStart,
  gameEnd,
  jump,
  draw,
  coinCollect,
  adView,
  purchase,
  menuOpen,
  settingsChange,
  tutorialStep,
  reviveUsed,
  missionComplete,
  upgradeUnlock,
  socialShare,
  unknown,
}

/// Comprehensive user session data
class UserSession {
  const UserSession({
    required this.sessionId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.actions,
    required this.deviceInfo,
    this.crashOccurred = false,
  });

  final String sessionId;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<GameAction> actions;
  final DeviceInfo deviceInfo;
  final bool crashOccurred;

  Duration get duration => 
      endTime?.difference(startTime) ?? DateTime.now().difference(startTime);

  int get actionCount => actions.length;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'deviceInfo': deviceInfo.toJson(),
      'crashOccurred': crashOccurred,
    };
  }

  static UserSession fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
      actions: (json['actions'] as List<dynamic>)
          .map((a) => GameAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      deviceInfo: DeviceInfo.fromJson(json['deviceInfo'] as Map<String, dynamic>),
      crashOccurred: json['crashOccurred'] as bool? ?? false,
    );
  }
}

/// Device information for context
class DeviceInfo {
  const DeviceInfo({
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.screenSize,
    required this.locale,
  });

  final String platform;
  final String osVersion;
  final String appVersion;
  final String screenSize;
  final String locale;

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'screenSize': screenSize,
      'locale': locale,
    };
  }

  static DeviceInfo fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      platform: json['platform'] as String,
      osVersion: json['osVersion'] as String,
      appVersion: json['appVersion'] as String,
      screenSize: json['screenSize'] as String,
      locale: json['locale'] as String,
    );
  }
}

/// Analyzed behavior pattern for a user
class BehaviorPattern {
  const BehaviorPattern({
    required this.userId,
    required this.averageSessionLength,
    required this.dailyPlayFrequency,
    required this.commonActions,
    required this.featureUsageRates,
    required this.playTimeDistribution,
    required this.retentionIndicators,
    required this.lastUpdated,
  });

  final String userId;
  final Duration averageSessionLength;
  final double dailyPlayFrequency;
  final Map<GameActionType, int> commonActions;
  final Map<String, double> featureUsageRates;
  final Map<int, double> playTimeDistribution; // hour -> frequency
  final RetentionIndicators retentionIndicators;
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'averageSessionLength': averageSessionLength.inMilliseconds,
      'dailyPlayFrequency': dailyPlayFrequency,
      'commonActions': commonActions.map((k, v) => MapEntry(k.name, v)),
      'featureUsageRates': featureUsageRates,
      'playTimeDistribution': playTimeDistribution.map((k, v) => MapEntry(k.toString(), v)),
      'retentionIndicators': retentionIndicators.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  static BehaviorPattern fromJson(Map<String, dynamic> json) {
    return BehaviorPattern(
      userId: json['userId'] as String,
      averageSessionLength: Duration(milliseconds: json['averageSessionLength'] as int),
      dailyPlayFrequency: (json['dailyPlayFrequency'] as num).toDouble(),
      commonActions: (json['commonActions'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(
          GameActionType.values.firstWhere((e) => e.name == k, orElse: () => GameActionType.unknown),
          v as int,
        ),
      ),
      featureUsageRates: Map<String, double>.from(json['featureUsageRates'] as Map),
      playTimeDistribution: (json['playTimeDistribution'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), (v as num).toDouble()),
      ),
      retentionIndicators: RetentionIndicators.fromJson(json['retentionIndicators'] as Map<String, dynamic>),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}

/// Indicators that help predict user retention
class RetentionIndicators {
  const RetentionIndicators({
    required this.sessionConsistency,
    required this.progressionRate,
    required this.socialEngagement,
    required this.monetizationEngagement,
    required this.tutorialCompletion,
    required this.daysSinceLastPlay,
  });

  final double sessionConsistency; // 0-1, how consistent are play sessions
  final double progressionRate; // 0-1, how fast user progresses
  final double socialEngagement; // 0-1, social feature usage
  final double monetizationEngagement; // 0-1, ad/purchase engagement
  final double tutorialCompletion; // 0-1, tutorial completion rate
  final int daysSinceLastPlay;

  Map<String, dynamic> toJson() {
    return {
      'sessionConsistency': sessionConsistency,
      'progressionRate': progressionRate,
      'socialEngagement': socialEngagement,
      'monetizationEngagement': monetizationEngagement,
      'tutorialCompletion': tutorialCompletion,
      'daysSinceLastPlay': daysSinceLastPlay,
    };
  }

  static RetentionIndicators fromJson(Map<String, dynamic> json) {
    return RetentionIndicators(
      sessionConsistency: (json['sessionConsistency'] as num).toDouble(),
      progressionRate: (json['progressionRate'] as num).toDouble(),
      socialEngagement: (json['socialEngagement'] as num).toDouble(),
      monetizationEngagement: (json['monetizationEngagement'] as num).toDouble(),
      tutorialCompletion: (json['tutorialCompletion'] as num).toDouble(),
      daysSinceLastPlay: json['daysSinceLastPlay'] as int,
    );
  }
}

/// Churn risk assessment
class ChurnRisk {
  const ChurnRisk({
    required this.riskLevel,
    required this.probability,
    required this.primaryFactors,
    required this.recommendedActions,
  });

  final ChurnRiskLevel riskLevel;
  final double probability; // 0-1
  final List<String> primaryFactors;
  final List<String> recommendedActions;

  Map<String, dynamic> toJson() {
    return {
      'riskLevel': riskLevel.name,
      'probability': probability,
      'primaryFactors': primaryFactors,
      'recommendedActions': recommendedActions,
    };
  }

  static ChurnRisk fromJson(Map<String, dynamic> json) {
    return ChurnRisk(
      riskLevel: ChurnRiskLevel.values.firstWhere(
        (e) => e.name == json['riskLevel'],
        orElse: () => ChurnRiskLevel.low,
      ),
      probability: (json['probability'] as num).toDouble(),
      primaryFactors: List<String>.from(json['primaryFactors'] as List),
      recommendedActions: List<String>.from(json['recommendedActions'] as List),
    );
  }
}

enum ChurnRiskLevel { low, medium, high, critical }

/// User behavior data for analysis
class UserBehaviorData {
  const UserBehaviorData({
    required this.userId,
    required this.sessions,
    required this.totalPlayTime,
    required this.averageScore,
    required this.purchaseHistory,
    required this.adInteractions,
    required this.socialActions,
    required this.lastActiveDate,
  });

  final String userId;
  final List<UserSession> sessions;
  final Duration totalPlayTime;
  final double averageScore;
  final List<Map<String, dynamic>> purchaseHistory;
  final List<Map<String, dynamic>> adInteractions;
  final List<Map<String, dynamic>> socialActions;
  final DateTime lastActiveDate;

  int get daysSinceLastActive => DateTime.now().difference(lastActiveDate).inDays;
  int get totalSessions => sessions.length;
  Duration get averageSessionLength => totalSessions > 0 
      ? Duration(milliseconds: totalPlayTime.inMilliseconds ~/ totalSessions)
      : Duration.zero;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'totalPlayTime': totalPlayTime.inMilliseconds,
      'averageScore': averageScore,
      'purchaseHistory': purchaseHistory,
      'adInteractions': adInteractions,
      'socialActions': socialActions,
      'lastActiveDate': lastActiveDate.toIso8601String(),
    };
  }

  static UserBehaviorData fromJson(Map<String, dynamic> json) {
    return UserBehaviorData(
      userId: json['userId'] as String,
      sessions: (json['sessions'] as List<dynamic>)
          .map((s) => UserSession.fromJson(s as Map<String, dynamic>))
          .toList(),
      totalPlayTime: Duration(milliseconds: json['totalPlayTime'] as int),
      averageScore: (json['averageScore'] as num).toDouble(),
      purchaseHistory: List<Map<String, dynamic>>.from(json['purchaseHistory'] as List),
      adInteractions: List<Map<String, dynamic>>.from(json['adInteractions'] as List),
      socialActions: List<Map<String, dynamic>>.from(json['socialActions'] as List),
      lastActiveDate: DateTime.parse(json['lastActiveDate'] as String),
    );
  }
}