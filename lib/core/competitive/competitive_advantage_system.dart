/// セルラン維持・競争力強化統合システム
/// KPI監視と競合分析を統合した包括的な競争力強化システム
/// 要件8.1, 8.2, 8.3, 8.4, 8.5, 8.6に対応

import 'dart:async';
import '../kpi/kpi_monitoring_system.dart';
import '../kpi/models/kpi_models.dart';
import 'competitive_analysis_system.dart';
import 'models/competitive_models.dart';

class CompetitiveAdvantageSystem {
  final KPIMonitoringSystem _kpiSystem;
  final CompetitiveAnalysisSystem _competitiveSystem;
  
  Timer? _integrationTimer;
  final StreamController<CompetitiveAdvantageReport> _reportController = StreamController.broadcast();
  final StreamController<StrategicAction> _actionController = StreamController.broadcast();

  Stream<CompetitiveAdvantageReport> get reportStream => _reportController.stream;
  Stream<StrategicAction> get actionStream => _actionController.stream;

  CompetitiveAdvantageSystem({
    KPIMonitoringSystem? kpiSystem,
    CompetitiveAnalysisSystem? competitiveSystem,
  }) : _kpiSystem = kpiSystem ?? KPIMonitoringSystem(),
        _competitiveSystem = competitiveSystem ?? CompetitiveAnalysisSystem();

  /// システム初期化
  void initialize() {
    _kpiSystem.initialize();
    _competitiveSystem.initialize();
    _startIntegratedAnalysis();
    _setupCrossSystemListeners();
  }

  void dispose() {
    _integrationTimer?.cancel();
    _reportController.close();
    _actionController.close();
    _kpiSystem.dispose();
    _competitiveSystem.dispose();
  }

  /// 統合分析開始
  void _startIntegratedAnalysis() {
    _integrationTimer = Timer.periodic(const Duration(hours: 2), (_) {
      _performIntegratedAnalysis();
    });
  }

  /// システム間リスナー設定
  void _setupCrossSystemListeners() {
    // KPIアラートに基づく競合対応
    _kpiSystem.alertStream.listen((alert) {
      _handleKPIAlert(alert);
    });

    // 競合分析に基づくKPI調整
    _competitiveSystem.reportStream.listen((report) {
      _handleCompetitiveReport(report);
    });

    // コンテンツ更新要求の処理
    _competitiveSystem.updateStream.listen((updateRequest) {
      _handleContentUpdateRequest(updateRequest);
    });
  }

  /// 統合分析実行
  void _performIntegratedAnalysis() {
    final kpiMetrics = _kpiSystem.getCurrentMetrics();
    final competitiveReport = _competitiveSystem.getCurrentReport();
    
    final integratedReport = _generateIntegratedReport(kpiMetrics, competitiveReport);
    _reportController.add(integratedReport);

    // 戦略的アクションの提案
    final strategicActions = _generateStrategicActions(integratedReport);
    for (final action in strategicActions) {
      _actionController.add(action);
    }
  }

  /// KPIアラート処理
  void _handleKPIAlert(KPIAlert alert) {
    // 競合状況を考慮した対応策の調整
    final competitors = _competitiveSystem.getCompetitors();
    final strongCompetitors = competitors.where((c) => c.isStrongCompetitor).toList();

    if (strongCompetitors.isNotEmpty && alert.severity == AlertSeverity.critical) {
      // 競合が強い場合、より積極的な対応
      final enhancedAction = StrategicAction(
        id: 'enhanced_${alert.id}',
        type: StrategicActionType.aggressiveCounterMeasure,
        description: '強力な競合に対する積極的対抗策: ${alert.message}',
        priority: StrategicPriority.critical,
        estimatedImpact: 0.3,
        implementationTime: const Duration(hours: 6),
        kpiTargets: [alert.kpiType],
        competitiveContext: {
          'strong_competitors': strongCompetitors.length,
          'market_pressure': 'high',
          'response_urgency': 'immediate',
        },
      );

      _actionController.add(enhancedAction);
    }
  }

