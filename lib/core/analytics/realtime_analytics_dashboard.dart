import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/realtime_analytics_models.dart';
import 'models/behavior_models.dart';

/// Real-time analytics dashboard system
class RealtimeAnalyticsDashboard {
  RealtimeAnalyticsDashboard({
    required this.storage,
    this.updateInterval = const Duration(seconds: 30),
  });

  final RealtimeAnalyticsStorage storage;
  final Duration updateInterval;

  Timer? _updateTimer;
  final StreamController<RealtimeKPIMetrics> _metricsController = 
      StreamController<RealtimeKPIMetrics>.broadcast();
  final StreamController<TriggeredAlert> _alertController = 
      StreamController<TriggeredAlert>.broadcast();

  Stream<RealtimeKPIMetrics> get metricsStream => _metricsController.stream;
  Stream<TriggeredAlert> get alertStream => _alertController.stream;

  List<KPIAlert> _activeAlerts = [];
  RealtimeKPIMetrics? _lastMetrics;

  /// Start real-time monitoring
  Future<void> startMonitoring() async {
    await _loadActiveAlerts();
    
    _updateTimer = Timer.periodic(updateInterval, (_) async {
      await _updateMetrics();
    });

    // Initial update
    await _updateMetrics();
    
    print('Real-time analytics monitoring started');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = null;
    print('Real-time analytics monitoring stopped');
  }

  /// Get current KPI metrics
  Future<RealtimeKPIMetrics> getCurrentMetrics() async {
    return await _calculateCurrentMetrics();
  }

