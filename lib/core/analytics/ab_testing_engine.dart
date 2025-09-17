import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ab_testing_models.dart';
import 'models/behavior_models.dart';

/// A/B testing engine with statistical significance validation
class ABTestingEngine {
  ABTestingEngine({
    required this.storage,
    this.random,
  }) : _random = random ?? Random();

  final ABTestStorage storage;
  final Random? random;
  final Random _random;

  static const String _assignmentsKey = 'ab_test_assignments';
  static const String _metricsKey = 'ab_test_metrics';

  /// Create and start a new A/B test
  Future<void> createABTest(ABTestConfiguration config) async {
    // Validate configuration
    _validateTestConfiguration(config);
    
    // Store test configuration
    await storage.saveTestConfiguration(config);
    
    print('A/B Test created: ${config.name} (${config.testId})');
  }

  /// Assign a user to a test variant
  Future<ABTestAssignment?> assignUserToTest(
    String userId, 
    String testId,
  ) async {
    final config = await storage.getTestConfiguration(testId);
    if (config == null || !config.isActive) {
      return null;
    }

    // Check if user is already assigned
    final existingAssignment = await storage.getUserAssignment(userId, testId);
    if (existingAssignment != null) {
      return existingAssignment;
    }

    // Check if user meets segment filters
    if (!await _userMatchesSegmentFilters(userId, config.segmentFilters)) {
      return null;
    }

    // Assign user to variant based on traffic allocation
    final variantId = _selectVariantForUser(userId, config);
    if (variantId == null) {
      return null;
    }

    final assignment = ABTestAssignment(
      userId: userId,
      testId: testId,
      variantId: variantId,
      assignmentDate: DateTime.now(),
    );

    await storage.saveUserAssignment(assignment);
    return assignment;
  }

  /// Get user's variant for a specific test
  Future<String?> getUserVariant(String userId, String testId) async {
    final assignment = await storage.getUserAssignment(userId, testId);
    return assignment?.variantId;
  }

  /// Record a metric event for A/B testing
  Future<void> recordMetricEvent(ABTestMetricEvent event) async {
    await storage.saveMetricEvent(event);
    
    // Check if we should auto-optimize based on new data
    await _checkAutoOptimization(event.testId);
  }

  /// Get test results with statistical analysis
  Future<ABTestResults?> getTestResults(String testId) async {
    final config = await storage.getTestConfiguration(testId);
    if (config == null) {
      return null;
    }

    final assignments = await storage.getTestAssignments(testId);
    final metricEvents = await storage.getTestMetricEvents(testId);

    if (assignments.isEmpty || metricEvents.isEmpty) {
      return null;
    }

    // Calculate variant results
    final variantResults = <String, ABTestVariantResults>{};
    for (final variant in config.variants) {
      final variantAssignments = assignments
          .where((a) => a.variantId == variant.variantId)
          .toList();
      
      final variantEvents = metricEvents
          .where((e) => e.variantId == variant.variantId)
          .toList();

      variantResults[variant.variantId] = _calculateVariantResults(
        variant.variantId,
        variantAssignments,
        variantEvents,
        config.targetMetrics,
      );
    }

    // Calculate statistical significance
    final significance = _calculateStatisticalSignificance(
      variantResults,
      config.targetMetrics,
      config.significanceLevel,
    );

    // Generate overall results and recommendations
    final overallResults = _generateOverallResults(
      variantResults,
      config,
      significance,
    );

    return ABTestResults(
      testId: testId,
      variantResults: variantResults,
      overallResults: overallResults,
      statisticalSignificance: significance,
      confidenceLevel: 1.0 - config.significanceLevel,
      generatedAt: DateTime.now(),
    );
  }

  /// Check if test results are statistically significant
  bool isStatisticallySignificant(ABTestResults results) {
    return results.statisticalSignificance.values.any((significant) => significant);
  }

  /// Auto-optimize based on test results
  Future<void> autoOptimizeBasedOnResults(String testId) async {
    final results = await getTestResults(testId);
    if (results == null) {
      return;
    }

    final config = await storage.getTestConfiguration(testId);
    if (config == null) {
      return;
    }

    // Check if we have enough data and statistical significance
    if (!_hasEnoughDataForOptimization(results, config) ||
        !isStatisticallySignificant(results)) {
      return;
    }

    // Implement winning variant if there's a clear winner
    if (results.overallResults.winningVariant != null &&
        results.overallResults.recommendation.action == ABTestAction.implementWinner) {
      
      await _implementWinningVariant(testId, results.overallResults.winningVariant!);
      print('Auto-optimized test $testId: Implemented winning variant ${results.overallResults.winningVariant}');
    }
  }