  /// 競合レポート処理
  void _handleCompetitiveReport(CompetitiveAnalysisReport report) {
    // 高優先度の差別化機会に基づくKPI目標調整
    final highPriorityOpportunities = report.highPriorityOpportunities;
    
    for (final opportunity in highPriorityOpportunities) {
      _adjustKPITargetsBasedOnOpportunity(opportunity);
    }

    // 市場トレンドに基づく緊急対応
    final highImpactTrends = report.activeTrends.where((t) => t.isHighImpact).toList();
    for (final trend in highImpactTrends) {
      _respondToMarketTrend(trend);
    }
  }

  /// コンテンツ更新要求処理
  void _handleContentUpdateRequest(ContentUpdateRequest request) {
    if (request.isUrgent) {
      // 緊急更新の場合、即座に実行
      _competitiveSystem.executeRapidContentUpdate(request);
      
      // KPIへの影響を監視
      _scheduleKPIImpactMonitoring(request);
    }
  }

  /// 統合レポート生成
  CompetitiveAdvantageReport _generateIntegratedReport(
    Map<KPIType, KPIMetric> kpiMetrics,
    CompetitiveAnalysisReport competitiveReport,
  ) {
    final competitivePosition = _calculateCompetitivePosition(kpiMetrics, competitiveReport);
    final marketOpportunities = _identifyMarketOpportunities(competitiveReport);
    final riskAssessment = _assessCompetitiveRisks(kpiMetrics, competitiveReport);
    final strategicRecommendations = _generateStrategicRecommendations(
      competitivePosition, 
      marketOpportunities, 
      riskAssessment
    );

    return CompetitiveAdvantageReport(
      generatedAt: DateTime.now(),
      kpiMetrics: kpiMetrics,
      competitivePosition: competitivePosition,
      marketOpportunities: marketOpportunities,
      riskAssessment: riskAssessment,
      strategicRecommendations: strategicRecommendations,
      systemHealth: _kpiSystem.isSystemHealthy(),
    );
  }

  /// 競争ポジション計算
  CompetitivePosition _calculateCompetitivePosition(
    Map<KPIType, KPIMetric> kpiMetrics,
    CompetitiveAnalysisReport competitiveReport,
  ) {
    final ourARPU = kpiMetrics[KPIType.arpu]?.currentValue ?? 0.0;
    final ourRating = kpiMetrics[KPIType.appRating]?.currentValue ?? 0.0;
    
    final competitorARPUs = competitiveReport.competitors.map((c) => c.arpu).toList();
    final competitorRatings = competitiveReport.competitors.map((c) => c.rating).toList();
    
    final arpuRank = _calculateRank(ourARPU, competitorARPUs, higher: true);
    final ratingRank = _calculateRank(ourRating, competitorRatings, higher: true);
    
    return CompetitivePosition(
      overallRank: ((arpuRank + ratingRank) / 2).round(),
      arpuRank: arpuRank,
      ratingRank: ratingRank,
      marketShareEstimate: competitiveReport.marketPositioning['market_share'] ?? 0.0,
      strengthAreas: _identifyStrengthAreas(kpiMetrics, competitiveReport),
      weaknessAreas: _identifyWeaknessAreas(kpiMetrics, competitiveReport),
    );
  }

  /// ランク計算
  int _calculateRank(double ourValue, List<double> competitorValues, {required bool higher}) {
    final allValues = [...competitorValues, ourValue];
    allValues.sort((a, b) => higher ? b.compareTo(a) : a.compareTo(b));
    return allValues.indexOf(ourValue) + 1;
  }

