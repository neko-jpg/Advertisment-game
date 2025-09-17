#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'dart:async';

/// Release monitoring and automatic rollback system
/// 
/// This script continuously monitors release metrics and can automatically
/// trigger rollbacks if critical thresholds are exceeded.
Future<void> main(List<String> args) async {
  print('📊 Starting release monitoring system...');
  
  final monitor = ReleaseMonitor();
  
  try {
    await monitor.startMonitoring();
  } catch (e, stackTrace) {
    print('❌ Monitoring failed: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

class ReleaseMonitor {
  late MonitoringConfig _config;
  late Timer _monitoringTimer;
  final List<MetricSnapshot> _metricHistory = [];
  bool _isMonitoring = false;
  
  Future<void> startMonitoring() async {
    print('🔧 Initializing release monitoring...');
    
    // Load monitoring configuration
    await _loadMonitoringConfig();
    
    // Start monitoring loop
    _startMonitoringLoop();
    
    print('✅ Release monitoring started');
    print('⏰ Check interval: ${_config.checkIntervalMinutes} minutes');
    print('🎯 Monitoring duration: ${_config.monitoringDurationHours} hours');
    
    // Keep the script running
    await _waitForMonitoringCompletion();
  }
  
  Future<void> _loadMonitoringConfig() async {
    final configFile = File('release_config/monitoring_config.json');
    
    if (!await configFile.exists()) {
      throw Exception('Monitoring configuration not found');
    }
    
    final configContent = await configFile.readAsString();
    final configJson = jsonDecode(configContent);
    
    _config = MonitoringConfig.fromJson(configJson);
  }
  
  void _startMonitoringLoop() {
    _isMonitoring = true;
    
    _monitoringTimer = Timer.periodic(
      Duration(minutes: _config.checkIntervalMinutes),
      (timer) async {
        await _performMonitoringCheck();
      },
    );
    
    // Perform initial check
    _performMonitoringCheck();
  }
  
  Future<void> _performMonitoringCheck() async {
    print('\n🔍 Performing monitoring check at ${DateTime.now()}');
    
    try {
      // Collect current metrics
      final metrics = await _collectMetrics();
      
      // Store metrics history
      _metricHistory.add(metrics);
      
      // Analyze metrics
      final analysis = _analyzeMetrics(metrics);
      
      // Print current status
      _printMetricsStatus(metrics, analysis);
      
      // Check for critical issues
      if (analysis.requiresRollback) {
        await _triggerEmergencyRollback(analysis);
      } else if (analysis.requiresAlert) {
        await _sendAlert(analysis);
      }
      
      // Check if monitoring should continue
      if (_shouldStopMonitoring()) {
        await _stopMonitoring();
      }
      
    } catch (e) {
      print('⚠️  Error during monitoring check: $e');
    }
  }
  
  Future<MetricSnapshot> _collectMetrics() async {
    // In a real implementation, this would collect metrics from:
    // - Google Play Console API
    // - Firebase Analytics
    // - Crashlytics
    // - Custom analytics backend
    
    // For demonstration, we'll simulate metric collection
    return await _simulateMetricCollection();
  }
  
  Future<MetricSnapshot> _simulateMetricCollection() async {
    // Simulate API calls with realistic delays
    await Future.delayed(const Duration(seconds: 2));
    
    // Generate realistic metrics with some randomness
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    
    return MetricSnapshot(
      timestamp: DateTime.now(),
      crashRate: 0.05 + (random / 10000), // 0.05% - 0.15%
      anrRate: 0.02 + (random / 20000), // 0.02% - 0.07%
      installRate: 1000 + (random * 10), // 1000-2000 installs/hour
      ratingAverage: 4.2 + (random / 500), // 4.2 - 4.4
      activeUsers: 50000 + (random * 100),
      revenue: 10000 + (random * 50),
      retentionDay1: 0.4 + (random / 1000),
      retentionDay7: 0.15 + (random / 2000),
    );
  }
  
  MetricAnalysis _analyzeMetrics(MetricSnapshot metrics) {
    final issues = <String>[];
    var severity = AlertSeverity.normal;
    
    // Check crash rate
    if (metrics.crashRate > _config.alertThresholds.crashRateMax) {
      issues.add('High crash rate: ${(metrics.crashRate * 100).toStringAsFixed(2)}%');
      severity = AlertSeverity.critical;
    }
    
    // Check ANR rate
    if (metrics.anrRate > _config.alertThresholds.anrRateMax) {
      issues.add('High ANR rate: ${(metrics.anrRate * 100).toStringAsFixed(2)}%');
      if (severity != AlertSeverity.critical) severity = AlertSeverity.warning;
    }
    
    // Check rating
    if (metrics.ratingAverage < _config.alertThresholds.ratingMin) {
      issues.add('Low rating: ${metrics.ratingAverage.toStringAsFixed(1)}');
      if (severity == AlertSeverity.normal) severity = AlertSeverity.warning;
    }
    
    // Check trends if we have history
    if (_metricHistory.length >= 3) {
      final trend = _analyzeTrends();
      if (trend.isNegative) {
        issues.add('Negative trend detected');
        if (severity == AlertSeverity.normal) severity = AlertSeverity.warning;
      }
    }
    
    return MetricAnalysis(
      issues: issues,
      severity: severity,
      requiresAlert: severity != AlertSeverity.normal,
      requiresRollback: severity == AlertSeverity.critical,
      recommendation: _generateRecommendation(issues, severity),
    );
  }
  
  TrendAnalysis _analyzeTrends() {
    if (_metricHistory.length < 3) {
      return TrendAnalysis(isNegative: false, description: 'Insufficient data');
    }
    
    final recent = _metricHistory.takeLast(3).toList();
    
    // Check if crash rate is trending upward
    final crashTrend = recent.last.crashRate - recent.first.crashRate;
    final ratingTrend = recent.last.ratingAverage - recent.first.ratingAverage;
    
    final isNegative = crashTrend > 0.01 || ratingTrend < -0.1;
    
    return TrendAnalysis(
      isNegative: isNegative,
      description: isNegative ? 'Metrics trending negatively' : 'Metrics stable',
    );
  }
  
  String _generateRecommendation(List<String> issues, AlertSeverity severity) {
    if (issues.isEmpty) {
      return 'All metrics within acceptable ranges. Continue monitoring.';
    }
    
    switch (severity) {
      case AlertSeverity.critical:
        return 'CRITICAL: Immediate rollback recommended. Multiple critical thresholds exceeded.';
      case AlertSeverity.warning:
        return 'WARNING: Close monitoring required. Consider preparing rollback plan.';
      case AlertSeverity.normal:
        return 'Minor issues detected. Continue monitoring.';
    }
  }
  
  void _printMetricsStatus(MetricSnapshot metrics, MetricAnalysis analysis) {
    print('📊 Current Metrics:');
    print('   💥 Crash Rate: ${(metrics.crashRate * 100).toStringAsFixed(2)}%');
    print('   🚫 ANR Rate: ${(metrics.anrRate * 100).toStringAsFixed(2)}%');
    print('   ⭐ Rating: ${metrics.ratingAverage.toStringAsFixed(1)}');
    print('   📱 Installs/hour: ${metrics.installRate.toInt()}');
    print('   👥 Active Users: ${metrics.activeUsers.toInt()}');
    print('   💰 Revenue: \$${metrics.revenue.toInt()}');
    print('   📈 Day 1 Retention: ${(metrics.retentionDay1 * 100).toStringAsFixed(1)}%');
    print('   📊 Day 7 Retention: ${(metrics.retentionDay7 * 100).toStringAsFixed(1)}%');
    
    if (analysis.issues.isNotEmpty) {
      print('⚠️  Issues detected:');
      for (final issue in analysis.issues) {
        print('   - $issue');
      }
    }
    
    print('💡 Recommendation: ${analysis.recommendation}');
  }
  
  Future<void> _sendAlert(MetricAnalysis analysis) async {
    print('\n🚨 ALERT: ${analysis.severity.name.toUpperCase()}');
    
    final alert = AlertMessage(
      severity: analysis.severity,
      timestamp: DateTime.now(),
      issues: analysis.issues,
      recommendation: analysis.recommendation,
      metrics: _metricHistory.last,
    );
    
    // Save alert to file
    await _saveAlert(alert);
    
    // In a real implementation, this would:
    // - Send Slack/Discord notifications
    // - Send email alerts
    // - Create PagerDuty incidents
    // - Update monitoring dashboards
    
    print('📧 Alert notifications sent');
  }
  
  Future<void> _saveAlert(AlertMessage alert) async {
    final alertsDir = Directory('release_monitoring/alerts');
    await alertsDir.create(recursive: true);
    
    final alertFile = File('${alertsDir.path}/alert_${alert.timestamp.millisecondsSinceEpoch}.json');
    await alertFile.writeAsString(jsonEncode(alert.toJson()));
  }
  
  Future<void> _triggerEmergencyRollback(MetricAnalysis analysis) async {
    print('\n🚨 EMERGENCY ROLLBACK TRIGGERED');
    print('Reason: ${analysis.issues.join(', ')}');
    
    // Create rollback record
    final rollback = RollbackRecord(
      timestamp: DateTime.now(),
      reason: analysis.issues.join(', '),
      triggerMetrics: _metricHistory.last,
      automatic: true,
    );
    
    // Save rollback record
    await _saveRollbackRecord(rollback);
    
    // Execute rollback
    await _executeRollback();
    
    // Stop monitoring after rollback
    await _stopMonitoring();
    
    print('✅ Emergency rollback completed');
  }
  
  Future<void> _saveRollbackRecord(RollbackRecord rollback) async {
    final rollbackDir = Directory('release_monitoring/rollbacks');
    await rollbackDir.create(recursive: true);
    
    final rollbackFile = File('${rollbackDir.path}/rollback_${rollback.timestamp.millisecondsSinceEpoch}.json');
    await rollbackFile.writeAsString(jsonEncode(rollback.toJson()));
  }
  
  Future<void> _executeRollback() async {
    print('🔄 Executing rollback...');
    
    // In a real implementation, this would:
    // - Call Google Play Console API to halt rollout
    // - Revert to previous version
    // - Update rollout percentage to 0%
    // - Notify stakeholders
    
    // Simulate rollback process
    await Future.delayed(const Duration(seconds: 3));
    
    print('✅ Rollback executed successfully');
  }
  
  bool _shouldStopMonitoring() {
    final monitoringDuration = Duration(hours: _config.monitoringDurationHours);
    final elapsed = DateTime.now().difference(_metricHistory.first.timestamp);
    
    return elapsed >= monitoringDuration;
  }
  
  Future<void> _stopMonitoring() async {
    print('\n⏹️  Stopping release monitoring...');
    
    _isMonitoring = false;
    _monitoringTimer.cancel();
    
    // Generate final report
    await _generateFinalReport();
    
    print('✅ Release monitoring completed');
  }
  
  Future<void> _generateFinalReport() async {
    final report = MonitoringReport(
      startTime: _metricHistory.first.timestamp,
      endTime: _metricHistory.last.timestamp,
      totalChecks: _metricHistory.length,
      metricsHistory: _metricHistory,
      summary: _generateSummary(),
    );
    
    final reportFile = File('release_monitoring/final_report_${DateTime.now().millisecondsSinceEpoch}.json');
    await reportFile.parent.create(recursive: true);
    await reportFile.writeAsString(jsonEncode(report.toJson()));
    
    print('📄 Final monitoring report saved: ${reportFile.path}');
  }
  
  String _generateSummary() {
    if (_metricHistory.isEmpty) return 'No data collected';
    
    final avgCrashRate = _metricHistory.map((m) => m.crashRate).reduce((a, b) => a + b) / _metricHistory.length;
    final avgRating = _metricHistory.map((m) => m.ratingAverage).reduce((a, b) => a + b) / _metricHistory.length;
    
    return 'Monitoring completed. Average crash rate: ${(avgCrashRate * 100).toStringAsFixed(2)}%, Average rating: ${avgRating.toStringAsFixed(1)}';
  }
  
  Future<void> _waitForMonitoringCompletion() async {
    while (_isMonitoring) {
      await Future.delayed(const Duration(seconds: 10));
    }
  }
}

// Data classes
class MonitoringConfig {
  final List<String> metrics;
  final AlertThresholds alertThresholds;
  final int monitoringDurationHours;
  final int checkIntervalMinutes;
  
  MonitoringConfig({
    required this.metrics,
    required this.alertThresholds,
    required this.monitoringDurationHours,
    required this.checkIntervalMinutes,
  });
  
  factory MonitoringConfig.fromJson(Map<String, dynamic> json) {
    return MonitoringConfig(
      metrics: List<String>.from(json['metrics']),
      alertThresholds: AlertThresholds.fromJson(json['alert_thresholds']),
      monitoringDurationHours: json['monitoring_duration_hours'],
      checkIntervalMinutes: json['check_interval_minutes'],
    );
  }
}

class AlertThresholds {
  final double crashRateMax;
  final double anrRateMax;
  final double ratingMin;
  
  AlertThresholds({
    required this.crashRateMax,
    required this.anrRateMax,
    required this.ratingMin,
  });
  
  factory AlertThresholds.fromJson(Map<String, dynamic> json) {
    return AlertThresholds(
      crashRateMax: json['crash_rate_max'],
      anrRateMax: json['anr_rate_max'],
      ratingMin: json['rating_min'],
    );
  }
}

class MetricSnapshot {
  final DateTime timestamp;
  final double crashRate;
  final double anrRate;
  final double installRate;
  final double ratingAverage;
  final double activeUsers;
  final double revenue;
  final double retentionDay1;
  final double retentionDay7;
  
  MetricSnapshot({
    required this.timestamp,
    required this.crashRate,
    required this.anrRate,
    required this.installRate,
    required this.ratingAverage,
    required this.activeUsers,
    required this.revenue,
    required this.retentionDay1,
    required this.retentionDay7,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'crash_rate': crashRate,
      'anr_rate': anrRate,
      'install_rate': installRate,
      'rating_average': ratingAverage,
      'active_users': activeUsers,
      'revenue': revenue,
      'retention_day1': retentionDay1,
      'retention_day7': retentionDay7,
    };
  }
}

class MetricAnalysis {
  final List<String> issues;
  final AlertSeverity severity;
  final bool requiresAlert;
  final bool requiresRollback;
  final String recommendation;
  
  MetricAnalysis({
    required this.issues,
    required this.severity,
    required this.requiresAlert,
    required this.requiresRollback,
    required this.recommendation,
  });
}

class TrendAnalysis {
  final bool isNegative;
  final String description;
  
  TrendAnalysis({
    required this.isNegative,
    required this.description,
  });
}

class AlertMessage {
  final AlertSeverity severity;
  final DateTime timestamp;
  final List<String> issues;
  final String recommendation;
  final MetricSnapshot metrics;
  
  AlertMessage({
    required this.severity,
    required this.timestamp,
    required this.issues,
    required this.recommendation,
    required this.metrics,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'issues': issues,
      'recommendation': recommendation,
      'metrics': metrics.toJson(),
    };
  }
}

class RollbackRecord {
  final DateTime timestamp;
  final String reason;
  final MetricSnapshot triggerMetrics;
  final bool automatic;
  
  RollbackRecord({
    required this.timestamp,
    required this.reason,
    required this.triggerMetrics,
    required this.automatic,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
      'trigger_metrics': triggerMetrics.toJson(),
      'automatic': automatic,
    };
  }
}

class MonitoringReport {
  final DateTime startTime;
  final DateTime endTime;
  final int totalChecks;
  final List<MetricSnapshot> metricsHistory;
  final String summary;
  
  MonitoringReport({
    required this.startTime,
    required this.endTime,
    required this.totalChecks,
    required this.metricsHistory,
    required this.summary,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'total_checks': totalChecks,
      'metrics_history': metricsHistory.map((m) => m.toJson()).toList(),
      'summary': summary,
    };
  }
}

enum AlertSeverity { normal, warning, critical }

extension ListExtension<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}