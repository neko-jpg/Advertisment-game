/// 競合分析・差別化戦略システムのデータモデル
/// 要件8.5, 8.6に対応

enum CompetitorType {
  direct,     // 直接競合（同ジャンル）
  indirect,   // 間接競合（類似ユーザー層）
  emerging,   // 新興競合
}

enum MarketTrend {
  seasonal,
  viral,
  technological,
  monetization,
  gameplay,
  social,
}

enum DifferentiationStrategy {
  uniqueGameplay,
  betterMonetization,
  superiorUX,
  socialFeatures,
  contentVariety,
  technicalPerformance,
}

class CompetitorData {
  final String id;
  final String name;
  final CompetitorType type;
  final double marketShare;
  final int downloads;
  final double rating;
  final double arpu;
  final List<String> keyFeatures;
  final Map<String, dynamic> monetizationStrategy;
  final DateTime lastUpdated;

  const CompetitorData({
    required this.id,
    required this.name,
    required this.type,
    required this.marketShare,
    required this.downloads,
    required this.rating,
    required this.arpu,
    required this.keyFeatures,
    required this.monetizationStrategy,
    required this.lastUpdated,
  });

  bool get isStrongCompetitor => marketShare > 0.05 && rating > 4.0;
  bool get isGrowingThreat => downloads > 1000000 && type == CompetitorType.emerging;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'marketShare': marketShare,
    'downloads': downloads,
    'rating': rating,
    'arpu': arpu,
    'keyFeatures': keyFeatures,
    'monetizationStrategy': monetizationStrategy,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory CompetitorData.fromJson(Map<String, dynamic> json) => CompetitorData(
    id: json['id'],
    name: json['name'],
    type: CompetitorType.values.byName(json['type']),
    marketShare: json['marketShare'].toDouble(),
    downloads: json['downloads'],
    rating: json['rating'].toDouble(),
    arpu: json['arpu'].toDouble(),
    keyFeatures: List<String>.from(json['keyFeatures']),
    monetizationStrategy: Map<String, dynamic>.from(json['monetizationStrategy']),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}

class MarketTrendData {
  final MarketTrend type;
  final String description;
  final double impactScore;
  final DateTime detectedAt;
  final Duration estimatedDuration;
  final List<String> affectedCompetitors;
  final Map<String, dynamic> trendMetrics;

  const MarketTrendData({
    required this.type,
    required this.description,
    required this.impactScore,
    required this.detectedAt,
    required this.estimatedDuration,
    required this.affectedCompetitors,
    required this.trendMetrics,
  });

  bool get isHighImpact => impactScore > 0.7;
  bool get isCurrentlyActive => DateTime.now().difference(detectedAt) < estimatedDuration;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'description': description,
    'impactScore': impactScore,
    'detectedAt': detectedAt.toIso8601String(),
    'estimatedDuration': estimatedDuration.inMilliseconds,
    'affectedCompetitors': affectedCompetitors,
    'trendMetrics': trendMetrics,
  };
}

class DifferentiationOpportunity {
  final DifferentiationStrategy strategy;
  final String description;
  final double feasibilityScore;
  final double impactScore;
  final Duration estimatedImplementationTime;
  final List<String> requiredResources;
  final Map<String, dynamic> competitiveAdvantage;

  const DifferentiationOpportunity({
    required this.strategy,
    required this.description,
    required this.feasibilityScore,
    required this.impactScore,
    required this.estimatedImplementationTime,
    required this.requiredResources,
    required this.competitiveAdvantage,
  });

  double get priorityScore => (feasibilityScore * impactScore) / estimatedImplementationTime.inDays;
  bool get isHighPriority => priorityScore > 0.1;

  Map<String, dynamic> toJson() => {
    'strategy': strategy.name,
    'description': description,
    'feasibilityScore': feasibilityScore,
    'impactScore': impactScore,
    'estimatedImplementationTime': estimatedImplementationTime.inMilliseconds,
    'requiredResources': requiredResources,
    'competitiveAdvantage': competitiveAdvantage,
  };
}

class SeasonalEvent {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final MarketTrend associatedTrend;
  final Map<String, dynamic> eventConfig;
  final double expectedImpact;

  const SeasonalEvent({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.associatedTrend,
    required this.eventConfig,
    required this.expectedImpact,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    final daysUntilStart = startDate.difference(now).inDays;
    return daysUntilStart > 0 && daysUntilStart <= 7;
  }

  Duration get timeUntilStart => startDate.difference(DateTime.now());
  Duration get duration => endDate.difference(startDate);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'associatedTrend': associatedTrend.name,
    'eventConfig': eventConfig,
    'expectedImpact': expectedImpact,
  };
}

class CompetitiveAnalysisReport {
  final DateTime generatedAt;
  final List<CompetitorData> competitors;
  final List<MarketTrendData> activeTrends;
  final List<DifferentiationOpportunity> opportunities;
  final Map<String, double> marketPositioning;
  final List<String> recommendations;

  const CompetitiveAnalysisReport({
    required this.generatedAt,
    required this.competitors,
    required this.activeTrends,
    required this.opportunities,
    required this.marketPositioning,
    required this.recommendations,
  });

  List<CompetitorData> get strongCompetitors => 
      competitors.where((c) => c.isStrongCompetitor).toList();

  List<DifferentiationOpportunity> get highPriorityOpportunities =>
      opportunities.where((o) => o.isHighPriority).toList();

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'competitors': competitors.map((c) => c.toJson()).toList(),
    'activeTrends': activeTrends.map((t) => t.toJson()).toList(),
    'opportunities': opportunities.map((o) => o.toJson()).toList(),
    'marketPositioning': marketPositioning,
    'recommendations': recommendations,
  };
}

class ContentUpdateRequest {
  final String id;
  final MarketTrend triggerTrend;
  final String contentType;
  final Map<String, dynamic> updateParameters;
  final DateTime requestedAt;
  final DateTime targetDeployment;
  final bool isUrgent;

  const ContentUpdateRequest({
    required this.id,
    required this.triggerTrend,
    required this.contentType,
    required this.updateParameters,
    required this.requestedAt,
    required this.targetDeployment,
    this.isUrgent = false,
  });

  Duration get timeToDeployment => targetDeployment.difference(DateTime.now());
  bool get isOverdue => DateTime.now().isAfter(targetDeployment);

  Map<String, dynamic> toJson() => {
    'id': id,
    'triggerTrend': triggerTrend.name,
    'contentType': contentType,
    'updateParameters': updateParameters,
    'requestedAt': requestedAt.toIso8601String(),
    'targetDeployment': targetDeployment.toIso8601String(),
    'isUrgent': isUrgent,
  };
}