  /// 強み領域特定
  List<String> _identifyStrengthAreas(
    Map<KPIType, KPIMetric> kpiMetrics,
    CompetitiveAnalysisReport competitiveReport,
  ) {
    final strengths = <String>[];
    
    // 独自性の強み
    strengths.add('描画メカニクスによる独自性');
    
    // KPIベースの強み
    final arpu = kpiMetrics[KPIType.arpu];
    if (arpu != null && arpu.performanceRatio > 1.1) {
      strengths.add('収益効率の高さ');
    }
    
    final rating = kpiMetrics[KPIType.appRating];
    if (rating != null && rating.currentValue > 4.2) {
      strengths.add('ユーザー満足度');
    }

    return strengths;
  }

  /// 弱み領域特定
  List<String> _identifyWeaknessAreas(
    Map<KPIType, KPIMetric> kpiMetrics,
    CompetitiveAnalysisReport competitiveReport,
  ) {
    final weaknesses = <String>[];
    
    final mau = kpiMetrics[KPIType.mau];
    if (mau != null && mau.performanceRatio < 0.8) {
      weaknesses.add('ユーザー獲得・維持');
    }
    
    final cpi = kpiMetrics[KPIType.cpi];
    if (cpi != null && cpi.performanceRatio > 1.2) {
      weaknesses.add('獲得コスト効率');
    }

    // 市場シェアが小さい場合
    final marketShare = competitiveReport.marketPositioning['market_share'] ?? 0.0;
    if (marketShare < 0.05) {
      weaknesses.add('市場認知度・シェア');
    }

    return weaknesses;
  }

  /// 市場機会特定
  List<MarketOpportunity> _identifyMarketOpportunities(CompetitiveAnalysisReport report) {
    final opportunities = <MarketOpportunity>[];
    
    // 差別化機会から市場機会を抽出
    for (final diffOpp in report.opportunities) {
      if (diffOpp.isHighPriority) {
        opportunities.add(MarketOpportunity(
          type: MarketOpportunityType.differentiation,
          description: diffOpp.description,
          impactScore: diffOpp.impactScore,
          feasibilityScore: diffOpp.feasibilityScore,
          timeWindow: diffOpp.estimatedImplementationTime,
        ));
      }
    }
    
    // トレンドベースの機会
    for (final trend in report.activeTrends) {
      if (trend.isHighImpact && trend.isCurrentlyActive) {
        opportunities.add(MarketOpportunity(
          type: MarketOpportunityType.trendCapture,
          description: 'トレンド活用: ${trend.description}',
          impactScore: trend.impactScore,
          feasibilityScore: 0.7, // デフォルト値
          timeWindow: trend.estimatedDuration,
        ));
      }
    }

    return opportunities;
  }

  /// 競争リスク評価
  CompetitiveRiskAssessment _assessCompetitiveRisks(
    Map<KPIType, KPIMetric> kpiMetrics,
    CompetitiveAnalysisReport competitiveReport,
  ) {
    final risks = <CompetitiveRisk>[];
    
    // 強力な競合からのリスク
    final strongCompetitors = competitiveReport.competitors
        .where((c) => c.isStrongCompetitor)
        .toList();
    
    if (strongCompetitors.isNotEmpty) {
      risks.add(CompetitiveRisk(
        type: CompetitiveRiskType.strongCompetitor,
        description: '強力な競合${strongCompetitors.length}社からの市場圧力',
        severity: strongCompetitors.length > 2 ? RiskSeverity.high : RiskSeverity.medium,
        probability: 0.8,
        potentialImpact: 0.3,
      ));
    }
    
    // 新興競合のリスク
    final emergingThreats = competitiveReport.competitors
        .where((c) => c.isGrowingThreat)
        .toList();
    
    if (emergingThreats.isNotEmpty) {
      risks.add(CompetitiveRisk(
        type: CompetitiveRiskType.emergingThreat,
        description: '新興競合による市場シェア侵食リスク',
        severity: RiskSeverity.medium,
        probability: 0.6,
        potentialImpact: 0.2,
      ));
    }
    
    // KPIベースのリスク
    final criticalKPIs = kpiMetrics.values
        .where((metric) => metric.performanceRatio < 0.7)
        .toList();
    
    if (criticalKPIs.isNotEmpty) {
      risks.add(CompetitiveRisk(
        type: CompetitiveRiskType.performanceDecline,
        description: '重要KPIの悪化による競争力低下',
        severity: RiskSeverity.high,
        probability: 0.9,
        potentialImpact: 0.4,
      ));
    }

    return CompetitiveRiskAssessment(
      overallRiskLevel: _calculateOverallRiskLevel(risks),
      risks: risks,
      mitigationStrategies: _generateMitigationStrategies(risks),
    );
  }

