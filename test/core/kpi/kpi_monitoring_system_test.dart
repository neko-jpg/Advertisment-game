/// KPI監視・緊急対応システムのテスト
/// 要件8.1, 8.2, 8.3, 8.4の検証

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/kpi/kpi_monitoring_system.dart';
import '../../../lib/core/kpi/models/kpi_models.dart';

void main() {
  group('KPIMonitoringSystem Tests', () {
    late KPIMonitoringSystem kpiSystem;

    setUp(() {
      kpiSystem = KPIMonitoringSystem();
      kpiSystem.initialize();
    });

    tearDown(() {
      kpiSystem.dispose();
    });

    test('システム初期化とデフォルトターゲット設定', () {
      // システムが正常に初期化されることを確認
      expect(kpiSystem.isSystemHealthy(), isTrue);
      
      // デフォルトターゲットが設定されていることを確認
      final currentMetrics = kpiSystem.getCurrentMetrics();
      expect(currentMetrics, isNotNull);
    });

    test('CPI目標値上回り時のアラート生成', () {
      // CPI が目標値を上回るメトリクスを作成
      final highCPIMetric = KPIMetric(
        type: KPIType.cpi,
        currentValue: 3.5, // 目標値2.0を大幅上回り
        targetValue: 2.0,
        previousValue: 2.2,
        timestamp: DateTime.now(),
        metadata: {'campaign': 'test_campaign'},
      );

      // メトリクス更新
      kpiSystem.updateKPIMetric(highCPIMetric);

      // アラートが生成されることを確認
      final alerts = kpiSystem.getActiveAlerts();
      final cpiAlerts = alerts.where((a) => a.kpiType == KPIType.cpi).toList();
      
      expect(cpiAlerts, isNotEmpty);
      final alert = cpiAlerts.first;
      expect(alert.kpiType, equals(KPIType.cpi));
      expect(alert.severity, equals(AlertSeverity.critical));
      expect(alert.actualValue, equals(3.5));
      expect(alert.recommendedActions, contains(EmergencyActionType.boostSocialFeatures));
    });

    test('MAU低下時の緊急施策自動実行', () {
      // MAU が目標値を大幅に下回るメトリクス
      final lowMAUMetric = KPIMetric(
        type: KPIType.mau,
        currentValue: 50000, // 目標値100,000を大幅下回り
        targetValue: 100000,
        previousValue: 80000,
        timestamp: DateTime.now(),
      );

      // メトリクス更新
      kpiSystem.updateKPIMetric(lowMAUMetric);

      // 緊急アクションが実行されることを確認
      final actions = kpiSystem.getScheduledActions();
      expect(actions, isNotEmpty);
      
      final retentionActions = actions.where((a) => a.type == EmergencyActionType.increaseRetentionRewards).toList();
      expect(retentionActions, isNotEmpty);
      
      final action = retentionActions.first;
      expect(action.type, equals(EmergencyActionType.increaseRetentionRewards));
      expect(action.description, contains('リテンション報酬'));
      expect(action.expectedImpact, greaterThan(0.0));
    });

    test('ARPU改善時の正常動作', () {
      // ARPU が改善したメトリクス
      final improvedARPUMetric = KPIMetric(
        type: KPIType.arpu,
        currentValue: 6.0, // 目標値5.0を上回り
        targetValue: 5.0,
        previousValue: 4.5,
        timestamp: DateTime.now(),
      );

      // メトリクス更新
      kpiSystem.updateKPIMetric(improvedARPUMetric);

      // 改善時はアラートが生成されないことを確認
      final activeAlerts = kpiSystem.getActiveAlerts();
      final arpuAlerts = activeAlerts.where((a) => a.kpiType == KPIType.arpu).toList();
      expect(arpuAlerts, isEmpty);
    });

    test('アプリ評価低下時のユーザー満足度改善プラン実行', () {
      // 低いユーザー満足度メトリクス
      final lowSatisfactionMetrics = UserSatisfactionMetrics(
        overallSatisfaction: 3.2, // 4.0を下回る
        gameplayRating: 3.0,
        monetizationSatisfaction: 2.8,
        technicalPerformance: 3.1,
        totalFeedbacks: 1500,
        lastUpdated: DateTime.now(),
      );

      // 改善プラン実行前のアクション数
      final initialActions = kpiSystem.getScheduledActions().length;

      // ユーザー満足度改善プラン実行
      kpiSystem.executeUserSatisfactionImprovementPlan(lowSatisfactionMetrics);

      // 新しいアクションが追加されることを確認
      final finalActions = kpiSystem.getScheduledActions().length;
      expect(finalActions, greaterThan(initialActions));

      // 適切な改善アクションが含まれることを確認
      final actions = kpiSystem.getScheduledActions();
      final hasUXImprovement = actions.any((a) => a.type == EmergencyActionType.improveUserExperience);
      final hasAdAdjustment = actions.any((a) => a.type == EmergencyActionType.adjustAdFrequency);
      
      expect(hasUXImprovement || hasAdAdjustment, isTrue);
    });

    test('複数KPIの同時監視', () {
      // 複数のKPIメトリクスを同時に更新
      final metrics = [
        KPIMetric(
          type: KPIType.cpi,
          currentValue: 2.8,
          targetValue: 2.0,
          previousValue: 2.5,
          timestamp: DateTime.now(),
        ),
        KPIMetric(
          type: KPIType.mau,
          currentValue: 75000,
          targetValue: 100000,
          previousValue: 85000,
          timestamp: DateTime.now(),
        ),
        KPIMetric(
          type: KPIType.appRating,
          currentValue: 3.8,
          targetValue: 4.5,
          previousValue: 4.0,
          timestamp: DateTime.now(),
        ),
      ];

      // 全メトリクスを更新
      for (final metric in metrics) {
        kpiSystem.updateKPIMetric(metric);
      }

      // 現在のメトリクスが正しく保存されることを確認
      final currentMetrics = kpiSystem.getCurrentMetrics();
      expect(currentMetrics.length, equals(3));
      expect(currentMetrics[KPIType.cpi]?.currentValue, equals(2.8));
      expect(currentMetrics[KPIType.mau]?.currentValue, equals(75000));
      expect(currentMetrics[KPIType.appRating]?.currentValue, equals(3.8));
    });

    test('アラート解決機能', () {
      // アラートを生成
      final criticalMetric = KPIMetric(
        type: KPIType.cpi,
        currentValue: 3.0,
        targetValue: 2.0,
        previousValue: 2.5,
        timestamp: DateTime.now(),
      );

      kpiSystem.updateKPIMetric(criticalMetric);

      // アラートが生成されることを確認
      final activeAlerts = kpiSystem.getActiveAlerts();
      expect(activeAlerts, isNotEmpty);

      final alert = activeAlerts.first;
      expect(alert.isResolved, isFalse);

      // アラートを解決
      kpiSystem.resolveAlert(alert.id);

      // アラートが解決されることを確認
      final updatedAlerts = kpiSystem.getActiveAlerts();
      final resolvedAlert = updatedAlerts.firstWhere((a) => a.id == alert.id);
      expect(resolvedAlert.isResolved, isTrue);
    });

    test('システム健全性チェック', () {
      // 正常状態でのシステム健全性
      expect(kpiSystem.isSystemHealthy(), isTrue);

      // クリティカルアラートを生成
      final criticalMetric = KPIMetric(
        type: KPIType.mau,
        currentValue: 40000, // クリティカル閾値を下回る
        targetValue: 100000,
        previousValue: 60000,
        timestamp: DateTime.now(),
      );

      kpiSystem.updateKPIMetric(criticalMetric);

      // システムが不健全と判定されることを確認
      expect(kpiSystem.isSystemHealthy(), isFalse);
    });

    test('KPIターゲット更新機能', () {
      // 新しいターゲットを設定
      const newTarget = KPITarget(
        type: KPIType.arpu,
        targetValue: 7.0, // より高い目標値
        warningThreshold: 5.5,
        criticalThreshold: 4.0,
        monitoringInterval: Duration(hours: 6),
      );

      kpiSystem.updateKPITarget(newTarget);

      // 新しいターゲットに基づくアラート評価
      final testMetric = KPIMetric(
        type: KPIType.arpu,
        currentValue: 5.0, // 新しい目標値を下回る
        targetValue: 7.0,
        previousValue: 5.2,
        timestamp: DateTime.now(),
      );

      kpiSystem.updateKPIMetric(testMetric);

      // 新しいターゲットに基づいてアラートが生成されることを確認
      final alerts = kpiSystem.getActiveAlerts();
      final arpuAlerts = alerts.where((a) => a.kpiType == KPIType.arpu).toList();
      expect(arpuAlerts, isNotEmpty);
    });

    test('緊急アクションのパラメータ設定', () {
      // 緊急アクションを生成するメトリクス
      final emergencyMetric = KPIMetric(
        type: KPIType.mau,
        currentValue: 45000,
        targetValue: 100000,
        previousValue: 70000,
        timestamp: DateTime.now(),
      );

      kpiSystem.updateKPIMetric(emergencyMetric);

      // 生成されたアクションのパラメータを確認
      final actions = kpiSystem.getScheduledActions();
      expect(actions, isNotEmpty);

      final retentionAction = actions.firstWhere(
        (a) => a.type == EmergencyActionType.increaseRetentionRewards,
        orElse: () => throw StateError('Retention action not found'),
      );

      expect(retentionAction.parameters['rewardMultiplier'], equals(2.0));
      expect(retentionAction.parameters['duration'], equals('24h'));
      expect(retentionAction.parameters['triggerKPI'], equals('mau'));
    });
  });
}