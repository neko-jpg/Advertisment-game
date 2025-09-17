import 'dart:async';
import 'dart:convert';

import '../../core/logging/logger.dart';
import '../models/monetization_models.dart';

/// Service for storing and retrieving monetization data
class MonetizationStorageService {
  MonetizationStorageService({
    required AppLogger logger,
  }) : _logger = logger;

  final AppLogger _logger;
  Map<String, String> _mockStorage = {};

  static const String _keyPrefix = 'monetization_';
  static const String _adFrequencyKey = '${_keyPrefix}ad_frequency_';
  static const String _alternativeMonetizationKey = '${_keyPrefix}alternative_';
  static const String _monetizationDataKey = '${_keyPrefix}data_';
  static const String _spendingProfileKey = '${_keyPrefix}spending_';
  static const String _adHistoryKey = '${_keyPrefix}ad_history_';

  Future<void> initialize() async {
    try {
      // Mock implementation - no initialization needed
      _logger.debug('Mock monetization storage initialized');
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize monetization storage', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Updates ad frequency settings for a user
  Future<void> updateAdFrequencySettings(String userId, Map<String, dynamic> settings) async {
    try {
      await initialize();
      final key = '$_adFrequencyKey$userId';
      final json = jsonEncode(settings);
      _mockStorage[key] = json;
      
      _logger.debug('Updated ad frequency settings for user $userId');
    } catch (error, stackTrace) {
      _logger.error('Failed to update ad frequency settings', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Gets ad frequency settings for a user
  Future<Map<String, dynamic>?> getAdFrequencySettings(String userId) async {
    try {
      await initialize();
      final key = '$_adFrequencyKey$userId';
      final json = _mockStorage[key];
      
      if (json != null) {
        return Map<String, dynamic>.from(jsonDecode(json) as Map);
      }
      return null;
    } catch (error, stackTrace) {
      _logger.error('Failed to get ad frequency settings', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates alternative monetization suggestions
  Future<void> updateAlternativeMonetizationSuggestions(String userId, List<String> suggestions) async {
    try {
      await initialize();
      final key = '$_alternativeMonetizationKey$userId';
      final data = {
        'suggestions': suggestions,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final json = jsonEncode(data);
      _mockStorage[key] = json;
      
      _logger.debug('Updated alternative monetization suggestions for user $userId');
    } catch (error, stackTrace) {
      _logger.error('Failed to update alternative monetization suggestions', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Gets alternative monetization suggestions for a user
  Future<List<String>> getAlternativeMonetizationSuggestions(String userId) async {
    try {
      await initialize();
      final key = '$_alternativeMonetizationKey$userId';
      final json = _mockStorage[key];
      
      if (json != null) {
        final data = Map<String, dynamic>.from(jsonDecode(json) as Map);
        return List<String>.from(data['suggestions'] as List? ?? []);
      }
      return [];
    } catch (error, stackTrace) {
      _logger.error('Failed to get alternative monetization suggestions', 
          error: error, stackTrace: stackTrace);
      return [];
    }
  }

  /// Stores complete monetization data for a user
  Future<void> storeMonetizationData(MonetizationData data) async {
    try {
      await initialize();
      final key = '$_monetizationDataKey${data.userId}';
      final json = jsonEncode(data.toJson());
      _mockStorage[key] = json;
      
      _logger.debug('Stored monetization data for user ${data.userId}');
    } catch (error, stackTrace) {
      _logger.error('Failed to store monetization data', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Retrieves monetization data for a user
  Future<MonetizationData?> getMonetizationData(String userId) async {
    try {
      await initialize();
      final key = '$_monetizationDataKey$userId';
      final json = _mockStorage[key];
      
      if (json != null) {
        final data = Map<String, dynamic>.from(jsonDecode(json) as Map);
        return MonetizationData.fromJson(data);
      }
      return null;
    } catch (error, stackTrace) {
      _logger.error('Failed to get monetization data', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates spending profile for a user
  Future<void> updateSpendingProfile(SpendingProfile profile) async {
    try {
      await initialize();
      final key = '$_spendingProfileKey${profile.userId}';
      final json = jsonEncode(profile.toJson());
      _mockStorage[key] = json;
      
      _logger.debug('Updated spending profile for user ${profile.userId}');
    } catch (error, stackTrace) {
      _logger.error('Failed to update spending profile', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Gets spending profile for a user
  Future<SpendingProfile?> getSpendingProfile(String userId) async {
    try {
      await initialize();
      final key = '$_spendingProfileKey$userId';
      final json = _mockStorage[key];
      
      if (json != null) {
        final data = Map<String, dynamic>.from(jsonDecode(json) as Map);
        return SpendingProfile.fromJson(data);
      }
      return null;
    } catch (error, stackTrace) {
      _logger.error('Failed to get spending profile', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates ad interaction history for a user
  Future<void> updateAdInteractionHistory(AdInteractionHistory history) async {
    try {
      await initialize();
      final key = '$_adHistoryKey${history.userId}';
      final json = jsonEncode(history.toJson());
      _mockStorage[key] = json;
      
      _logger.debug('Updated ad interaction history for user ${history.userId}');
    } catch (error, stackTrace) {
      _logger.error('Failed to update ad interaction history', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Gets ad interaction history for a user
  Future<AdInteractionHistory?> getAdInteractionHistory(String userId) async {
    try {
      await initialize();
      final key = '$_adHistoryKey$userId';
      final json = _mockStorage[key];
      
      if (json != null) {
        final data = Map<String, dynamic>.from(jsonDecode(json) as Map);
        return AdInteractionHistory.fromJson(data);
      }
      return null;
    } catch (error, stackTrace) {
      _logger.error('Failed to get ad interaction history', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Records an ad interaction
  Future<void> recordAdInteraction(String userId, {
    required String adType,
    required Duration viewDuration,
    required bool completed,
    required bool skipped,
  }) async {
    try {
      final history = await getAdInteractionHistory(userId);
      final now = DateTime.now();
      
      if (history != null) {
        // Update existing history
        final updatedHistory = AdInteractionHistory(
          userId: userId,
          totalAdsViewed: history.totalAdsViewed + 1,
          adsViewedToday: _isSameDay(history.lastAdViewTime, now) 
              ? history.adsViewedToday + 1 
              : 1,
          lastAdViewTime: now,
          averageViewDuration: Duration(
            milliseconds: ((history.averageViewDuration.inMilliseconds * history.totalAdsViewed) + 
                          viewDuration.inMilliseconds) ~/ (history.totalAdsViewed + 1),
          ),
          skipRate: ((history.skipRate * history.totalAdsViewed) + (skipped ? 1.0 : 0.0)) / 
                   (history.totalAdsViewed + 1),
          rewardedAdEngagement: adType == 'rewarded' 
              ? ((history.rewardedAdEngagement * history.totalAdsViewed) + (completed ? 1.0 : 0.0)) / 
                (history.totalAdsViewed + 1)
              : history.rewardedAdEngagement,
          interstitialTolerance: adType == 'interstitial'
              ? ((history.interstitialTolerance * history.totalAdsViewed) + (completed ? 1.0 : 0.0)) / 
                (history.totalAdsViewed + 1)
              : history.interstitialTolerance,
        );
        
        await updateAdInteractionHistory(updatedHistory);
      } else {
        // Create new history
        final newHistory = AdInteractionHistory(
          userId: userId,
          totalAdsViewed: 1,
          adsViewedToday: 1,
          lastAdViewTime: now,
          averageViewDuration: viewDuration,
          skipRate: skipped ? 1.0 : 0.0,
          rewardedAdEngagement: adType == 'rewarded' && completed ? 1.0 : 0.0,
          interstitialTolerance: adType == 'interstitial' && completed ? 1.0 : 0.0,
        );
        
        await updateAdInteractionHistory(newHistory);
      }
    } catch (error, stackTrace) {
      _logger.error('Failed to record ad interaction', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Records a purchase
  Future<void> recordPurchase(String userId, {
    required double amount,
    required String currency,
    required String productId,
  }) async {
    try {
      final profile = await getSpendingProfile(userId);
      final now = DateTime.now();
      
      if (profile != null) {
        // Update existing profile
        final totalTransactions = (profile.totalSpent / profile.averageTransactionValue).round();
        final updatedProfile = SpendingProfile(
          userId: userId,
          totalSpent: profile.totalSpent + amount,
          averageTransactionValue: (profile.totalSpent + amount) / (totalTransactions + 1),
          purchaseFrequency: profile.purchaseFrequency, // This would need more complex calculation
          preferredPriceRange: _calculatePriceRange(amount),
          lastPurchaseDate: now,
          conversionRate: profile.conversionRate, // This would be updated by analytics
        );
        
        await updateSpendingProfile(updatedProfile);
      } else {
        // Create new profile
        final newProfile = SpendingProfile(
          userId: userId,
          totalSpent: amount,
          averageTransactionValue: amount,
          purchaseFrequency: 1.0,
          preferredPriceRange: _calculatePriceRange(amount),
          lastPurchaseDate: now,
          conversionRate: 1.0, // First purchase = 100% conversion
        );
        
        await updateSpendingProfile(newProfile);
      }
    } catch (error, stackTrace) {
      _logger.error('Failed to record purchase', 
          error: error, stackTrace: stackTrace);
    }
  }

  bool _isSameDay(DateTime? date1, DateTime date2) {
    if (date1 == null) return false;
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  PriceRange _calculatePriceRange(double amount) {
    if (amount <= 200) return PriceRange.low;
    if (amount <= 500) return PriceRange.medium;
    if (amount <= 1000) return PriceRange.high;
    return PriceRange.premium;
  }

  /// Clears all monetization data (for testing or user data deletion)
  Future<void> clearAllData() async {
    try {
      await initialize();
      final keys = _mockStorage.keys.where((key) => key.startsWith(_keyPrefix)).toList();
      
      for (final key in keys) {
        _mockStorage.remove(key);
      }
      
      _logger.info('Cleared all monetization data');
    } catch (error, stackTrace) {
      _logger.error('Failed to clear monetization data', 
          error: error, stackTrace: stackTrace);
    }
  }
}