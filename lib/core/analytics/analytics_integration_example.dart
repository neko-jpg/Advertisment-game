import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ab_testing_engine.dart';
import 'realtime_analytics_dashboard.dart';
import 'models/ab_testing_models.dart';
import 'models/realtime_analytics_models.dart';
import 'ui/analytics_dashboard_widget.dart';

/// Example integration of A/B testing and real-time analytics
class AnalyticsIntegrationExample {
  static Future<void> demonstrateAnalyticsSystem() async {
    print('=== Analytics System Integration Demo ===');
    
    // Initialize storage
    final prefs = await SharedPreferences.getInstance();
    final abTestStorage = LocalABTestStorage(preferences: prefs);
    final analyticsStorage = LocalRealtimeAnalyticsStorage(preferences: prefs);
    
    // Initialize engines
    final abTestEngine = ABTestingEngine(storage: abTestStorage);
    final analyticsDashboard = RealtimeAnalyticsDashboard(
      storage: analyticsStorage,
      updateInterval: Duration(seconds: 10),
    );
    
    try {
      // Demo A/B Testing
      await _demonstrateABTesting(abTestEngine);
      
      // Demo Real-time Analytics
      await _demonstrateRealtimeAnalytics(analyticsDashboard);
      
      // Demo Integration
      await _demonstrateIntegration(abTestEngine, analyticsDashboard);
      
    } finally {
      analyticsDashboard.dispose();
    }
  }
  