  /// Get historical metrics
  Future<List<RealtimeKPIMetrics>> getHistoricalMetrics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await storage.getMetricsHistory(startDate, endDate);
  }

  /// Add KPI alert
  Future<void> addKPIAlert(KPIAlert alert) async {
    await storage.saveKPIAlert(alert);
    await _loadActiveAlerts();
    print('KPI alert added: ${alert.metricName} ${alert.condition.name} ${alert.threshold}');
  }

  /// Remove KPI alert
  Future<void> removeKPIAlert(String alertId) async {
    await storage.removeKPIAlert(alertId);
    await _loadActiveAlerts();
    print('KPI alert removed: $alertId');
  }

  /// Get active alerts
  Future<List<KPIAlert>> getActiveAlerts() async {
    return await storage.getActiveKPIAlerts();
  }

  /// Get triggered alerts
  Future<List<TriggeredAlert>> getTriggeredAlerts({
    DateTime? since,
    bool unresolvedOnly = false,
  }) async {
    return await storage.getTriggeredAlerts(
      since: since,
      unresolvedOnly: unresolvedOnly,
    );
  }

  /// Resolve alert
  Future<void> resolveAlert(String alertId) async {
    await storage.resolveAlert(alertId);
    print('Alert resolved: $alertId');
  }

  /// Get competitor analysis
  Future<List<CompetitorAnalysis>> getCompetitorAnalysis() async {
    return await storage.getCompetitorAnalysis();
  }

  /// Update competitor data
  Future<void> updateCompetitorData(CompetitorAnalysis competitor) async {
    await storage.saveCompetitorAnalysis(competitor);
    print('Competitor data updated: ${competitor.name}');
  }

  /// Get market position
  Future<MarketPosition> getMarketPosition() async {
    final position = await storage.getMarketPosition();
    return position ?? _generateMockMarketPosition();
  }

  /// Update market position
  Future<void> updateMarketPosition(MarketPosition position) async {
    await storage.saveMarketPosition(position);
    print('Market position updated: Rank ${position.currentRanking}');
  }

  /// Create dashboard configuration
  Future<void> createDashboard(DashboardConfig config) async {
    await storage.saveDashboardConfig(config);
    print('Dashboard created: ${config.name}');
  }

  /// Get dashboard configuration
  Future<DashboardConfig?> getDashboard(String dashboardId) async {
    return await storage.getDashboardConfig(dashboardId);
  }

  /// Get time series data for metric
  Future<List<TimeSeriesDataPoint>> getTimeSeriesData({
    required String metricName,
    required DateTime startDate,
    required DateTime endDate,
    Duration? granularity,
  }) async {
    return await storage.getTimeSeriesData(
      metricName: metricName,
      startDate: startDate,
      endDate: endDate,
      granularity: granularity ?? Duration(hours: 1),
    );
  }

  /// Generate automated insights
  Future<List<String>> generateInsights() async {
    final insights = <String>[];
    
    if (_lastMetrics == null) {
      return insights;
    }

    final metrics = _lastMetrics!;
    final historical = await getHistoricalMetrics(
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    );

    if (historical.isNotEmpty) {
      final avgRevenue = historical.fold(0.0, (sum, m) => sum + m.revenue) / historical.length;
      if (metrics.revenue > avgRevenue * 1.2) {
        insights.add('Revenue is 20% above weekly average - excellent performance!');
      } else if (metrics.revenue < avgRevenue * 0.8) {
        insights.add('Revenue is 20% below weekly average - investigate monetization issues');
      }

      final avgRetention = historical.fold(0.0, (sum, m) => sum + m.retentionRate) / historical.length;
      if (metrics.retentionRate > avgRetention * 1.1) {
        insights.add('User retention is improving - current strategies are working');
      } else if (metrics.retentionRate < avgRetention * 0.9) {
        insights.add('User retention declining - review onboarding and engagement features');
      }
    }

    if (metrics.crashRate > 0.05) {
      insights.add('High crash rate detected - prioritize stability fixes');
    }

    if (metrics.appStoreRating < 4.0) {
      insights.add('App store rating below 4.0 - focus on user satisfaction improvements');
    }

    return insights;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _metricsController.close();
    _alertController.close();
  }

  // Private methods

  Future<void> _updateMetrics() async {
    try {
      final metrics = await _calculateCurrentMetrics();
      _lastMetrics = metrics;
      
      // Store metrics
      await storage.saveMetrics(metrics);
      
      // Check alerts
      await _checkAlerts(metrics);
      
      // Emit to stream
      _metricsController.add(metrics);
      
    } catch (e) {
      print('Error updating metrics: $e');
    }
  }

  Future<RealtimeKPIMetrics> _calculateCurrentMetrics() async {
    // In a real implementation, this would aggregate data from various sources
    // For now, we'll generate realistic mock data
    
    final now = DateTime.now();
    final random = Random();
    
    // Simulate realistic metrics with some variance
    final baseActiveUsers = 10000 + random.nextInt(5000);
    final baseRevenue = 1000.0 + (random.nextDouble() * 500);
    final baseArpu = baseRevenue / baseActiveUsers;
    
    return RealtimeKPIMetrics(
      timestamp: now,
      activeUsers: baseActiveUsers,
      revenue: baseRevenue,
      arpu: baseArpu,
      sessionLength: Duration(minutes: 8 + random.nextInt(5)),
      retentionRate: 0.65 + (random.nextDouble() * 0.2),
      crashRate: 0.01 + (random.nextDouble() * 0.03),
      appStoreRating: 4.2 + (random.nextDouble() * 0.6),
      conversionRate: 0.08 + (random.nextDouble() * 0.05),
      adRevenue: baseRevenue * 0.7,
      iapRevenue: baseRevenue * 0.3,
    );
  }

  Future<void> _loadActiveAlerts() async {
    _activeAlerts = await storage.getActiveKPIAlerts();
  }

  Future<void> _checkAlerts(RealtimeKPIMetrics metrics) async {
    for (final alert in _activeAlerts) {
      if (!alert.isActive) continue;

      final currentValue = _getMetricValue(metrics, alert.metricName);
      if (currentValue == null) continue;

      bool shouldTrigger = false;
      switch (alert.condition) {
        case AlertCondition.above:
          shouldTrigger = currentValue > alert.threshold;
          break;
        case AlertCondition.below:
          shouldTrigger = currentValue < alert.threshold;
          break;
        case AlertCondition.equals:
          shouldTrigger = (currentValue - alert.threshold).abs() < 0.001;
          break;
      }

      if (shouldTrigger) {
        await _triggerAlert(alert, currentValue);
      }
    }
  }

  double? _getMetricValue(RealtimeKPIMetrics metrics, String metricName) {
    switch (metricName) {
      case 'activeUsers':
        return metrics.activeUsers.toDouble();
      case 'revenue':
        return metrics.revenue;
      case 'arpu':
        return metrics.arpu;
      case 'sessionLength':
        return metrics.sessionLength.inMinutes.toDouble();
      case 'retentionRate':
        return metrics.retentionRate;
      case 'crashRate':
        return metrics.crashRate;
      case 'appStoreRating':
        return metrics.appStoreRating;
      case 'conversionRate':
        return metrics.conversionRate;
      case 'adRevenue':
        return metrics.adRevenue;
      case 'iapRevenue':
        return metrics.iapRevenue;
      default:
        return null;
    }
  }

  Future<void> _triggerAlert(KPIAlert alert, double currentValue) async {
    // Check if alert was already triggered recently (avoid spam)
    final recentAlerts = await storage.getTriggeredAlerts(
      since: DateTime.now().subtract(Duration(hours: 1)),
      unresolvedOnly: true,
    );
    
    final alreadyTriggered = recentAlerts.any((a) => a.alertId == alert.alertId);
    if (alreadyTriggered) return;

    final triggeredAlert = TriggeredAlert(
      alertId: alert.alertId,
      metricName: alert.metricName,
      currentValue: currentValue,
      threshold: alert.threshold,
      triggeredAt: DateTime.now(),
      severity: alert.severity,
      message: _generateAlertMessage(alert, currentValue),
    );

    await storage.saveTriggeredAlert(triggeredAlert);
    _alertController.add(triggeredAlert);

    // Execute alert actions
    await _executeAlertActions(alert, triggeredAlert);

    print('Alert triggered: ${alert.metricName} = $currentValue (threshold: ${alert.threshold})');
  }

  String _generateAlertMessage(KPIAlert alert, double currentValue) {
    final condition = alert.condition.name;
    return '${alert.metricName} is $condition ${alert.threshold} (current: ${currentValue.toStringAsFixed(2)})';
  }

  Future<void> _executeAlertActions(KPIAlert alert, TriggeredAlert triggeredAlert) async {
    for (final action in alert.actions) {
      try {
        await _executeAlertAction(action, triggeredAlert);
      } catch (e) {
        print('Error executing alert action ${action.type}: $e');
      }
    }
  }

  Future<void> _executeAlertAction(AlertAction action, TriggeredAlert alert) async {
    switch (action.type) {
      case AlertActionType.log:
        print('ALERT: ${alert.message}');
        break;
      case AlertActionType.notification:
        // In a real app, this would show a system notification
        print('NOTIFICATION: ${alert.message}');
        break;
      case AlertActionType.email:
        // In a real app, this would send an email
        print('EMAIL ALERT: ${alert.message}');
        break;
      case AlertActionType.webhook:
        // In a real app, this would call a webhook
        print('WEBHOOK: ${alert.message}');
        break;
      case AlertActionType.autoOptimize:
        await _executeAutoOptimization(alert);
        break;
      case AlertActionType.emergencyMode:
        await _activateEmergencyMode(alert);
        break;
    }
  }

  Future<void> _executeAutoOptimization(TriggeredAlert alert) async {
    print('Executing auto-optimization for ${alert.metricName}');
    
    // Example auto-optimizations based on metric
    switch (alert.metricName) {
      case 'crashRate':
        // Enable crash recovery mode
        print('Enabling enhanced error recovery');
        break;
      case 'revenue':
        // Boost monetization
        print('Activating revenue boost strategies');
        break;
      case 'retentionRate':
        // Activate retention campaigns
        print('Launching retention improvement campaigns');
        break;
    }
  }

  Future<void> _activateEmergencyMode(TriggeredAlert alert) async {
    print('EMERGENCY MODE ACTIVATED for ${alert.metricName}');
    
    // Emergency actions based on severity
    switch (alert.severity) {
      case AlertSeverity.critical:
        print('Critical alert - implementing emergency measures');
        break;
      case AlertSeverity.high:
        print('High severity alert - escalating to team');
        break;
      default:
        print('Emergency mode activated');
    }
  }

  MarketPosition _generateMockMarketPosition() {
    final random = Random();
    return MarketPosition(
      currentRanking: 15 + random.nextInt(10),
      previousRanking: 20 + random.nextInt(10),
      category: 'Casual Games',
      marketShare: 0.02 + (random.nextDouble() * 0.03),
      competitiveAdvantages: [
        'Unique drawing mechanics',
        'High user engagement',
        'Strong retention rates',
      ],
      threats: [
        'Increasing competition',
        'Market saturation',
        'User acquisition costs rising',
      ],
      opportunities: [
        'Expand to new markets',
        'Add social features',
        'Implement seasonal events',
      ],
      recommendedActions: [
        'Optimize user acquisition campaigns',
        'Enhance monetization strategies',
        'Improve app store optimization',
      ],
      analysisDate: DateTime.now(),
    );
  }
}

