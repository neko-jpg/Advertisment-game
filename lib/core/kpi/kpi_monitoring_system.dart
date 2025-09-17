/// KPI監視・自動アラートシステム
/// 要件8.1, 8.2, 8.3, 8.4に対応

import 'dart:async';
import 'dart:math';
import 'models/kpi_models.dart';

class KPIMonitoringSystem {
  final Map<KPIType, KPITarget> _targets = {};
  final Map<KPIType, KPIMetric> _currentMetrics = {};
  final List<KPIAlert> _activeAlerts = [];
  final List<EmergencyAction> _scheduledActions = [];
  
  Timer? _monitoringTimer;
  final StreamController<KPIAlert> _alertController = StreamController.broadcast();
  final StreamController<EmergencyAction> _actionController = StreamController.broadcast();

  Stream<KPIAlert> get alertStream => _alertController.stream;
  Stream<EmergencyAction> get actionStream => _actionController.stream;

  /// システム初期化とデフォルトターゲット設定
  void initialize() {
    _setupDefaultTargets();
    _startMonitoring();
  }

  void dispose() {
    _monitoringTimer?.cancel();
    _alertController.close();
    _actionController.close();
  }

  /// デフォルトKPIターゲットの設定
  void _setupDefaultTargets() {
    _targets[KPIType.cpi] = const KPITarget(
      type: KPIType.cpi,
      targetValue: 2.0, // $2.00 target CPI
      warningThreshold: 2.5,
      criticalThreshold: 3.0,
      monitoringInterval: Duration(hours: 6),
    );

    _targets[KPIType.mau] = const KPITarget(
      type: KPIType.mau,
      targetValue: 100000, // 100K MAU target
      warningThreshold: 80000,
      criticalThreshold: 60000,
      monitoringInterval: Duration(hours: 24),
    );

    _targets[KPIType.arpu] = const KPITarget(
      type: KPIType.arpu,
      targetValue: 5.0, // $5.00 ARPU target
      warningThreshold: 4.0,
      criticalThreshold: 3.0,
      monitoringInterval: Duration(hours: 12),
    );

    _targets[KPIType.appRating] = const KPITarget(
      type: KPIType.appRating,
      targetValue: 4.5,
      warningThreshold: 4.0,
      criticalThreshold: 3.5,
      monitoringInterval: Duration(hours: 8),
    );
  }