  static Future<void> _demonstrateABTesting(ABTestingEngine engine) async {
    print('\n--- A/B Testing Demo ---');
    
    // Create a test for button color optimization
    final buttonColorTest = ABTestConfiguration(
      testId: 'button_color_test_001',
      name: 'Purchase Button Color Test',
      description: 'Testing different button colors for purchase conversion',
      variants: [
        ABTestVariant(
          variantId: 'control_blue',
          name: 'Blue Button (Control)',
          description: 'Original blue purchase button',
          parameters: {'buttonColor': '#2196F3', 'textColor': '#FFFFFF'},
          isControl: true,
        ),
        ABTestVariant(
          variantId: 'variant_green',
          name: 'Green Button',
          description: 'Green purchase button variant',
          parameters: {'buttonColor': '#4CAF50', 'textColor': '#FFFFFF'},
        ),
        ABTestVariant(
          variantId: 'variant_orange',
          name: 'Orange Button',
          description: 'Orange purchase button variant',
          parameters: {'buttonColor': '#FF9800', 'textColor': '#FFFFFF'},
        ),
      ],
      trafficAllocation: {
        'control_blue': 0.4,
        'variant_green': 0.3,
        'variant_orange': 0.3,
      },
      targetMetrics: ['purchase_conversion', 'button_clicks', 'revenue_per_user'],
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 14)),
      minimumSampleSize: 1000,
      significanceLevel: 0.05,
    );
    
    await engine.createABTest(buttonColorTest);
    print('✓ Created A/B test: ${buttonColorTest.name}');
    
    // Simulate user assignments and metric collection
    await _simulateABTestData(engine, buttonColorTest.testId);
    
    // Analyze results
    final results = await engine.getTestResults(buttonColorTest.testId);
    if (results != null) {
      print('✓ Test Results Generated:');
      print('  - Total Participants: ${results.overallResults.totalParticipants}');
      print('  - Winning Variant: ${results.overallResults.winningVariant ?? "No clear winner"}');
      print('  - Recommendation: ${results.overallResults.recommendation.action.name}');
      print('  - Statistical Significance: ${engine.isStatisticallySignificant(results)}');
    }
  }
  
  static Future<void> _demonstrateRealtimeAnalytics(RealtimeAnalyticsDashboard dashboard) async {
    print('\n--- Real-time Analytics Demo ---');
    
    // Set up KPI alerts
    final revenueAlert = KPIAlert(
      alertId: 'revenue_drop_alert',
      metricName: 'revenue',
      threshold: 800.0,
      condition: AlertCondition.below,
      severity: AlertSeverity.high,
      isActive: true,
      description: 'Daily revenue dropped below $800',
      actions: [
        AlertAction(
          type: AlertActionType.autoOptimize,
          parameters: {'strategy': 'boost_monetization'},
        ),
        AlertAction(
          type: AlertActionType.notification,
          parameters: {'message': 'Revenue alert triggered'},
        ),
      ],
    );
    
    final crashAlert = KPIAlert(
      alertId: 'crash_rate_alert',
      metricName: 'crashRate',
      threshold: 0.03,
      condition: AlertCondition.above,
      severity: AlertSeverity.critical,
      isActive: true,
      description: 'Crash rate above 3%',
      actions: [
        AlertAction(
          type: AlertActionType.emergencyMode,
          parameters: {'action': 'stability_mode'},
        ),
      ],
    );
    
    await dashboard.addKPIAlert(revenueAlert);
    await dashboard.addKPIAlert(crashAlert);
    print('✓ Added KPI alerts for revenue and crash rate');
    
    // Start monitoring
    await dashboard.startMonitoring();
    print('✓ Started real-time monitoring');
    
    // Simulate some competitor data
    final competitor = CompetitorAnalysis(
      competitorId: 'subway_surfers',
      name: 'Subway Surfers',
      ranking: 3,
      estimatedRevenue: 150000.0,
      downloads: 5000000,
      rating: 4.4,
      lastUpdated: DateTime.now(),
      keyFeatures: ['Endless runner', 'Character collection', 'Power-ups'],
      marketShare: 0.35,
    );
    
    await dashboard.updateCompetitorData(competitor);
    print('✓ Updated competitor analysis data');
    
    // Wait for some metrics collection
    await Future.delayed(Duration(seconds: 2));
    
    // Get current metrics
    final metrics = await dashboard.getCurrentMetrics();
    print('✓ Current Metrics:');
    print('  - Active Users: ${metrics.activeUsers}');
    print('  - Revenue: \$${metrics.revenue.toStringAsFixed(2)}');
    print('  - ARPU: \$${metrics.arpu.toStringAsFixed(3)}');
    print('  - Retention Rate: ${(metrics.retentionRate * 100).toStringAsFixed(1)}%');
    
    // Generate insights
    final insights = await dashboard.generateInsights();
    if (insights.isNotEmpty) {
      print('✓ AI Insights:');
      for (final insight in insights) {
        print('  - $insight');
      }
    }
    
    dashboard.stopMonitoring();
  }
  
  static Future<void> _demonstrateIntegration(
    ABTestingEngine abEngine,
    RealtimeAnalyticsDashboard dashboard,
  ) async {
    print('\n--- Integration Demo ---');
    
    // Create an A/B test for monetization optimization
    final monetizationTest = ABTestConfiguration(
      testId: 'monetization_optimization_001',
      name: 'Ad Frequency Optimization',
      description: 'Testing different ad frequencies for optimal revenue',
      variants: [
        ABTestVariant(
          variantId: 'control_normal',
          name: 'Normal Ad Frequency',
          description: 'Current ad frequency (every 3 games)',
          parameters: {'adFrequency': 3, 'rewardMultiplier': 1.0},
          isControl: true,
        ),
        ABTestVariant(
          variantId: 'variant_reduced',
          name: 'Reduced Ad Frequency',
          description: 'Reduced ad frequency (every 5 games)',
          parameters: {'adFrequency': 5, 'rewardMultiplier': 1.2},
        ),
      ],
      trafficAllocation: {'control_normal': 0.5, 'variant_reduced': 0.5},
      targetMetrics: ['ad_revenue', 'user_satisfaction', 'session_length'],
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 10)),
      minimumSampleSize: 500,
      significanceLevel: 0.05,
    );
    
    await abEngine.createABTest(monetizationTest);
    print('✓ Created monetization A/B test');
    
    // Set up analytics alert for the A/B test
    final testAlert = KPIAlert(
      alertId: 'ab_test_revenue_alert',
      metricName: 'adRevenue',
      threshold: 500.0,
      condition: AlertCondition.below,
      severity: AlertSeverity.medium,
      isActive: true,
      description: 'Ad revenue impact from A/B test',
      actions: [
        AlertAction(
          type: AlertActionType.log,
          parameters: {'test_id': monetizationTest.testId},
        ),
      ],
    );
    
    await dashboard.addKPIAlert(testAlert);
    print('✓ Added analytics alert for A/B test monitoring');
    
    // Simulate integrated workflow
    print('✓ Integration workflow:');
    print('  1. A/B test running with real-time monitoring');
    print('  2. Analytics dashboard tracking test impact on KPIs');
    print('  3. Automated alerts for significant changes');
    print('  4. Auto-optimization based on statistical significance');
    
    // Demonstrate how A/B test results feed into analytics
    await _simulateABTestData(abEngine, monetizationTest.testId);
    
    final testResults = await abEngine.getTestResults(monetizationTest.testId);
    if (testResults != null && abEngine.isStatisticallySignificant(testResults)) {
      print('✓ A/B test shows significant results - triggering auto-optimization');
      await abEngine.autoOptimizeBasedOnResults(monetizationTest.testId);
    }
    
    print('✓ Integration demo completed successfully');
  }
  
  static Future<void> _simulateABTestData(ABTestingEngine engine, String testId) async {
    print('  Simulating user data collection...');
    
    // Simulate 200 users
    for (int i = 0; i < 200; i++) {
      final userId = 'user_$i';
      final assignment = await engine.assignUserToTest(userId, testId);
      
      if (assignment != null) {
        // Simulate different conversion rates for variants
        double conversionRate;
        double clickRate;
        
        switch (assignment.variantId) {
          case 'control_blue':
          case 'control_normal':
            conversionRate = 0.08; // 8% conversion
            clickRate = 0.25; // 25% click rate
            break;
          case 'variant_green':
            conversionRate = 0.12; // 12% conversion (better)
            clickRate = 0.35; // 35% click rate
            break;
          case 'variant_orange':
            conversionRate = 0.06; // 6% conversion (worse)
            clickRate = 0.20; // 20% click rate
            break;
          case 'variant_reduced':
            conversionRate = 0.10; // 10% conversion
            clickRate = 0.30; // 30% click rate
            break;
          default:
            conversionRate = 0.08;
            clickRate = 0.25;
        }
        
        // Simulate metric events based on probability
        if (i / 200.0 < clickRate) {
          await engine.recordMetricEvent(ABTestMetricEvent(
            userId: userId,
            testId: testId,
            variantId: assignment.variantId,
            metricName: 'button_clicks',
            value: 1.0,
            timestamp: DateTime.now(),
          ));
        }
        
        if (i / 200.0 < conversionRate) {
          await engine.recordMetricEvent(ABTestMetricEvent(
            userId: userId,
            testId: testId,
            variantId: assignment.variantId,
            metricName: 'purchase_conversion',
            value: 1.0,
            timestamp: DateTime.now(),
          ));
          
          // Revenue event
          final revenue = 2.99 + (i % 3) * 1.0; // Varying revenue
          await engine.recordMetricEvent(ABTestMetricEvent(
            userId: userId,
            testId: testId,
            variantId: assignment.variantId,
            metricName: 'revenue_per_user',
            value: revenue,
            timestamp: DateTime.now(),
          ));
        }
      }
    }
    
    print('  ✓ Simulated data for 200 users');
  }
  
  /// Create a Flutter widget that demonstrates the analytics dashboard
  static Widget createDashboardDemo() {
    return FutureBuilder<RealtimeAnalyticsDashboard>(
      future: _initializeDashboardForDemo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }
        
        return AnalyticsDashboardWidget(
          dashboard: snapshot.data!,
        );
      },
    );
  }
  
  static Future<RealtimeAnalyticsDashboard> _initializeDashboardForDemo() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalRealtimeAnalyticsStorage(preferences: prefs);
    
    final dashboard = RealtimeAnalyticsDashboard(
      storage: storage,
      updateInterval: Duration(seconds: 30),
    );
    
    // Add some demo alerts
    await dashboard.addKPIAlert(KPIAlert(
      alertId: 'demo_revenue_alert',
      metricName: 'revenue',
      threshold: 1000.0,
      condition: AlertCondition.below,
      severity: AlertSeverity.medium,
      isActive: true,
      description: 'Revenue below $1000',
    ));
    
    return dashboard;
  }
}

/// Example usage in a Flutter app
class AnalyticsExampleApp extends StatelessWidget {
  const AnalyticsExampleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Analytics Dashboard Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AnalyticsIntegrationExample.createDashboardDemo(),
    );
  }
}