/// Storage interface for real-time analytics
abstract class RealtimeAnalyticsStorage {
  Future<void> saveMetrics(RealtimeKPIMetrics metrics);
  Future<List<RealtimeKPIMetrics>> getMetricsHistory(DateTime startDate, DateTime endDate);
  
  Future<void> saveKPIAlert(KPIAlert alert);
  Future<void> removeKPIAlert(String alertId);
  Future<List<KPIAlert>> getActiveKPIAlerts();
  
  Future<void> saveTriggeredAlert(TriggeredAlert alert);
  Future<List<TriggeredAlert>> getTriggeredAlerts({DateTime? since, bool unresolvedOnly = false});
  Future<void> resolveAlert(String alertId);
  
  Future<void> saveCompetitorAnalysis(CompetitorAnalysis competitor);
  Future<List<CompetitorAnalysis>> getCompetitorAnalysis();
  
  Future<void> saveMarketPosition(MarketPosition position);
  Future<MarketPosition?> getMarketPosition();
  
  Future<void> saveDashboardConfig(DashboardConfig config);
  Future<DashboardConfig?> getDashboardConfig(String dashboardId);
  
  Future<List<TimeSeriesDataPoint>> getTimeSeriesData({
    required String metricName,
    required DateTime startDate,
    required DateTime endDate,
    required Duration granularity,
  });
}

