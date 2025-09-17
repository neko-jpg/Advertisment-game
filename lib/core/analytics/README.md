# Analytics & A/B Testing System

This module provides comprehensive analytics and A/B testing capabilities for the mobile game, implementing requirements 5.3, 5.4, and 5.6 from the monetization specification.

## Features

### A/B Testing Engine
- **Statistical Significance Testing**: Ensures reliable test results with proper statistical validation
- **Automatic User Assignment**: Consistent hash-based assignment ensures users always see the same variant
- **Multi-Variant Support**: Test multiple variants simultaneously with configurable traffic allocation
- **Auto-Optimization**: Automatically implement winning variants when statistical significance is achieved
- **Comprehensive Metrics**: Track conversion rates, revenue impact, and custom metrics

### Real-Time Analytics Dashboard
- **Live KPI Monitoring**: Track active users, revenue, ARPU, retention rates, and more
- **Intelligent Alerts**: Configurable thresholds with automated actions (notifications, auto-optimization, emergency mode)
- **Competitor Analysis**: Monitor competitor rankings, revenue estimates, and market share
- **Market Position Tracking**: Track app store rankings and competitive positioning
- **AI-Powered Insights**: Automated analysis and recommendations based on performance trends

## Architecture

```
Analytics System
├── A/B Testing Engine
│   ├── Test Configuration & Management
│   ├── User Assignment & Tracking
│   ├── Statistical Analysis
│   └── Auto-Optimization
├── Real-Time Analytics Dashboard
│   ├── KPI Metrics Collection
│   ├── Alert System
│   ├── Competitor Monitoring
│   └── Insights Generation
└── Integration Layer
    ├── Shared Storage
    ├── Event Tracking
    └── UI Components
```

## Usage Examples

### Setting Up A/B Testing

```dart
// Initialize A/B testing engine
final prefs = await SharedPreferences.getInstance();
final storage = LocalABTestStorage(preferences: prefs);
final abEngine = ABTestingEngine(storage: storage);

// Create a test for button color optimization
final buttonTest = ABTestConfiguration(
  testId: 'button_color_test',
  name: 'Purchase Button Color Test',
  description: 'Testing different button colors for conversion',
  variants: [
    ABTestVariant(
      variantId: 'control_blue',
      name: 'Blue Button',
      parameters: {'buttonColor': '#2196F3'},
      isControl: true,
    ),
    ABTestVariant(
      variantId: 'variant_green',
      name: 'Green Button',
      parameters: {'buttonColor': '#4CAF50'},
    ),
  ],
  trafficAllocation: {'control_blue': 0.5, 'variant_green': 0.5},
  targetMetrics: ['purchase_conversion', 'button_clicks'],
  startDate: DateTime.now(),
  endDate: DateTime.now().add(Duration(days: 14)),
  minimumSampleSize: 1000,
  significanceLevel: 0.05,
);

await abEngine.createABTest(buttonTest);

// Assign user to test
final assignment = await abEngine.assignUserToTest('user123', 'button_color_test');
if (assignment != null) {
  // Use variant parameters in UI
  final buttonColor = assignment.variantId == 'control_blue' ? '#2196F3' : '#4CAF50';
}

// Record metric events
await abEngine.recordMetricEvent(ABTestMetricEvent(
  userId: 'user123',
  testId: 'button_color_test',
  variantId: assignment!.variantId,
  metricName: 'button_clicks',
  value: 1.0,
  timestamp: DateTime.now(),
));
```

### Setting Up Real-Time Analytics

