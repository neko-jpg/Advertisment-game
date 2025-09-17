import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/logging/logger.dart';
import 'ad_experience_manager.dart' show AdType;
import 'models/monetization_models.dart';

/// Multi-network ad system with eCPM optimization
/// 
/// Implements requirements:
/// - AdMob, Unity Ads, IronSource integration
/// - eCPM optimization engine for revenue maximization
/// - Fallback system between ad networks
/// - Regional ad delivery optimization for global revenue
class MultiNetworkAdSystem {
  MultiNetworkAdSystem({
    required AppLogger logger,
  }) : _logger = logger;

  final AppLogger _logger;

  final Map<AdNetworkType, AdNetworkAdapter> _adapters = {};
  final Map<AdNetworkType, NetworkPerformanceMetrics> _performanceMetrics = {};
  
  bool _isInitialized = false;
  String _currentRegion = 'JP'; // Default to Japan

  /// Initializes all ad networks
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _logger.info('Initializing multi-network ad system...');

      // Initialize AdMob
      _adapters[AdNetworkType.admob] = AdMobAdapter(logger: _logger);
      await _adapters[AdNetworkType.admob]!.initialize();

      // Initialize Unity Ads
      _adapters[AdNetworkType.unityAds] = UnityAdsAdapter(logger: _logger);
      await _adapters[AdNetworkType.unityAds]!.initialize();

      // Initialize IronSource
      _adapters[AdNetworkType.ironSource] = IronSourceAdapter(logger: _logger);
      await _adapters[AdNetworkType.ironSource]!.initialize();

      // Initialize performance tracking
      _initializePerformanceTracking();

