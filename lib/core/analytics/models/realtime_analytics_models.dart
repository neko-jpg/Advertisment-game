import 'dart:convert';

/// Real-time KPI metrics
class RealtimeKPIMetrics {
  const RealtimeKPIMetrics({
    required this.timestamp,
    required this.activeUsers,
    required this.revenue,
    required this.arpu,
    required this.sessionLength,
    required this.retentionRate,
    required this.crashRate,
    required this.appStoreRating,
    required this.conversionRate,
    required this.adRevenue,
    required this.iapRevenue,
  });

  final DateTime timestamp;
  final int activeUsers;
  final double revenue;
  final double arpu; // Average Revenue Per User
  final Duration sessionLength;
  final double retentionRate;
  final double crashRate;
  final double appStoreRating;
  final double conversionRate;
  final double adRevenue;
  final double iapRevenue;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'activeUsers': activeUsers,
      'revenue': revenue,
      'arpu': arpu,
      'sessionLength': sessionLength.inMilliseconds,
      'retentionRate': retentionRate,
      'crashRate': crashRate,
      'appStoreRating': appStoreRating,
      'conversionRate': conversionRate,
      'adRevenue': adRevenue,
      'iapRevenue': iapRevenue,
    };
  }

  static RealtimeKPIMetrics fromJson(Map<String, dynamic> json) {
    return RealtimeKPIMetrics(
      timestamp: DateTime.parse(json['timestamp'] as String),
      activeUsers: json['activeUsers'] as int,
      revenue: (json['revenue'] as num).toDouble(),
      arpu: (json['arpu'] as num).toDouble(),
      sessionLength: Duration(milliseconds: json['sessionLength'] as int),
      retentionRate: (json['retentionRate'] as num).toDouble(),
      crashRate: (json['crashRate'] as num).toDouble(),
      appStoreRating: (json['appStoreRating'] as num).toDouble(),
      conversionRate: (json['conversionRate'] as num).toDouble(),
      adRevenue: (json['adRevenue'] as num).toDouble(),
      iapRevenue: (json['iapRevenue'] as num).toDouble(),
    );
  }
}

/// KPI alert configuration
class KPIAlert {
  const KPIAlert({
    required this.alertId,
    required this.metricName,
    required this.threshold,
    required this.condition,
    required this.severity,
    required this.isActive,
    this.description = '',
    this.actions = const [],
  });

  final String alertId;
  final String metricName;
  final double threshold;
  final AlertCondition condition;
  final AlertSeverity severity;
  final bool isActive;
  final String description;
  final List<AlertAction> actions;

  Map<String, dynamic> toJson() {
    return {
      'alertId': alertId,
      'metricName': metricName,
      'threshold': threshold,
      'condition': condition.name,
      'severity': severity.name,
      'isActive': isActive,
      'description': description,
      'actions': actions.map((a) => a.toJson()).toList(),
    };
  }

  static KPIAlert fromJson(Map<String, dynamic> json) {
    return KPIAlert(
      alertId: json['alertId'] as String,
      metricName: json['metricName'] as String,
      threshold: (json['threshold'] as num).toDouble(),
      condition: AlertCondition.values.firstWhere(
        (e) => e.name == json['condition'],
        orElse: () => AlertCondition.below,
      ),
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.medium,
      ),
      isActive: json['isActive'] as bool,
      description: json['description'] as String? ?? '',
      actions: (json['actions'] as List<dynamic>?)
          ?.map((a) => AlertAction.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

enum AlertCondition { above, below, equals }
enum AlertSeverity { low, medium, high, critical }

/// Alert action to take when threshold is breached
class AlertAction {
  const AlertAction({
    required this.type,
    required this.parameters,
  });

  final AlertActionType type;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'parameters': parameters,
    };
  }

  static AlertAction fromJson(Map<String, dynamic> json) {
    return AlertAction(
      type: AlertActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AlertActionType.log,
      ),
      parameters: Map<String, dynamic>.from(json['parameters'] as Map),
    );
  }
}