```dart
// Initialize analytics dashboard
final analyticsStorage = LocalRealtimeAnalyticsStorage(preferences: prefs);
final dashboard = RealtimeAnalyticsDashboard(
  storage: analyticsStorage,
  updateInterval: Duration(seconds: 30),
);

// Add KPI alerts
await dashboard.addKPIAlert(KPIAlert(
  alertId: 'revenue_alert',
  metricName: 'revenue',
  threshold: 1000.0,
  condition: AlertCondition.below,
  severity: AlertSeverity.high,
  isActive: true,
  description: 'Daily revenue below $1000',
  actions: [
    AlertAction(
      type: AlertActionType.autoOptimize,
      parameters: {'strategy': 'boost_monetization'},
    ),
  ],
));

// Start monitoring
await dashboard.startMonitoring();

// Listen to real-time metrics
dashboard.metricsStream.listen((metrics) {
  print('Current revenue: \$${metrics.revenue}');
  print('Active users: ${metrics.activeUsers}');
});

// Listen to alerts
dashboard.alertStream.listen((alert) {
  print('Alert triggered: ${alert.message}');
});
```

### Using the Dashboard UI

```dart
// Create dashboard widget
Widget buildAnalyticsDashboard() {
  return AnalyticsDashboardWidget(
    dashboard: dashboard,
    refreshInterval: Duration(seconds: 30),
  );
}
```

## Key Components

### Models
- **`ab_testing_models.dart`**: A/B test configurations, variants, results, and metrics
- **`realtime_analytics_models.dart`**: KPI metrics, alerts, competitor data, and dashboard configs
- **`behavior_models.dart`**: User behavior tracking and analysis models

### Engines
- **`ab_testing_engine.dart`**: Core A/B testing logic with statistical analysis
- **`realtime_analytics_dashboard.dart`**: Real-time monitoring and alerting system

### Storage
- **`LocalABTestStorage`**: Local storage implementation for A/B test data
- **`LocalRealtimeAnalyticsStorage`**: Local storage for analytics data

### UI Components
- **`analytics_dashboard_widget.dart`**: Complete dashboard UI with metrics, alerts, and insights

## Statistical Methods

### A/B Testing Statistics
- **Sample Size Calculation**: Ensures adequate sample sizes for reliable results
- **T-Test Analysis**: Compares means between variants with confidence intervals
- **Statistical Significance**: Uses configurable significance levels (typically 0.05)
- **Effect Size Calculation**: Measures practical significance of differences

### Real-Time Analytics
- **Moving Averages**: Smooth out short-term fluctuations in metrics
- **Anomaly Detection**: Identify unusual patterns in user behavior
- **Trend Analysis**: Track performance changes over time
- **Comparative Analysis**: Benchmark against historical performance

## Integration with Game Systems

### Monetization Integration
```dart
// Use A/B test results to optimize ad placement
final adPlacementVariant = await abEngine.getUserVariant(userId, 'ad_placement_test');
if (adPlacementVariant == 'variant_reduced_frequency') {
  // Show ads less frequently but with higher rewards
  adManager.setFrequency(5); // Every 5 games instead of 3
  adManager.setRewardMultiplier(1.2);
}
```

### User Experience Integration
```dart
// Monitor user satisfaction and adjust difficulty
dashboard.metricsStream.listen((metrics) {
  if (metrics.retentionRate < 0.6) {
    // Low retention - make game easier
    difficultyEngine.adjustGlobalDifficulty(-0.1);
  }
});
```

## Performance Considerations

- **Efficient Storage**: Uses local storage with automatic cleanup of old data
- **Batch Processing**: Groups metric events for efficient processing
- **Memory Management**: Streams and subscriptions are properly disposed
- **Background Processing**: Analytics calculations don't block UI thread

## Testing

The system includes comprehensive tests covering:
- A/B test configuration and validation
- User assignment consistency and distribution
- Statistical analysis accuracy
- Real-time metrics collection
- Alert triggering and resolution
- Dashboard functionality

Run tests with:
```bash
flutter test test/core/analytics/
```

## Future Enhancements

- **Advanced ML Models**: Implement more sophisticated churn prediction
- **Real-Time Personalization**: Dynamic content based on user behavior
- **Advanced Segmentation**: More granular user segmentation
- **External Integrations**: Connect to external analytics platforms
- **Predictive Analytics**: Forecast future performance trends

## Requirements Fulfilled

- **5.3**: A/B testing framework with statistical significance validation ✅
- **5.4**: Real-time KPI monitoring and automated alerting ✅  
- **5.6**: Competitor analysis and market position tracking ✅