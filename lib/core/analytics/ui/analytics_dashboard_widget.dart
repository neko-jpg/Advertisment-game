import 'package:flutter/material.dart';
import 'dart:async';
import '../realtime_analytics_dashboard.dart';
import '../models/realtime_analytics_models.dart';

/// Analytics dashboard UI widget
class AnalyticsDashboardWidget extends StatefulWidget {
  const AnalyticsDashboardWidget({
    Key? key,
    required this.dashboard,
    this.refreshInterval = const Duration(seconds: 30),
  }) : super(key: key);

  final RealtimeAnalyticsDashboard dashboard;
  final Duration refreshInterval;

  @override
  State<AnalyticsDashboardWidget> createState() => _AnalyticsDashboardWidgetState();
}

class _AnalyticsDashboardWidgetState extends State<AnalyticsDashboardWidget> {
  StreamSubscription<RealtimeKPIMetrics>? _metricsSubscription;
  StreamSubscription<TriggeredAlert>? _alertSubscription;
  
  RealtimeKPIMetrics? _currentMetrics;
  List<TriggeredAlert> _recentAlerts = [];
  List<String> _insights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _metricsSubscription?.cancel();
    _alertSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeDashboard() async {
    try {
      // Start monitoring
      await widget.dashboard.startMonitoring();
      
      // Subscribe to streams
      _metricsSubscription = widget.dashboard.metricsStream.listen((metrics) {
        if (mounted) {
          setState(() {
            _currentMetrics = metrics;
            _isLoading = false;
          });
          _updateInsights();
        }
      });

      _alertSubscription = widget.dashboard.alertStream.listen((alert) {
        if (mounted) {
          setState(() {
            _recentAlerts.insert(0, alert);
            if (_recentAlerts.length > 5) {
              _recentAlerts = _recentAlerts.take(5).toList();
            }
          });
        }
      });

      // Load initial data
      final metrics = await widget.dashboard.getCurrentMetrics();
      final alerts = await widget.dashboard.getTriggeredAlerts(
        since: DateTime.now().subtract(Duration(hours: 24)),
        unresolvedOnly: true,
      );

      if (mounted) {
        setState(() {
          _currentMetrics = metrics;
          _recentAlerts = alerts.take(5).toList();
          _isLoading = false;
        });
        _updateInsights();
      }
    } catch (e) {
      print('Error initializing dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateInsights() async {
    try {
      final insights = await widget.dashboard.generateInsights();
      if (mounted) {
        setState(() {
          _insights = insights;
        });
      }
    } catch (e) {
      print('Error updating insights: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPIMetricsSection(),
              const SizedBox(height: 24),
              _buildAlertsSection(),
              const SizedBox(height: 24),
              _buildInsightsSection(),
              const SizedBox(height: 24),
              _buildMarketPositionSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKPIMetricsSection() {
    if (_currentMetrics == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No metrics available'),
        ),
      );
    }

    final metrics = _currentMetrics!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Key Performance Indicators',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMetricCard(
                  'Active Users',
                  metrics.activeUsers.toString(),
                  Icons.people,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Revenue',
                  '\$${metrics.revenue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'ARPU',
                  '\$${metrics.arpu.toStringAsFixed(3)}',
                  Icons.person_outline,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Retention Rate',
                  '${(metrics.retentionRate * 100).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.purple,
                ),
                _buildMetricCard(
                  'Session Length',
                  '${metrics.sessionLength.inMinutes}m',
                  Icons.timer,
                  Colors.teal,
                ),
                _buildMetricCard(
                  'App Rating',
                  metrics.appStoreRating.toStringAsFixed(1),
                  Icons.star,
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600]),
                const SizedBox(width: 8),
                Text(
                  'Recent Alerts',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentAlerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    const Text('No active alerts'),
                  ],
                ),
              )
            else
              ...(_recentAlerts.map((alert) => _buildAlertCard(alert)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(TriggeredAlert alert) {
    Color alertColor;
    IconData alertIcon;
    
    switch (alert.severity) {
      case AlertSeverity.critical:
        alertColor = Colors.red;
        alertIcon = Icons.error;
        break;
      case AlertSeverity.high:
        alertColor = Colors.orange;
        alertIcon = Icons.warning;
        break;
      case AlertSeverity.medium:
        alertColor = Colors.yellow[700]!;
        alertIcon = Icons.info;
        break;
      case AlertSeverity.low:
        alertColor = Colors.blue;
        alertIcon = Icons.info_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(alertIcon, color: alertColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Triggered: ${_formatDateTime(alert.triggeredAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (!alert.resolved)
            TextButton(
              onPressed: () => _resolveAlert(alert.alertId),
              child: const Text('Resolve'),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[600]),
                const SizedBox(width: 8),
                Text(
                  'AI Insights',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_insights.isEmpty)
              const Text('No insights available at this time.')
            else
              ...(_insights.map((insight) => _buildInsightCard(insight)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.insights, color: Colors.blue[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketPositionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green[600]),
                const SizedBox(width: 8),
                Text(
                  'Market Position',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<MarketPosition>(
              future: widget.dashboard.getMarketPosition(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData) {
                  return const Text('Market position data not available');
                }
                
                final position = snapshot.data!;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPositionMetric(
                          'Current Rank',
                          '#${position.currentRanking}',
                          Colors.blue,
                        ),
                        _buildPositionMetric(
                          'Previous Rank',
                          '#${position.previousRanking}',
                          Colors.grey,
                        ),
                        _buildPositionMetric(
                          'Change',
                          position.isImproving ? '+${position.rankingChange}' : '${position.rankingChange}',
                          position.isImproving ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPositionMetric(
                      'Market Share',
                      '${(position.marketShare * 100).toStringAsFixed(2)}%',
                      Colors.purple,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _refreshData() async {
    try {
      final metrics = await widget.dashboard.getCurrentMetrics();
      final alerts = await widget.dashboard.getTriggeredAlerts(
        since: DateTime.now().subtract(Duration(hours: 24)),
        unresolvedOnly: true,
      );

      if (mounted) {
        setState(() {
          _currentMetrics = metrics;
          _recentAlerts = alerts.take(5).toList();
        });
        _updateInsights();
      }
    } catch (e) {
      print('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing data: $e')),
        );
      }
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    try {
      await widget.dashboard.resolveAlert(alertId);
      
      if (mounted) {
        setState(() {
          _recentAlerts.removeWhere((alert) => alert.alertId == alertId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert resolved')),
        );
      }
    } catch (e) {
      print('Error resolving alert: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving alert: $e')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}