enum AlertActionType {
  log,
  notification,
  email,
  webhook,
  autoOptimize,
  emergencyMode,
}

/// Triggered alert instance
class TriggeredAlert {
  const TriggeredAlert({
    required this.alertId,
    required this.metricName,
    required this.currentValue,
    required this.threshold,
    required this.triggeredAt,
    required this.severity,
    this.resolved = false,
    this.resolvedAt,
    this.message = '',
  });

  final String alertId;
  final String metricName;
  final double currentValue;
  final double threshold;
  final DateTime triggeredAt;
  final AlertSeverity severity;
  final bool resolved;
  final DateTime? resolvedAt;
  final String message;

  Map<String, dynamic> toJson() {
    return {
      'alertId': alertId,
      'metricName': metricName,
      'currentValue': currentValue,
      'threshold': threshold,
      'triggeredAt': triggeredAt.toIso8601String(),
      'severity': severity.name,
      'resolved': resolved,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'message': message,
    };
  }

  static TriggeredAlert fromJson(Map<String, dynamic> json) {
    return TriggeredAlert(
      alertId: json['alertId'] as String,
      metricName: json['metricName'] as String,
      currentValue: (json['currentValue'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      severity: AlertSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => AlertSeverity.medium,
      ),
      resolved: json['resolved'] as bool? ?? false,
      resolvedAt: json['resolvedAt'] != null 
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Competitor analysis data
class CompetitorAnalysis {
  const CompetitorAnalysis({
    required this.competitorId,
    required this.name,
    required this.ranking,
    required this.estimatedRevenue,
    required this.downloads,
    required this.rating,
    required this.lastUpdated,
    required this.keyFeatures,
    required this.marketShare,
  });

  final String competitorId;
  final String name;
  final int ranking;
  final double estimatedRevenue;
  final int downloads;
  final double rating;
  final DateTime lastUpdated;
  final List<String> keyFeatures;
  final double marketShare;

  Map<String, dynamic> toJson() {
    return {
      'competitorId': competitorId,
      'name': name,
      'ranking': ranking,
      'estimatedRevenue': estimatedRevenue,
      'downloads': downloads,
      'rating': rating,
      'lastUpdated': lastUpdated.toIso8601String(),
      'keyFeatures': keyFeatures,
      'marketShare': marketShare,
    };
  }

  static CompetitorAnalysis fromJson(Map<String, dynamic> json) {
    return CompetitorAnalysis(
      competitorId: json['competitorId'] as String,
      name: json['name'] as String,
      ranking: json['ranking'] as int,
      estimatedRevenue: (json['estimatedRevenue'] as num).toDouble(),
      downloads: json['downloads'] as int,
      rating: (json['rating'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      keyFeatures: List<String>.from(json['keyFeatures'] as List),
      marketShare: (json['marketShare'] as num).toDouble(),
    );
  }
}

/// Market position analysis
class MarketPosition {
  const MarketPosition({
    required this.currentRanking,
    required this.previousRanking,
    required this.category,
    required this.marketShare,
    required this.competitiveAdvantages,
    required this.threats,
    required this.opportunities,
    required this.recommendedActions,
    required this.analysisDate,
  });

  final int currentRanking;
  final int previousRanking;
  final String category;
  final double marketShare;
  final List<String> competitiveAdvantages;
  final List<String> threats;
  final List<String> opportunities;
  final List<String> recommendedActions;
  final DateTime analysisDate;

  int get rankingChange => previousRanking - currentRanking;
  bool get isImproving => rankingChange > 0;

  Map<String, dynamic> toJson() {
    return {
      'currentRanking': currentRanking,
      'previousRanking': previousRanking,
      'category': category,
      'marketShare': marketShare,
      'competitiveAdvantages': competitiveAdvantages,
      'threats': threats,
      'opportunities': opportunities,
      'recommendedActions': recommendedActions,
      'analysisDate': analysisDate.toIso8601String(),
    };
  }

  static MarketPosition fromJson(Map<String, dynamic> json) {
    return MarketPosition(
      currentRanking: json['currentRanking'] as int,
      previousRanking: json['previousRanking'] as int,
      category: json['category'] as String,
      marketShare: (json['marketShare'] as num).toDouble(),
      competitiveAdvantages: List<String>.from(json['competitiveAdvantages'] as List),
      threats: List<String>.from(json['threats'] as List),
      opportunities: List<String>.from(json['opportunities'] as List),
      recommendedActions: List<String>.from(json['recommendedActions'] as List),
      analysisDate: DateTime.parse(json['analysisDate'] as String),
    );
  }
}

/// Dashboard configuration
class DashboardConfig {
  const DashboardConfig({
    required this.dashboardId,
    required this.name,
    required this.widgets,
    required this.refreshInterval,
    required this.isActive,
    this.filters = const {},
  });

  final String dashboardId;
  final String name;
  final List<DashboardWidget> widgets;
  final Duration refreshInterval;
  final bool isActive;
  final Map<String, dynamic> filters;

  Map<String, dynamic> toJson() {
    return {
      'dashboardId': dashboardId,
      'name': name,
      'widgets': widgets.map((w) => w.toJson()).toList(),
      'refreshInterval': refreshInterval.inMilliseconds,
      'isActive': isActive,
      'filters': filters,
    };
  }

  static DashboardConfig fromJson(Map<String, dynamic> json) {
    return DashboardConfig(
      dashboardId: json['dashboardId'] as String,
      name: json['name'] as String,
      widgets: (json['widgets'] as List<dynamic>)
          .map((w) => DashboardWidget.fromJson(w as Map<String, dynamic>))
          .toList(),
      refreshInterval: Duration(milliseconds: json['refreshInterval'] as int),
      isActive: json['isActive'] as bool,
      filters: Map<String, dynamic>.from(json['filters'] as Map? ?? {}),
    );
  }
}

/// Dashboard widget configuration
class DashboardWidget {
  const DashboardWidget({
    required this.widgetId,
    required this.type,
    required this.title,
    required this.metrics,
    required this.position,
    required this.size,
    this.config = const {},
  });

  final String widgetId;
  final WidgetType type;
  final String title;
  final List<String> metrics;
  final WidgetPosition position;
  final WidgetSize size;
  final Map<String, dynamic> config;

  Map<String, dynamic> toJson() {
    return {
      'widgetId': widgetId,
      'type': type.name,
      'title': title,
      'metrics': metrics,
      'position': position.toJson(),
      'size': size.toJson(),
      'config': config,
    };
  }

  static DashboardWidget fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      widgetId: json['widgetId'] as String,
      type: WidgetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WidgetType.metric,
      ),
      title: json['title'] as String,
      metrics: List<String>.from(json['metrics'] as List),
      position: WidgetPosition.fromJson(json['position'] as Map<String, dynamic>),
      size: WidgetSize.fromJson(json['size'] as Map<String, dynamic>),
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }
}

enum WidgetType {
  metric,
  chart,
  table,
  alert,
  competitor,
  heatmap,
}

/// Widget position on dashboard
class WidgetPosition {
  const WidgetPosition({
    required this.x,
    required this.y,
  });

  final int x;
  final int y;

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }

  static WidgetPosition fromJson(Map<String, dynamic> json) {
    return WidgetPosition(
      x: json['x'] as int,
      y: json['y'] as int,
    );
  }
}

/// Widget size on dashboard
class WidgetSize {
  const WidgetSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
    };
  }

  static WidgetSize fromJson(Map<String, dynamic> json) {
    return WidgetSize(
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }
}

/// Time series data point
class TimeSeriesDataPoint {
  const TimeSeriesDataPoint({
    required this.timestamp,
    required this.value,
    this.metadata = const {},
  });

  final DateTime timestamp;
  final double value;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'value': value,
      'metadata': metadata,
    };
  }

  static TimeSeriesDataPoint fromJson(Map<String, dynamic> json) {
    return TimeSeriesDataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}