/// Local storage implementation for real-time analytics
class LocalRealtimeAnalyticsStorage implements RealtimeAnalyticsStorage {
  LocalRealtimeAnalyticsStorage({required this.preferences});
  
  final SharedPreferences preferences;
  
  static const String _metricsPrefix = 'rt_metrics_';
  static const String _alertsPrefix = 'rt_alerts_';
  static const String _triggeredAlertsPrefix = 'rt_triggered_';
  static const String _competitorPrefix = 'rt_competitor_';
  static const String _marketPositionKey = 'rt_market_position';
  static const String _dashboardPrefix = 'rt_dashboard_';
  static const String _timeSeriesPrefix = 'rt_timeseries_';

  @override
  Future<void> saveMetrics(RealtimeKPIMetrics metrics) async {
    final key = '$_metricsPrefix${metrics.timestamp.millisecondsSinceEpoch}';
    await preferences.setString(key, jsonEncode(metrics.toJson()));
    
    // Clean up old metrics (keep last 7 days)
    await _cleanupOldMetrics();
  }

  @override
  Future<List<RealtimeKPIMetrics>> getMetricsHistory(DateTime startDate, DateTime endDate) async {
    final metrics = <RealtimeKPIMetrics>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_metricsPrefix));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final metric = RealtimeKPIMetrics.fromJson(json);
          
          if (metric.timestamp.isAfter(startDate) && metric.timestamp.isBefore(endDate)) {
            metrics.add(metric);
          }
        } catch (e) {
          print('Error loading metric: $e');
        }
      }
    }
    
    metrics.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return metrics;
  }

  @override
  Future<void> saveKPIAlert(KPIAlert alert) async {
    final key = '$_alertsPrefix${alert.alertId}';
    await preferences.setString(key, jsonEncode(alert.toJson()));
  }

  @override
  Future<void> removeKPIAlert(String alertId) async {
    final key = '$_alertsPrefix$alertId';
    await preferences.remove(key);
  }

  @override
  Future<List<KPIAlert>> getActiveKPIAlerts() async {
    final alerts = <KPIAlert>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_alertsPrefix));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final alert = KPIAlert.fromJson(json);
          if (alert.isActive) {
            alerts.add(alert);
          }
        } catch (e) {
          print('Error loading alert: $e');
        }
      }
    }
    
    return alerts;
  }

  @override
  Future<void> saveTriggeredAlert(TriggeredAlert alert) async {
    final key = '$_triggeredAlertsPrefix${alert.triggeredAt.millisecondsSinceEpoch}';
    await preferences.setString(key, jsonEncode(alert.toJson()));
  }

  @override
  Future<List<TriggeredAlert>> getTriggeredAlerts({DateTime? since, bool unresolvedOnly = false}) async {
    final alerts = <TriggeredAlert>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_triggeredAlertsPrefix));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final alert = TriggeredAlert.fromJson(json);
          
          if (since != null && alert.triggeredAt.isBefore(since)) continue;
          if (unresolvedOnly && alert.resolved) continue;
          
          alerts.add(alert);
        } catch (e) {
          print('Error loading triggered alert: $e');
        }
      }
    }
    
    alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return alerts;
  }

  @override
  Future<void> resolveAlert(String alertId) async {
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_triggeredAlertsPrefix));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final alert = TriggeredAlert.fromJson(json);
          
          if (alert.alertId == alertId && !alert.resolved) {
            final resolvedAlert = TriggeredAlert(
              alertId: alert.alertId,
              metricName: alert.metricName,
              currentValue: alert.currentValue,
              threshold: alert.threshold,
              triggeredAt: alert.triggeredAt,
              severity: alert.severity,
              resolved: true,
              resolvedAt: DateTime.now(),
              message: alert.message,
            );
            
            await preferences.setString(key, jsonEncode(resolvedAlert.toJson()));
            break;
          }
        } catch (e) {
          print('Error resolving alert: $e');
        }
      }
    }
  }

  @override
  Future<void> saveCompetitorAnalysis(CompetitorAnalysis competitor) async {
    final key = '$_competitorPrefix${competitor.competitorId}';
    await preferences.setString(key, jsonEncode(competitor.toJson()));
  }

  @override
  Future<List<CompetitorAnalysis>> getCompetitorAnalysis() async {
    final competitors = <CompetitorAnalysis>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_competitorPrefix));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          competitors.add(CompetitorAnalysis.fromJson(json));
        } catch (e) {
          print('Error loading competitor: $e');
        }
      }
    }
    
    competitors.sort((a, b) => a.ranking.compareTo(b.ranking));
    return competitors;
  }

  @override
  Future<void> saveMarketPosition(MarketPosition position) async {
    await preferences.setString(_marketPositionKey, jsonEncode(position.toJson()));
  }

  @override
  Future<MarketPosition?> getMarketPosition() async {
    final jsonString = preferences.getString(_marketPositionKey);
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return MarketPosition.fromJson(json);
    } catch (e) {
      print('Error loading market position: $e');
      return null;
    }
  }

  @override
  Future<void> saveDashboardConfig(DashboardConfig config) async {
    final key = '$_dashboardPrefix${config.dashboardId}';
    await preferences.setString(key, jsonEncode(config.toJson()));
  }

  @override
  Future<DashboardConfig?> getDashboardConfig(String dashboardId) async {
    final key = '$_dashboardPrefix$dashboardId';
    final jsonString = preferences.getString(key);
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DashboardConfig.fromJson(json);
    } catch (e) {
      print('Error loading dashboard config: $e');
      return null;
    }
  }

  @override
  Future<List<TimeSeriesDataPoint>> getTimeSeriesData({
    required String metricName,
    required DateTime startDate,
    required DateTime endDate,
    required Duration granularity,
  }) async {
    // For simplicity, generate mock time series data
    final dataPoints = <TimeSeriesDataPoint>[];
    final random = Random();
    
    var current = startDate;
    while (current.isBefore(endDate)) {
      final value = 100.0 + (random.nextDouble() * 50);
      dataPoints.add(TimeSeriesDataPoint(
        timestamp: current,
        value: value,
        metadata: {'metric': metricName},
      ));
      current = current.add(granularity);
    }
    
    return dataPoints;
  }

  Future<void> _cleanupOldMetrics() async {
    final cutoff = DateTime.now().subtract(Duration(days: 7));
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_metricsPrefix));
    
    for (final key in keys) {
      final timestampStr = key.substring(_metricsPrefix.length);
      try {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr));
        if (timestamp.isBefore(cutoff)) {
          await preferences.remove(key);
        }
      } catch (e) {
        // Invalid timestamp, remove the key
        await preferences.remove(key);
      }
    }
  }
}