  /// 全体リスクレベル計算
  RiskSeverity _calculateOverallRiskLevel(List<CompetitiveRisk> risks) {
    if (risks.any((r) => r.severity == RiskSeverity.high)) {
      return RiskSeverity.high;
    } else if (risks.any((r) => r.severity == RiskSeverity.medium)) {
      return RiskSeverity.medium;
    } else {
      return RiskSeverity.low;
    }
  }

  /// リスク軽減戦略生成
  List<String> _generateMitigationStrategies(List<CompetitiveRisk> risks) {
    final strategies = <String>[];
    
    for (final risk in risks) {
      switch (risk.type) {
        case CompetitiveRiskType.strongCompetitor:
          strategies.add('差別化機能の強化と独自価値提案の明確化');
          break;
        case CompetitiveRiskType.emergingThreat:
          strategies.add('イノベーション加速と市場先行優位の確立');
          break;
        case CompetitiveRiskType.performanceDecline:
          strategies.add('KPI改善施策の緊急実行と根本原因の解決');
          break;
      }
    }
    
    return strategies;
  }

  /// 戦略的推奨事項生成
  List<String> _generateStrategicRecommendations(
    CompetitivePosition position,
    List<MarketOpportunity> opportunities,
    CompetitiveRiskAssessment riskAssessment,
  ) {
    final recommendations = <String>[];
    
    // ポジションベースの推奨
    if (position.overallRank > 3) {
      recommendations.add('市場ポジション向上のための積極的差別化戦略の実行');
    }
    
    // 機会ベースの推奨
    final topOpportunity = opportunities.isNotEmpty 
        ? opportunities.reduce((a, b) => a.impactScore > b.impactScore ? a : b)
        : null;
    
    if (topOpportunity != null) {
      recommendations.add('最高インパクト機会の優先実行: ${topOpportunity.description}');
    }
    
    // リスクベースの推奨
    if (riskAssessment.overallRiskLevel == RiskSeverity.high) {
      recommendations.add('高リスク状況への緊急対応: ${riskAssessment.mitigationStrategies.first}');
    }
    
    return recommendations;
  }

  /// 戦略的アクション生成
  List<StrategicAction> _generateStrategicActions(CompetitiveAdvantageReport report) {
    final actions = <StrategicAction>[];
    
    // 高優先度機会への対応
    for (final opportunity in report.marketOpportunities) {
      if (opportunity.impactScore > 0.7) {
        actions.add(StrategicAction(
          id: 'opportunity_${DateTime.now().millisecondsSinceEpoch}',
          type: StrategicActionType.opportunityCapture,
          description: opportunity.description,
          priority: StrategicPriority.high,
          estimatedImpact: opportunity.impactScore,
          implementationTime: opportunity.timeWindow,
          kpiTargets: [KPIType.arpu, KPIType.mau],
          competitiveContext: {
            'opportunity_type': opportunity.type.name,
            'feasibility': opportunity.feasibilityScore,
          },
        ));
      }
    }
    
    return actions;
  }

  /// 機会ベースKPI目標調整
  void _adjustKPITargetsBasedOnOpportunity(DifferentiationOpportunity opportunity) {
    // 差別化機会に基づいてKPI目標を調整
    // 実装は具体的な機会タイプに応じて調整
  }