  /// Get active tests for a user
  Future<List<ABTestAssignment>> getActiveTestsForUser(String userId) async {
    return await storage.getUserActiveAssignments(userId);
  }

  /// Stop a test
  Future<void> stopTest(String testId) async {
    final config = await storage.getTestConfiguration(testId);
    if (config == null) {
      return;
    }

    final updatedConfig = ABTestConfiguration(
      testId: config.testId,
      name: config.name,
      description: config.description,
      variants: config.variants,
      trafficAllocation: config.trafficAllocation,
      targetMetrics: config.targetMetrics,
      startDate: config.startDate,
      endDate: config.endDate,
      minimumSampleSize: config.minimumSampleSize,
      significanceLevel: config.significanceLevel,
      segmentFilters: config.segmentFilters,
      isActive: false,
    );

    await storage.saveTestConfiguration(updatedConfig);
  }

  // Private methods

  void _validateTestConfiguration(ABTestConfiguration config) {
    if (config.variants.isEmpty) {
      throw ArgumentError('Test must have at least one variant');
    }

    if (config.variants.length < 2) {
      throw ArgumentError('Test must have at least two variants');
    }

    final totalAllocation = config.trafficAllocation.values.fold(0.0, (a, b) => a + b);
    if ((totalAllocation - 1.0).abs() > 0.001) {
      throw ArgumentError('Traffic allocation must sum to 1.0');
    }

    if (config.targetMetrics.isEmpty) {
      throw ArgumentError('Test must have at least one target metric');
    }

    if (config.minimumSampleSize < 100) {
      throw ArgumentError('Minimum sample size should be at least 100');
    }
  }

  Future<bool> _userMatchesSegmentFilters(
    String userId, 
    Map<String, dynamic> filters,
  ) async {
    if (filters.isEmpty) {
      return true;
    }

    // For now, return true - in a real implementation, this would check
    // user properties against the segment filters
    return true;
  }

  String? _selectVariantForUser(String userId, ABTestConfiguration config) {
    // Use consistent hashing to ensure same user always gets same variant
    final hash = (userId.hashCode.abs() % 1000000) / 1000000.0; // Normalize to 0-1
    
    double cumulativeAllocation = 0.0;
    for (final entry in config.trafficAllocation.entries) {
      cumulativeAllocation += entry.value;
      if (hash < cumulativeAllocation) {
        return entry.key;
      }
    }

    // Fallback to first variant
    return config.variants.first.variantId;
  }

  ABTestVariantResults _calculateVariantResults(
    String variantId,
    List<ABTestAssignment> assignments,
    List<ABTestMetricEvent> events,
    List<String> targetMetrics,
  ) {
    final sampleSize = assignments.length;
    final metrics = <String, double>{};
    final conversionRates = <String, double>{};
    final confidenceIntervals = <String, ConfidenceInterval>{};

    for (final metric in targetMetrics) {
      final metricEvents = events.where((e) => e.metricName == metric).toList();
      
      if (metricEvents.isNotEmpty) {
        // Calculate average metric value
        final totalValue = metricEvents.fold(0.0, (sum, e) => sum + e.value);
        metrics[metric] = totalValue / metricEvents.length;
        
        // Calculate conversion rate (percentage of users who triggered this metric)
        final uniqueUsers = metricEvents.map((e) => e.userId).toSet().length;
        conversionRates[metric] = sampleSize > 0 ? uniqueUsers / sampleSize : 0.0;
        
        // Calculate confidence interval (simplified)
        final stdDev = _calculateStandardDeviation(metricEvents.map((e) => e.value).toList());
        final marginOfError = 1.96 * (stdDev / sqrt(metricEvents.length)); // 95% CI
        confidenceIntervals[metric] = ConfidenceInterval(
          lowerBound: metrics[metric]! - marginOfError,
          upperBound: metrics[metric]! + marginOfError,
          confidenceLevel: 0.95,
        );
      } else {
        metrics[metric] = 0.0;
        conversionRates[metric] = 0.0;
        confidenceIntervals[metric] = ConfidenceInterval(
          lowerBound: 0.0,
          upperBound: 0.0,
          confidenceLevel: 0.95,
        );
      }
    }

    return ABTestVariantResults(
      variantId: variantId,
      sampleSize: sampleSize,
      metrics: metrics,
      conversionRates: conversionRates,
      confidenceIntervals: confidenceIntervals,
    );
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.fold(0.0, (a, b) => a + b) / values.length;
    final variance = values.fold(0.0, (sum, value) => sum + pow(value - mean, 2)) / values.length;
    return sqrt(variance);
  }