      _isInitialized = true;
      _logger.info('Multi-network ad system initialized successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize multi-network ad system', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Shows ad with optimal network selection based on eCPM
  Future<AdResult?> showOptimalAd(AdType adType, String placement) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Get optimal network based on eCPM and availability
      final optimalNetwork = await _selectOptimalNetwork(adType, placement);
      if (optimalNetwork == null) {
        _logger.warn('No available network for ad type: ${adType.name}');
        return null;
      }

      _logger.info('Showing ${adType.name} ad via ${optimalNetwork.name} for placement: $placement');

      // Attempt to show ad with primary network
      var result = await _showAdWithNetwork(optimalNetwork, adType, placement);
      
      // If primary network fails, try fallback networks
      if (result == null || !result.success) {
        result = await _showAdWithFallback(adType, placement, optimalNetwork);
      }

      // Update performance metrics
      if (result != null) {
        await _updatePerformanceMetrics(optimalNetwork, result);
      }

      return result;
    } catch (error, stackTrace) {
      _logger.error('Error showing optimal ad', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Selects optimal network based on eCPM and performance
  Future<AdNetworkType?> _selectOptimalNetwork(AdType adType, String placement) async {
    try {
      final availableNetworks = <AdNetworkType>[];
      
      // Check which networks have ads available
      for (final entry in _adapters.entries) {
        final network = entry.key;
        final adapter = entry.value;
        
        if (await adapter.isAdAvailable(adType)) {
          availableNetworks.add(network);
        }
      }

      if (availableNetworks.isEmpty) {
        return null;
      }

      // Calculate weighted scores for each network
      final networkScores = <AdNetworkType, double>{};
      
      for (final network in availableNetworks) {
        final score = await _calculateNetworkScore(network, adType, placement);
        networkScores[network] = score;
      }

      // Select network with highest score
      final optimalNetwork = networkScores.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      _logger.debug('Selected optimal network: ${optimalNetwork.name} '
          'with score: ${networkScores[optimalNetwork]}');

      return optimalNetwork;
    } catch (error, stackTrace) {
      _logger.error('Error selecting optimal network', 
          error: error, stackTrace: stackTrace);
      return availableNetworks.isNotEmpty ? availableNetworks.first : null;
    }
  }

  /// Calculates network score based on eCPM, fill rate, and latency
  Future<double> _calculateNetworkScore(AdNetworkType network, AdType adType, String placement) async {
    final metrics = _performanceMetrics[network];
    if (metrics == null) {
      return 0.0; // No data available
    }

    double score = 0.0;

    // eCPM weight (50% of score)
    final ecpm = metrics.getECPM(adType, _currentRegion);
    score += ecpm * 0.5;

    // Fill rate weight (30% of score)
    final fillRate = metrics.getFillRate(adType);
    score += fillRate * 30.0; // Scale to match eCPM range

    // Latency weight (20% of score) - lower latency is better
    final latency = metrics.getAverageLatency(adType);
    final latencyScore = math.max(0, 10 - (latency.inMilliseconds / 100));
    score += latencyScore * 0.2;

    // Regional performance bonus
    final regionalMultiplier = _getRegionalMultiplier(network, _currentRegion);
    score *= regionalMultiplier;

    return score;
  }

  /// Shows ad with specific network
  Future<AdResult?> _showAdWithNetwork(AdNetworkType network, AdType adType, String placement) async {
    try {
      final adapter = _adapters[network];
      if (adapter == null) {
        return null;
      }

      final startTime = DateTime.now();
      final result = await adapter.showAd(adType, placement);
      final endTime = DateTime.now();

      if (result != null) {
        result.network = network;
        result.latency = endTime.difference(startTime);
      }

      return result;
    } catch (error, stackTrace) {
      _logger.error('Error showing ad with network ${network.name}', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Shows ad with fallback networks
  Future<AdResult?> _showAdWithFallback(AdType adType, String placement, AdNetworkType excludeNetwork) async {
    final fallbackNetworks = AdNetworkType.values
        .where((network) => network != excludeNetwork)
        .toList();

    // Sort by priority/performance
    fallbackNetworks.sort((a, b) {
      final aMetrics = _performanceMetrics[a];
      final bMetrics = _performanceMetrics[b];
      
      if (aMetrics == null && bMetrics == null) return 0;
      if (aMetrics == null) return 1;
      if (bMetrics == null) return -1;
      
      return bMetrics.getFillRate(adType).compareTo(aMetrics.getFillRate(adType));
    });

    for (final network in fallbackNetworks) {
      final adapter = _adapters[network];
      if (adapter == null) continue;

      if (await adapter.isAdAvailable(adType)) {
        _logger.info('Trying fallback network: ${network.name}');
        
        final result = await _showAdWithNetwork(network, adType, placement);
        if (result != null && result.success) {
          _logger.info('Fallback successful with ${network.name}');
          return result;
        }
      }
    }

    _logger.warn('All fallback networks failed for ${adType.name}');
    return null;
  }

  /// Updates performance metrics after ad display
  Future<void> _updatePerformanceMetrics(AdNetworkType network, AdResult result) async {
    try {
      var metrics = _performanceMetrics[network];
      if (metrics == null) {
        metrics = NetworkPerformanceMetrics(network: network);
        _performanceMetrics[network] = metrics;
      }

      metrics.recordAdResult(result);
      
      _logger.debug('Updated metrics for ${network.name}: '
          'eCPM=${metrics.getECPM(result.adType, _currentRegion)}, '
          'fillRate=${metrics.getFillRate(result.adType)}');
    } catch (error, stackTrace) {
      _logger.error('Error updating performance metrics', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Gets regional multiplier for network performance
  double _getRegionalMultiplier(AdNetworkType network, String region) {
    // Regional performance data based on typical network strengths
    const regionalMultipliers = {
      AdNetworkType.admob: {
        'JP': 1.2, 'US': 1.3, 'EU': 1.1, 'AS': 1.0, 'OTHER': 0.9,
      },
      AdNetworkType.unityAds: {
        'JP': 1.0, 'US': 1.2, 'EU': 1.1, 'AS': 1.1, 'OTHER': 1.0,
      },
      AdNetworkType.ironSource: {
        'JP': 1.1, 'US': 1.1, 'EU': 1.0, 'AS': 1.2, 'OTHER': 0.8,
      },
    };

    return regionalMultipliers[network]?[region] ?? 1.0;
  }

  /// Initializes performance tracking
  void _initializePerformanceTracking() {
    for (final network in AdNetworkType.values) {
      _performanceMetrics[network] = NetworkPerformanceMetrics(network: network);
    }
  }

  /// Sets current region for optimization
  void setRegion(String region) {
    _currentRegion = region;
    _logger.info('Set region to: $region');
  }

  /// Gets current eCPM for all networks
  Map<AdNetworkType, double> getCurrentECPMs(AdType adType) {
    final ecpms = <AdNetworkType, double>{};
    
    for (final entry in _performanceMetrics.entries) {
      ecpms[entry.key] = entry.value.getECPM(adType, _currentRegion);
    }
    
    return ecpms;
  }

  /// Gets performance report
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    for (final entry in _performanceMetrics.entries) {
      report[entry.key.name] = entry.value.toJson();
    }
    
    return report;
  }

  /// Disposes resources
  void dispose() {
    for (final adapter in _adapters.values) {
      adapter.dispose();
    }
    _adapters.clear();
    _performanceMetrics.clear();
  }
}

/// Ad network types
enum AdNetworkType { admob, unityAds, ironSource }

/// Ad network adapter interface
abstract class AdNetworkAdapter {
  Future<void> initialize();
  Future<bool> isAdAvailable(AdType adType);
  Future<AdResult?> showAd(AdType adType, String placement);
  void dispose();
}

/// AdMob adapter implementation
class AdMobAdapter implements AdNetworkAdapter {
  AdMobAdapter({required AppLogger logger}) : _logger = logger;
  
  final AppLogger _logger;

  @override
  Future<void> initialize() async {
    _logger.info('Initializing AdMob adapter');
    // Implementation would initialize AdMob SDK
  }

  @override
  Future<bool> isAdAvailable(AdType adType) async {
    // Implementation would check AdMob ad availability
    return true; // Placeholder
  }

  @override
  Future<AdResult?> showAd(AdType adType, String placement) async {
    // Implementation would show AdMob ad
    return AdResult(
      success: true,
      adType: adType,
      placement: placement,
      revenue: _simulateRevenue(adType),
      network: AdNetworkType.admob,
      latency: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _logger.info('Disposing AdMob adapter');
  }

  double _simulateRevenue(AdType adType) {
    return switch (adType) {
      AdType.rewarded => 0.05 + (math.Random().nextDouble() * 0.03),
      AdType.interstitial => 0.03 + (math.Random().nextDouble() * 0.02),
      AdType.banner => 0.001 + (math.Random().nextDouble() * 0.0005),
    };
  }
}

/// Unity Ads adapter implementation
class UnityAdsAdapter implements AdNetworkAdapter {
  UnityAdsAdapter({required AppLogger logger}) : _logger = logger;
  
  final AppLogger _logger;

  @override
  Future<void> initialize() async {
    _logger.info('Initializing Unity Ads adapter');
    // Implementation would initialize Unity Ads SDK
  }

  @override
  Future<bool> isAdAvailable(AdType adType) async {
    // Implementation would check Unity Ads availability
    return true; // Placeholder
  }

  @override
  Future<AdResult?> showAd(AdType adType, String placement) async {
    // Implementation would show Unity ad
    return AdResult(
      success: true,
      adType: adType,
      placement: placement,
      revenue: _simulateRevenue(adType),
      network: AdNetworkType.unityAds,
      latency: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _logger.info('Disposing Unity Ads adapter');
  }

  double _simulateRevenue(AdType adType) {
    return switch (adType) {
      AdType.rewarded => 0.04 + (math.Random().nextDouble() * 0.025),
      AdType.interstitial => 0.025 + (math.Random().nextDouble() * 0.015),
      AdType.banner => 0.0008 + (math.Random().nextDouble() * 0.0004),
    };
  }
}

/// IronSource adapter implementation
class IronSourceAdapter implements AdNetworkAdapter {
  IronSourceAdapter({required AppLogger logger}) : _logger = logger;
  
  final AppLogger _logger;

  @override
  Future<void> initialize() async {
    _logger.info('Initializing IronSource adapter');
    // Implementation would initialize IronSource SDK
  }

  @override
  Future<bool> isAdAvailable(AdType adType) async {
    // Implementation would check IronSource availability
    return true; // Placeholder
  }

  @override
  Future<AdResult?> showAd(AdType adType, String placement) async {
    // Implementation would show IronSource ad
    return AdResult(
      success: true,
      adType: adType,
      placement: placement,
      revenue: _simulateRevenue(adType),
      network: AdNetworkType.ironSource,
      latency: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _logger.info('Disposing IronSource adapter');
  }

  double _simulateRevenue(AdType adType) {
    return switch (adType) {
      AdType.rewarded => 0.045 + (math.Random().nextDouble() * 0.028),
      AdType.interstitial => 0.028 + (math.Random().nextDouble() * 0.018),
      AdType.banner => 0.0009 + (math.Random().nextDouble() * 0.0006),
    };
  }
}

/// Network performance metrics
class NetworkPerformanceMetrics {
  NetworkPerformanceMetrics({required this.network});

  final AdNetworkType network;
  final Map<AdType, List<AdResult>> _results = {};
  final Map<String, Map<AdType, double>> _regionalECPMs = {};

  void recordAdResult(AdResult result) {
    _results[result.adType] ??= [];
    _results[result.adType]!.add(result);

    // Keep only recent results (last 100 per ad type)
    if (_results[result.adType]!.length > 100) {
      _results[result.adType]!.removeAt(0);
    }
  }

  double getECPM(AdType adType, String region) {
    final results = _results[adType];
    if (results == null || results.isEmpty) {
      return 0.0;
    }

    final totalRevenue = results.fold<double>(0.0, (sum, result) => sum + result.revenue);
    final totalImpressions = results.length;
    
    return (totalRevenue / totalImpressions) * 1000; // eCPM = revenue per 1000 impressions
  }

  double getFillRate(AdType adType) {
    final results = _results[adType];
    if (results == null || results.isEmpty) {
      return 0.0;
    }

    final successfulAds = results.where((r) => r.success).length;
    return successfulAds / results.length;
  }

  Duration getAverageLatency(AdType adType) {
    final results = _results[adType];
    if (results == null || results.isEmpty) {
      return Duration.zero;
    }

    final totalLatency = results.fold<int>(0, (sum, result) => sum + result.latency.inMilliseconds);
    return Duration(milliseconds: totalLatency ~/ results.length);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'network': network.name,
      'adTypes': <String, dynamic>{},
    };

    for (final entry in _results.entries) {
      final adType = entry.key;
      json['adTypes'][adType.name] = {
        'ecpm': getECPM(adType, 'JP'), // Default region
        'fillRate': getFillRate(adType),
        'averageLatency': getAverageLatency(adType).inMilliseconds,
        'totalImpressions': entry.value.length,
      };
    }

    return json;
  }
}

/// Ad result with network information
class AdResult {
  AdResult({
    required this.success,
    required this.adType,
    required this.placement,
    required this.revenue,
    required this.latency,
    this.network,
  });

  final bool success;
  final AdType adType;
  final String placement;
  final double revenue;
  final Duration latency;
  AdNetworkType? network;
}