  /// 監視開始
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _checkAllKPIs();
    });
  }

  /// KPIメトリクス更新
  void updateKPIMetric(KPIMetric metric) {
    final previous = _currentMetrics[metric.type];
    _currentMetrics[metric.type] = metric;
    
    // 即座にアラート評価を実行
    _evaluateKPIAlert(metric, previous);
  }

  /// 全KPIチェック
  void _checkAllKPIs() {
    for (final metric in _currentMetrics.values) {
      _evaluateKPIAlert(metric, null);
    }
  }

  /// KPIアラート評価
  void _evaluateKPIAlert(KPIMetric metric, KPIMetric? previous) {
    final target = _targets[metric.type];
    if (target == null) return;

    final severity = target.getSeverityForValue(metric.currentValue);
    
    // アラート生成条件を緩和（medium以上でアラート生成）
    if (severity == AlertSeverity.medium || severity == AlertSeverity.high || severity == AlertSeverity.critical) {
      final alert = _createAlert(metric, target, severity);
      _activeAlerts.add(alert);
      _alertController.add(alert);
      
      // 緊急施策の自動実行
      if (severity == AlertSeverity.critical) {
        _executeEmergencyActions(metric.type, metric.currentValue);
      }
    }
  }

  /// アラート作成
  KPIAlert _createAlert(KPIMetric metric, KPITarget target, AlertSeverity severity) {
    final message = _generateAlertMessage(metric, target);
    final actions = _getRecommendedActions(metric.type, severity);
    
    return KPIAlert(
      id: 'alert_${metric.type.name}_${DateTime.now().millisecondsSinceEpoch}',
      kpiType: metric.type,
      severity: severity,
      message: message,
      threshold: target.warningThreshold,
      actualValue: metric.currentValue,
      triggeredAt: DateTime.now(),
      recommendedActions: actions,
    );
  }

  /// アラートメッセージ生成
  String _generateAlertMessage(KPIMetric metric, KPITarget target) {
    final performance = (metric.currentValue / target.targetValue * 100).toStringAsFixed(1);
    
    switch (metric.type) {
      case KPIType.cpi:
        return 'CPI が目標値を上回っています: \$${metric.currentValue.toStringAsFixed(2)} (目標: \$${target.targetValue.toStringAsFixed(2)})';
      case KPIType.mau:
        return 'MAU が目標値を下回っています: ${metric.currentValue.toInt()} (目標: ${target.targetValue.toInt()}) - ${performance}%';
      case KPIType.arpu:
        return 'ARPU が目標値を下回っています: \$${metric.currentValue.toStringAsFixed(2)} (目標: \$${target.targetValue.toStringAsFixed(2)}) - ${performance}%';
      case KPIType.appRating:
        return 'アプリ評価が低下しています: ${metric.currentValue.toStringAsFixed(1)} (目標: ${target.targetValue.toStringAsFixed(1)})';
      default:
        return '${metric.type.name} が目標値から乖離しています: ${performance}%';
    }
  }

  /// 推奨アクション取得
  List<EmergencyActionType> _getRecommendedActions(KPIType kpiType, AlertSeverity severity) {
    switch (kpiType) {
      case KPIType.cpi:
        return [
          EmergencyActionType.boostSocialFeatures,
          EmergencyActionType.activateSpecialEvents,
        ];
      case KPIType.mau:
        return [
          EmergencyActionType.increaseRetentionRewards,
          EmergencyActionType.activateSpecialEvents,
          EmergencyActionType.enhanceOnboarding,
        ];
      case KPIType.arpu:
        return [
          EmergencyActionType.adjustAdFrequency,
          EmergencyActionType.activateSpecialEvents,
        ];
      case KPIType.appRating:
        return [
          EmergencyActionType.improveUserExperience,
          EmergencyActionType.enhanceOnboarding,
        ];
      default:
        return [EmergencyActionType.activateSpecialEvents];
    }
  }

  /// 緊急施策自動実行
  void _executeEmergencyActions(KPIType kpiType, double currentValue) {
    final actions = _getRecommendedActions(kpiType, AlertSeverity.critical);
    
    for (final actionType in actions) {
      final action = _createEmergencyAction(actionType, kpiType, currentValue);
      _scheduledActions.add(action);
      _actionController.add(action);
      
      // 実際の施策実行
      _performEmergencyAction(action);
    }
  }

  /// 緊急アクション作成
  EmergencyAction _createEmergencyAction(
    EmergencyActionType type, 
    KPIType triggerKPI, 
    double currentValue
  ) {
    final parameters = <String, dynamic>{
      'triggerKPI': triggerKPI.name,
      'currentValue': currentValue,
      'timestamp': DateTime.now().toIso8601String(),
    };

    switch (type) {
      case EmergencyActionType.increaseRetentionRewards:
        parameters['rewardMultiplier'] = 2.0;
        parameters['duration'] = '24h';
        return EmergencyAction(
          type: type,
          description: 'リテンション報酬を2倍に増加（24時間）',
          parameters: parameters,
          scheduledAt: DateTime.now(),
          expectedImpact: 0.15,
        );
        
      case EmergencyActionType.adjustAdFrequency:
        parameters['frequencyReduction'] = 0.3;
        return EmergencyAction(
          type: type,
          description: '広告頻度を30%削減してユーザー体験を改善',
          parameters: parameters,
          scheduledAt: DateTime.now(),
          expectedImpact: 0.10,
        );
        
      case EmergencyActionType.activateSpecialEvents:
        parameters['eventType'] = 'emergency_boost';
        parameters['duration'] = '48h';
        return EmergencyAction(
          type: type,
          description: '緊急ブーストイベントを48時間開催',
          parameters: parameters,
          scheduledAt: DateTime.now(),
          expectedImpact: 0.25,
        );
        
      case EmergencyActionType.improveUserExperience:
        return EmergencyAction(
          type: type,
          description: 'ユーザー体験改善施策を実行',
          parameters: parameters,
          scheduledAt: DateTime.now(),
          expectedImpact: 0.20,
        );
        
      case EmergencyActionType.enhanceOnboarding:
        return EmergencyAction(
          type: type,
          description: 'オンボーディング体験を強化',
          parameters: parameters,
          scheduledAt: DateTime.now(),
          expectedImpact: 0.18,
        );
        
      case EmergencyActionType.boostSocialFeatures:
        parameters['socialRewardMultiplier'] = 1.5;
        return EmergencyAction(
          type: type,
          description: 'ソーシャル機能報酬を1.5倍に増加',
          parameters: parameters,
          scheduledAt: DateTime.now(),
          expectedImpact: 0.12,
        );
    }
  }

  /// 緊急アクション実行
  void _performEmergencyAction(EmergencyAction action) {
    // 実際の施策実行ロジック
    // 他のシステムとの連携が必要
    print('緊急施策実行: ${action.description}');
    
    // アクション完了をマーク
    final completedAction = action.copyWith(
      executedAt: DateTime.now(),
      isCompleted: true,
    );
    
    final index = _scheduledActions.indexWhere((a) => a.type == action.type);
    if (index != -1) {
      _scheduledActions[index] = completedAction;
    }
  }

  /// ユーザー満足度改善プラン自動実行
  void executeUserSatisfactionImprovementPlan(UserSatisfactionMetrics metrics) {
    if (!metrics.needsImprovement) return;

    final actions = <EmergencyAction>[];
    
    if (metrics.gameplayRating < 3.5) {
      actions.add(_createEmergencyAction(
        EmergencyActionType.improveUserExperience,
        KPIType.appRating,
        metrics.gameplayRating,
      ));
    }
    
    if (metrics.monetizationSatisfaction < 3.0) {
      actions.add(_createEmergencyAction(
        EmergencyActionType.adjustAdFrequency,
        KPIType.appRating,
        metrics.monetizationSatisfaction,
      ));
    }
    
    if (metrics.technicalPerformance < 3.5) {
      actions.add(_createEmergencyAction(
        EmergencyActionType.improveUserExperience,
        KPIType.appRating,
        metrics.technicalPerformance,
      ));
    }

    for (final action in actions) {
      _scheduledActions.add(action);
      _actionController.add(action);
      _performEmergencyAction(action);
    }
  }

  /// 現在のKPIメトリクス取得
  Map<KPIType, KPIMetric> getCurrentMetrics() => Map.from(_currentMetrics);

  /// アクティブアラート取得
  List<KPIAlert> getActiveAlerts() => List.from(_activeAlerts);

  /// スケジュール済みアクション取得
  List<EmergencyAction> getScheduledActions() => List.from(_scheduledActions);

  /// アラート解決
  void resolveAlert(String alertId) {
    final index = _activeAlerts.indexWhere((alert) => alert.id == alertId);
    if (index != -1) {
      _activeAlerts[index] = _activeAlerts[index].copyWith(isResolved: true);
    }
  }

  /// KPIターゲット更新
  void updateKPITarget(KPITarget target) {
    _targets[target.type] = target;
  }

  /// システム健全性チェック
  bool isSystemHealthy() {
    final criticalAlerts = _activeAlerts
        .where((alert) => !alert.isResolved && alert.severity == AlertSeverity.critical)
        .length;
    
    return criticalAlerts == 0;
  }
}