  Map<String, bool> _calculateStatisticalSignificance(
    Map<String, ABTestVariantResults> variantResults,
    List<String> targetMetrics,
    double significanceLevel,
  ) {
    final significance = <String, bool>{};
    
    if (variantResults.length < 2) {
      for (final metric in targetMetrics) {
        significance[metric] = false;
      }
      return significance;
    }

    final variants = variantResults.values.toList();
    final controlVariant = variants.first;
    
    for (final metric in targetMetrics) {
      bool isSignificant = false;
      
      for (int i = 1; i < variants.length; i++) {
        final testVariant = variants[i];
        
        // Simplified t-test calculation
        final controlMean = controlVariant.metrics[metric] ?? 0.0;
        final testMean = testVariant.metrics[metric] ?? 0.0;
        
        if (controlVariant.sampleSize > 30 && testVariant.sampleSize > 30) {
          // Use normal approximation for large samples
          final pooledStdError = sqrt(
            (pow(controlVariant.confidenceIntervals[metric]?.upperBound ?? 0.0 - controlMean, 2) +
             pow(testVariant.confidenceIntervals[metric]?.upperBound ?? 0.0 - testMean, 2)) / 2
          );
          
          if (pooledStdError > 0) {
            final tStat = (testMean - controlMean).abs() / pooledStdError;
            // Simplified: consider significant if t-stat > 1.96 (95% confidence)
            if (tStat > 1.96) {
              isSignificant = true;
              break;
            }
          }
        }
      }
      
      significance[metric] = isSignificant;
    }
    
    return significance;
  }

  ABTestOverallResults _generateOverallResults(
    Map<String, ABTestVariantResults> variantResults,
    ABTestConfiguration config,
    Map<String, bool> significance,
  ) {
    final totalParticipants = variantResults.values
        .fold(0, (sum, result) => sum + result.sampleSize);
    
    final testDuration = DateTime.now().difference(config.startDate);
    
    // Find winning variant based on primary metric (first target metric)
    String? winningVariant;
    final improvementPercentage = <String, double>{};
    
    if (config.targetMetrics.isNotEmpty && variantResults.length >= 2) {
      final primaryMetric = config.targetMetrics.first;
      final variants = variantResults.entries.toList();
      
      // Assume first variant is control
      final controlResult = variants.first.value;
      final controlValue = controlResult.metrics[primaryMetric] ?? 0.0;
      
      double bestImprovement = 0.0;
      String? bestVariant;
      
      for (int i = 1; i < variants.length; i++) {
        final variant = variants[i];
        final testValue = variant.value.metrics[primaryMetric] ?? 0.0;
        
        if (controlValue > 0) {
          final improvement = ((testValue - controlValue) / controlValue) * 100;
          improvementPercentage[variant.key] = improvement;
          
          if (improvement > bestImprovement && significance[primaryMetric] == true) {
            bestImprovement = improvement;
            bestVariant = variant.key;
          }
        }
      }
      
      winningVariant = bestVariant;
    }
    
    // Generate recommendation
    final recommendation = _generateRecommendation(
      variantResults,
      significance,
      config,
      winningVariant,
      totalParticipants,
    );
    
    return ABTestOverallResults(
      totalParticipants: totalParticipants,
      testDuration: testDuration,
      winningVariant: winningVariant,
      improvementPercentage: improvementPercentage,
      recommendation: recommendation,
    );
  }

  ABTestRecommendation _generateRecommendation(
    Map<String, ABTestVariantResults> variantResults,
    Map<String, bool> significance,
    ABTestConfiguration config,
    String? winningVariant,
    int totalParticipants,
  ) {
    final hasSignificantResults = significance.values.any((sig) => sig);
    final hasEnoughSamples = totalParticipants >= config.minimumSampleSize;
    
    if (!hasEnoughSamples) {
      return ABTestRecommendation(
        action: ABTestAction.continueTest,
        confidence: 0.3,
        reasoning: 'Not enough samples collected yet. Need at least ${config.minimumSampleSize} participants.',
        nextSteps: ['Continue collecting data', 'Monitor sample size daily'],
      );
    }
    
    if (!hasSignificantResults) {
      return ABTestRecommendation(
        action: ABTestAction.continueTest,
        confidence: 0.5,
        reasoning: 'No statistically significant differences found yet.',
        nextSteps: ['Continue test for more data', 'Consider extending test duration'],
      );
    }
    
    if (winningVariant != null) {
      return ABTestRecommendation(
        action: ABTestAction.implementWinner,
        confidence: 0.9,
        reasoning: 'Variant $winningVariant shows statistically significant improvement.',
        nextSteps: ['Implement winning variant', 'Monitor post-implementation metrics'],
      );
    }
    
    return ABTestRecommendation(
      action: ABTestAction.stopTest,
      confidence: 0.7,
      reasoning: 'Test has run long enough without clear winner.',
      nextSteps: ['Analyze learnings', 'Design follow-up tests'],
    );
  }