  /// 市場トレンド対応
  void _respondToMarketTrend(MarketTrendData trend) {
    // トレンドに基づく迅速な対応策を実行
    print('市場トレンド対応: ${trend.description}');
  }

  /// KPI影響監視スケジュール
  void _scheduleKPIImpactMonitoring(ContentUpdateRequest request) {
    // コンテンツ更新後のKPI影響を監視
    Timer(const Duration(hours: 24), () {
      _monitorUpdateImpact(request);
    });
  }

  /// 更新影響監視
  void _monitorUpdateImpact(ContentUpdateRequest request) {
    // 更新前後のKPI変化を分析
    print('コンテンツ更新影響監視: ${request.contentType}');
  }

  /// 現在の競争優位レポート取得
  CompetitiveAdvantageReport getCurrentAdvantageReport() {
    final kpiMetrics = _kpiSystem.getCurrentMetrics();
    final competitiveReport = _competitiveSystem.getCurrentReport();
    return _generateIntegratedReport(kpiMetrics, competitiveReport);
  }
}

// 追加のデータモデル
class CompetitiveAdvantageReport {
  final DateTime generatedAt;
  final Map<KPIType, KPIMetric> kpiMetrics;
  final CompetitivePosition competitivePosition;
  final List<MarketOpportunity> marketOpportunities;
  final CompetitiveRiskAssessment riskAssessment;
  final List<String> strategicRecommendations;
  final bool systemHealth;

  const CompetitiveAdvantageReport({
    required this.generatedAt,
    required this.kpiMetrics,
    required this.competitivePosition,
    required this.marketOpportunities,
    required this.riskAssessment,
    required this.strategicRecommendations,
    required this.systemHealth,
  });
}

class CompetitivePosition {
  final int overallRank;
  final int arpuRank;
  final int ratingRank;
  final double marketShareEstimate;
  final List<String> strengthAreas;
  final List<String> weaknessAreas;

  const CompetitivePosition({
    required this.overallRank,
    required this.arpuRank,
    required this.ratingRank,
    required this.marketShareEstimate,
    required this.strengthAreas,
    required this.weaknessAreas,
  });
}

enum MarketOpportunityType { differentiation, trendCapture, competitorWeakness }

class MarketOpportunity {
  final MarketOpportunityType type;
  final String description;
  final double impactScore;
  final double feasibilityScore;
  final Duration timeWindow;

  const MarketOpportunity({
    required this.type,
    required this.description,
    required this.impactScore,
    required this.feasibilityScore,
    required this.timeWindow,
  });
}

enum CompetitiveRiskType { strongCompetitor, emergingThreat, performanceDecline }
enum RiskSeverity { low, medium, high }

class CompetitiveRisk {
  final CompetitiveRiskType type;
  final String description;
  final RiskSeverity severity;
  final double probability;
  final double potentialImpact;

  const CompetitiveRisk({
    required this.type,
    required this.description,
    required this.severity,
    required this.probability,
    required this.potentialImpact,
  });
}

class CompetitiveRiskAssessment {
  final RiskSeverity overallRiskLevel;
  final List<CompetitiveRisk> risks;
  final List<String> mitigationStrategies;

  const CompetitiveRiskAssessment({
    required this.overallRiskLevel,
    required this.risks,
    required this.mitigationStrategies,
  });
}

enum StrategicActionType { opportunityCapture, riskMitigation, aggressiveCounterMeasure }
enum StrategicPriority { low, medium, high, critical }

class StrategicAction {
  final String id;
  final StrategicActionType type;
  final String description;
  final StrategicPriority priority;
  final double estimatedImpact;
  final Duration implementationTime;
  final List<KPIType> kpiTargets;
  final Map<String, dynamic> competitiveContext;

  const StrategicAction({
    required this.id,
    required this.type,
    required this.description,
    required this.priority,
    required this.estimatedImpact,
    required this.implementationTime,
    required this.kpiTargets,
    required this.competitiveContext,
  });
}