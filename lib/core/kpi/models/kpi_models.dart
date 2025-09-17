/// KPI監視・緊急対応システムのデータモデル
/// 要件8.1, 8.2, 8.3, 8.4に対応

enum KPIType {
  cpi,        // Cost Per Install
  mau,        // Monthly Active Users
  arpu,       // Average Revenue Per User
  appRating,  // App Store Rating
  retention,  // User Retention Rate
  ltv,        // Lifetime Value
}

enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

enum EmergencyActionType {
  increaseRetentionRewards,
  adjustAdFrequency,
  activateSpecialEvents,
  improveUserExperience,
  enhanceOnboarding,
  boostSocialFeatures,
}

class KPIMetric {
  final KPIType type;
  final double currentValue;
  final double targetValue;
  final double previousValue;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const KPIMetric({
    required this.type,
    required this.currentValue,
    required this.targetValue,
    required this.previousValue,
    required this.timestamp,
    this.metadata = const {},
  });

  double get performanceRatio => currentValue / targetValue;
  double get changeRate => (currentValue - previousValue) / previousValue;
  bool get isUnderperforming => currentValue < targetValue;
  bool get isImproving => currentValue > previousValue;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'currentValue': currentValue,
    'targetValue': targetValue,
    'previousValue': previousValue,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory KPIMetric.fromJson(Map<String, dynamic> json) => KPIMetric(
    type: KPIType.values.byName(json['type']),
    currentValue: json['currentValue'].toDouble(),
    targetValue: json['targetValue'].toDouble(),
    previousValue: json['previousValue'].toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

class KPIAlert {
  final String id;
  final KPIType kpiType;
  final AlertSeverity severity;
  final String message;
  final double threshold;
  final double actualValue;
  final DateTime triggeredAt;
  final List<EmergencyActionType> recommendedActions;
  final bool isResolved;

  const KPIAlert({
    required this.id,
    required this.kpiType,
    required this.severity,
    required this.message,
    required this.threshold,
    required this.actualValue,
    required this.triggeredAt,
    required this.recommendedActions,
    this.isResolved = false,
  });

  KPIAlert copyWith({
    String? id,
    KPIType? kpiType,
    AlertSeverity? severity,
    String? message,
    double? threshold,
    double? actualValue,
    DateTime? triggeredAt,
    List<EmergencyActionType>? recommendedActions,
    bool? isResolved,
  }) => KPIAlert(
    id: id ?? this.id,
    kpiType: kpiType ?? this.kpiType,
    severity: severity ?? this.severity,
    message: message ?? this.message,
    threshold: threshold ?? this.threshold,
    actualValue: actualValue ?? this.actualValue,
    triggeredAt: triggeredAt ?? this.triggeredAt,
    recommendedActions: recommendedActions ?? this.recommendedActions,
    isResolved: isResolved ?? this.isResolved,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kpiType': kpiType.name,
    'severity': severity.name,
    'message': message,
    'threshold': threshold,
    'actualValue': actualValue,
    'triggeredAt': triggeredAt.toIso8601String(),
    'recommendedActions': recommendedActions.map((a) => a.name).toList(),
    'isResolved': isResolved,
  };
}

class EmergencyAction {
  final EmergencyActionType type;
  final String description;
  final Map<String, dynamic> parameters;
  final DateTime scheduledAt;
  final DateTime? executedAt;
  final bool isCompleted;
  final double expectedImpact;

  const EmergencyAction({
    required this.type,
    required this.description,
    required this.parameters,
    required this.scheduledAt,
    this.executedAt,
    this.isCompleted = false,
    this.expectedImpact = 0.0,
  });

  EmergencyAction copyWith({
    EmergencyActionType? type,
    String? description,
    Map<String, dynamic>? parameters,
    DateTime? scheduledAt,
    DateTime? executedAt,
    bool? isCompleted,
    double? expectedImpact,
  }) => EmergencyAction(
    type: type ?? this.type,
    description: description ?? this.description,
    parameters: parameters ?? this.parameters,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    executedAt: executedAt ?? this.executedAt,
    isCompleted: isCompleted ?? this.isCompleted,
    expectedImpact: expectedImpact ?? this.expectedImpact,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'description': description,
    'parameters': parameters,
    'scheduledAt': scheduledAt.toIso8601String(),
    'executedAt': executedAt?.toIso8601String(),
    'isCompleted': isCompleted,
    'expectedImpact': expectedImpact,
  };
}

class KPITarget {
  final KPIType type;
  final double targetValue;
  final double warningThreshold;
  final double criticalThreshold;
  final Duration monitoringInterval;

  const KPITarget({
    required this.type,
    required this.targetValue,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.monitoringInterval,
  });

  AlertSeverity getSeverityForValue(double value) {
    // CPI の場合は値が高いほど悪い（逆転ロジック）
    if (type == KPIType.cpi) {
      if (value >= criticalThreshold) return AlertSeverity.critical;
      if (value >= warningThreshold) return AlertSeverity.high;
      if (value > targetValue * 1.1) return AlertSeverity.medium;
      return AlertSeverity.low;
    } else {
      // その他のKPIは値が低いほど悪い
      if (value <= criticalThreshold) return AlertSeverity.critical;
      if (value <= warningThreshold) return AlertSeverity.high;
      if (value < targetValue * 0.9) return AlertSeverity.medium;
      return AlertSeverity.low;
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'targetValue': targetValue,
    'warningThreshold': warningThreshold,
    'criticalThreshold': criticalThreshold,
    'monitoringInterval': monitoringInterval.inMilliseconds,
  };
}

class UserSatisfactionMetrics {
  final double overallSatisfaction;
  final double gameplayRating;
  final double monetizationSatisfaction;
  final double technicalPerformance;
  final int totalFeedbacks;
  final DateTime lastUpdated;

  const UserSatisfactionMetrics({
    required this.overallSatisfaction,
    required this.gameplayRating,
    required this.monetizationSatisfaction,
    required this.technicalPerformance,
    required this.totalFeedbacks,
    required this.lastUpdated,
  });

  bool get needsImprovement => overallSatisfaction < 4.0;
  bool get isCritical => overallSatisfaction < 3.5;

  Map<String, dynamic> toJson() => {
    'overallSatisfaction': overallSatisfaction,
    'gameplayRating': gameplayRating,
    'monetizationSatisfaction': monetizationSatisfaction,
    'technicalPerformance': technicalPerformance,
    'totalFeedbacks': totalFeedbacks,
    'lastUpdated': lastUpdated.toIso8601String(),
  };
}