  Future<void> _checkAutoOptimization(String testId) async {
    final config = await storage.getTestConfiguration(testId);
    if (config == null || !config.isActive) {
      return;
    }

    // Check if test has been running for minimum duration (e.g., 7 days)
    final testDuration = DateTime.now().difference(config.startDate);
    if (testDuration.inDays < 7) {
      return;
    }

    await autoOptimizeBasedOnResults(testId);
  }

  bool _hasEnoughDataForOptimization(ABTestResults results, ABTestConfiguration config) {
    return results.overallResults.totalParticipants >= config.minimumSampleSize &&
           results.overallResults.testDuration.inDays >= 7;
  }

  Future<void> _implementWinningVariant(String testId, String winningVariantId) async {
    // In a real implementation, this would update the app configuration
    // to use the winning variant's parameters for all users
    print('Implementing winning variant $winningVariantId for test $testId');
    
    // Stop the test
    await stopTest(testId);
  }
}

/// Storage interface for A/B testing data
abstract class ABTestStorage {
  Future<void> saveTestConfiguration(ABTestConfiguration config);
  Future<ABTestConfiguration?> getTestConfiguration(String testId);
  Future<void> saveUserAssignment(ABTestAssignment assignment);
  Future<ABTestAssignment?> getUserAssignment(String userId, String testId);
  Future<List<ABTestAssignment>> getTestAssignments(String testId);
  Future<List<ABTestAssignment>> getUserActiveAssignments(String userId);
  Future<void> saveMetricEvent(ABTestMetricEvent event);
  Future<List<ABTestMetricEvent>> getTestMetricEvents(String testId);
}

/// Local storage implementation for A/B testing
class LocalABTestStorage implements ABTestStorage {
  LocalABTestStorage({required this.preferences});
  
  final SharedPreferences preferences;
  
  static const String _configPrefix = 'ab_test_config_';
  static const String _assignmentPrefix = 'ab_test_assignment_';
  static const String _metricsPrefix = 'ab_test_metrics_';

  @override
  Future<void> saveTestConfiguration(ABTestConfiguration config) async {
    final key = '$_configPrefix${config.testId}';
    await preferences.setString(key, jsonEncode(config.toJson()));
  }

  @override
  Future<ABTestConfiguration?> getTestConfiguration(String testId) async {
    final key = '$_configPrefix$testId';
    final jsonString = preferences.getString(key);
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ABTestConfiguration.fromJson(json);
    } catch (e) {
      print('Error loading test configuration: $e');
      return null;
    }
  }

  @override
  Future<void> saveUserAssignment(ABTestAssignment assignment) async {
    final key = '$_assignmentPrefix${assignment.userId}_${assignment.testId}';
    await preferences.setString(key, jsonEncode(assignment.toJson()));
  }

  @override
  Future<ABTestAssignment?> getUserAssignment(String userId, String testId) async {
    final key = '$_assignmentPrefix${userId}_$testId';
    final jsonString = preferences.getString(key);
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ABTestAssignment.fromJson(json);
    } catch (e) {
      print('Error loading user assignment: $e');
      return null;
    }
  }

  @override
  Future<List<ABTestAssignment>> getTestAssignments(String testId) async {
    final assignments = <ABTestAssignment>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith(_assignmentPrefix) && key.endsWith('_$testId'));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          assignments.add(ABTestAssignment.fromJson(json));
        } catch (e) {
          print('Error loading assignment: $e');
        }
      }
    }
    
    return assignments;
  }

  @override
  Future<List<ABTestAssignment>> getUserActiveAssignments(String userId) async {
    final assignments = <ABTestAssignment>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith('$_assignmentPrefix$userId'));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final assignment = ABTestAssignment.fromJson(json);
          if (assignment.isActive) {
            assignments.add(assignment);
          }
        } catch (e) {
          print('Error loading assignment: $e');
        }
      }
    }
    
    return assignments;
  }

  @override
  Future<void> saveMetricEvent(ABTestMetricEvent event) async {
    final key = '$_metricsPrefix${event.testId}_${DateTime.now().millisecondsSinceEpoch}';
    await preferences.setString(key, jsonEncode(event.toJson()));
  }

  @override
  Future<List<ABTestMetricEvent>> getTestMetricEvents(String testId) async {
    final events = <ABTestMetricEvent>[];
    final keys = preferences.getKeys()
        .where((key) => key.startsWith('$_metricsPrefix$testId'));
    
    for (final key in keys) {
      final jsonString = preferences.getString(key);
      if (jsonString != null) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          events.add(ABTestMetricEvent.fromJson(json));
        } catch (e) {
          print('Error loading metric event: $e');
        }
      }
    }
    
    return events;
  }
}