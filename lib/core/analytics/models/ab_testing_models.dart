import 'dart:convert';

/// Configuration for an A/B test
class ABTestConfiguration {
  const ABTestConfiguration({
    required this.testId,
    required this.name,
    required this.description,
    required this.variants,
    required this.trafficAllocation,
    required this.targetMetrics,
    required this.startDate,
    required this.endDate,
    required this.minimumSampleSize,
    required this.significanceLevel,
    this.segmentFilters = const {},
    this.isActive = true,
  });

  final String testId;
  final String name;
  final String description;
  final List<ABTestVariant> variants;
  final Map<String, double> trafficAllocation; // variant -> percentage
  final List<String> targetMetrics;
  final DateTime startDate;
  final DateTime endDate;
  final int minimumSampleSize;
  final double significanceLevel; // typically 0.05
  final Map<String, dynamic> segmentFilters;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'name': name,
      'description': description,
      'variants': variants.map((v) => v.toJson()).toList(),
      'trafficAllocation': trafficAllocation,
      'targetMetrics': targetMetrics,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'minimumSampleSize': minimumSampleSize,
      'significanceLevel': significanceLevel,
      'segmentFilters': segmentFilters,
      'isActive': isActive,
    };
  }

  static ABTestConfiguration fromJson(Map<String, dynamic> json) {
    return ABTestConfiguration(
      testId: json['testId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      variants: (json['variants'] as List<dynamic>)
          .map((v) => ABTestVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
      trafficAllocation: Map<String, double>.from(json['trafficAllocation'] as Map),
      targetMetrics: List<String>.from(json['targetMetrics'] as List),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      minimumSampleSize: json['minimumSampleSize'] as int,
      significanceLevel: (json['significanceLevel'] as num).toDouble(),
      segmentFilters: Map<String, dynamic>.from(json['segmentFilters'] as Map? ?? {}),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// A variant in an A/B test
class ABTestVariant {
  const ABTestVariant({
    required this.variantId,
    required this.name,
    required this.description,
    required this.parameters,
    this.isControl = false,
  });

  final String variantId;
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final bool isControl;

  Map<String, dynamic> toJson() {
    return {
      'variantId': variantId,
      'name': name,
      'description': description,
      'parameters': parameters,
      'isControl': isControl,
    };
  }

  static ABTestVariant fromJson(Map<String, dynamic> json) {
    return ABTestVariant(
      variantId: json['variantId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      parameters: Map<String, dynamic>.from(json['parameters'] as Map),
      isControl: json['isControl'] as bool? ?? false,
    );
  }
}

/// User assignment to an A/B test
class ABTestAssignment {
  const ABTestAssignment({
    required this.userId,
    required this.testId,
    required this.variantId,
    required this.assignmentDate,
    this.isActive = true,
  });

  final String userId;
  final String testId;
  final String variantId;
  final DateTime assignmentDate;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'testId': testId,
      'variantId': variantId,
      'assignmentDate': assignmentDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  static ABTestAssignment fromJson(Map<String, dynamic> json) {
    return ABTestAssignment(
      userId: json['userId'] as String,
      testId: json['testId'] as String,
      variantId: json['variantId'] as String,
      assignmentDate: DateTime.parse(json['assignmentDate'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

/// Results of an A/B test
class ABTestResults {
  const ABTestResults({
    required this.testId,
    required this.variantResults,
    required this.overallResults,
    required this.statisticalSignificance,
    required this.confidenceLevel,
    required this.generatedAt,
  });

  final String testId;
  final Map<String, ABTestVariantResults> variantResults;
  final ABTestOverallResults overallResults;
  final Map<String, bool> statisticalSignificance; // metric -> significant
  final double confidenceLevel;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'testId': testId,
      'variantResults': variantResults.map((k, v) => MapEntry(k, v.toJson())),
      'overallResults': overallResults.toJson(),
      'statisticalSignificance': statisticalSignificance,
      'confidenceLevel': confidenceLevel,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  static ABTestResults fromJson(Map<String, dynamic> json) {
    return ABTestResults(
      testId: json['testId'] as String,
      variantResults: (json['variantResults'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ABTestVariantResults.fromJson(v as Map<String, dynamic>)),
      ),
      overallResults: ABTestOverallResults.fromJson(json['overallResults'] as Map<String, dynamic>),
      statisticalSignificance: Map<String, bool>.from(json['statisticalSignificance'] as Map),
      confidenceLevel: (json['confidenceLevel'] as num).toDouble(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }
}

/// Results for a specific variant
class ABTestVariantResults {
  const ABTestVariantResults({
    required this.variantId,
    required this.sampleSize,
    required this.metrics,
    required this.conversionRates,
    required this.confidenceIntervals,
  });

  final String variantId;
  final int sampleSize;
  final Map<String, double> metrics;
  final Map<String, double> conversionRates;
  final Map<String, ConfidenceInterval> confidenceIntervals;

  Map<String, dynamic> toJson() {
    return {
      'variantId': variantId,
      'sampleSize': sampleSize,
      'metrics': metrics,
      'conversionRates': conversionRates,
      'confidenceIntervals': confidenceIntervals.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  static ABTestVariantResults fromJson(Map<String, dynamic> json) {
    return ABTestVariantResults(
      variantId: json['variantId'] as String,
      sampleSize: json['sampleSize'] as int,
      metrics: Map<String, double>.from(json['metrics'] as Map),
      conversionRates: Map<String, double>.from(json['conversionRates'] as Map),
      confidenceIntervals: (json['confidenceIntervals'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, ConfidenceInterval.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }
}

/// Overall test results
class ABTestOverallResults {
  const ABTestOverallResults({
    required this.totalParticipants,
    required this.testDuration,
    required this.winningVariant,
    required this.improvementPercentage,
    required this.recommendation,
  });

  final int totalParticipants;
  final Duration testDuration;
  final String? winningVariant;
  final Map<String, double> improvementPercentage; // metric -> improvement %
  final ABTestRecommendation recommendation;

  Map<String, dynamic> toJson() {
    return {
      'totalParticipants': totalParticipants,
      'testDuration': testDuration.inMilliseconds,
      'winningVariant': winningVariant,
      'improvementPercentage': improvementPercentage,
      'recommendation': recommendation.toJson(),
    };
  }

  static ABTestOverallResults fromJson(Map<String, dynamic> json) {
    return ABTestOverallResults(
      totalParticipants: json['totalParticipants'] as int,
      testDuration: Duration(milliseconds: json['testDuration'] as int),
      winningVariant: json['winningVariant'] as String?,
      improvementPercentage: Map<String, double>.from(json['improvementPercentage'] as Map),
      recommendation: ABTestRecommendation.fromJson(json['recommendation'] as Map<String, dynamic>),
    );
  }
}

/// Confidence interval for statistical analysis
class ConfidenceInterval {
  const ConfidenceInterval({
    required this.lowerBound,
    required this.upperBound,
    required this.confidenceLevel,
  });

  final double lowerBound;
  final double upperBound;
  final double confidenceLevel;

  Map<String, dynamic> toJson() {
    return {
      'lowerBound': lowerBound,
      'upperBound': upperBound,
      'confidenceLevel': confidenceLevel,
    };
  }

  static ConfidenceInterval fromJson(Map<String, dynamic> json) {
    return ConfidenceInterval(
      lowerBound: (json['lowerBound'] as num).toDouble(),
      upperBound: (json['upperBound'] as num).toDouble(),
      confidenceLevel: (json['confidenceLevel'] as num).toDouble(),
    );
  }
}

/// Recommendation based on test results
class ABTestRecommendation {
  const ABTestRecommendation({
    required this.action,
    required this.confidence,
    required this.reasoning,
    required this.nextSteps,
  });

  final ABTestAction action;
  final double confidence; // 0-1
  final String reasoning;
  final List<String> nextSteps;

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      'confidence': confidence,
      'reasoning': reasoning,
      'nextSteps': nextSteps,
    };
  }

  static ABTestRecommendation fromJson(Map<String, dynamic> json) {
    return ABTestRecommendation(
      action: ABTestAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => ABTestAction.continueTest,
      ),
      confidence: (json['confidence'] as num).toDouble(),
      reasoning: json['reasoning'] as String,
      nextSteps: List<String>.from(json['nextSteps'] as List),
    );
  }
}

enum ABTestAction {
  implementWinner,
  continueTest,
  stopTest,
  redesignTest,
  rollbackToControl,
}

/// Metric event for A/B testing
class ABTestMetricEvent {
  const ABTestMetricEvent({
    required this.userId,
    required this.testId,
    required this.variantId,
    required this.metricName,
    required this.value,
    required this.timestamp,
    this.metadata = const {},
  });

  final String userId;
  final String testId;
  final String variantId;
  final String metricName;
  final double value;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'testId': testId,
      'variantId': variantId,
      'metricName': metricName,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  static ABTestMetricEvent fromJson(Map<String, dynamic> json) {
    return ABTestMetricEvent(
      userId: json['userId'] as String,
      testId: json['testId'] as String,
      variantId: json['variantId'] as String,
      metricName: json['metricName'] as String,
      value: (json['value'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }
}