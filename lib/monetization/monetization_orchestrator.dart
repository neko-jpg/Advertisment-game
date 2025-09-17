import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/analytics/models/behavior_models.dart';
import '../core/logging/logger.dart';
import 'models/monetization_models.dart';
import 'services/monetization_storage_service.dart';

/// Orchestrates monetization strategies with UX consideration
/// 
/// Implements requirements:
/// - 2.4: Ad frequency auto-adjustment based on user fatigue
/// - 2.7: Ad fatigue detection and alternative monetization
class MonetizationOrchestrator {
  MonetizationOrchestrator({
    required MonetizationStorageService storageService,
    required AppLogger logger,
  }) : _storageService = storageService,
       _logger = logger;

  final MonetizationStorageService _storageService;
  final AppLogger _logger;

  // Ad frequency limits based on fatigue level
  static const Map<AdFatigueLevel, int> _maxDailyAds = {
    AdFatigueLevel.none: 25,
    AdFatigueLevel.low: 20,
    AdFatigueLevel.medium: 15,
    AdFatigueLevel.high: 8,
    AdFatigueLevel.critical: 3,
  };

  // Minimum time between ads based on fatigue
  static const Map<AdFatigueLevel, Duration> _adCooldowns = {
    AdFatigueLevel.none: Duration(minutes: 2),
    AdFatigueLevel.low: Duration(minutes: 3),
    AdFatigueLevel.medium: Duration(minutes: 5),
    AdFatigueLevel.high: Duration(minutes: 10),
    AdFatigueLevel.critical: Duration(minutes: 30),
  };

  /// Adjusts ad frequency based on user's ad interaction history
  /// Requirement 2.7: Ad fatigue detection and auto-adjustment
  Future<void> adjustAdFrequency(String userId, AdInteractionHistory history) async {
    try {
      final fatigueLevel = history.fatigueLevel;
      final maxAds = _maxDailyAds[fatigueLevel] ?? 15;
      final cooldown = _adCooldowns[fatigueLevel] ?? const Duration(minutes: 5);

      _logger.info('Adjusting ad frequency for user $userId: '
          'fatigue=${fatigueLevel.name}, maxAds=$maxAds, cooldown=${cooldown.inMinutes}min');

      // Store updated frequency settings
      await _storageService.updateAdFrequencySettings(userId, {
        'maxDailyAds': maxAds,
        'cooldownMinutes': cooldown.inMinutes,
        'fatigueLevel': fatigueLevel.name,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // If user is highly fatigued, suggest alternative monetization
      if (fatigueLevel == AdFatigueLevel.high || fatigueLevel == AdFatigueLevel.critical) {
        await _suggestAlternativeMonetization(userId, history);
      }
    } catch (error, stackTrace) {
      _logger.error('Failed to adjust ad frequency for user $userId', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Determines if an ad should be shown based on value proposition
  /// Requirement 2.4: User value-based ad placement
  Future<bool> shouldShowValuePropositionAd(GameContext context) async {
    try {
      // Don't show ads during negative moments
      if (context.playerMood == PlayerMood.frustrated || 
          context.consecutiveFailures >= 3) {
        return false;
      }

      // Prefer showing ads at natural break points
      if (!context.isNaturalBreakPoint) {
        return false;
      }

      // Show ads when player achieved something (positive reinforcement)
      if (context.isPositiveMoment) {
        return true;
      }

      // Show ads after reasonable session duration
      if (context.sessionDuration.inMinutes >= 3) {
        return true;
      }

      return false;
    } catch (error, stackTrace) {
      _logger.error('Error determining ad value proposition', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Generates tiered IAP offers based on user spending profile
  /// Requirement 2.5: Staged pricing system (120, 250, 480, 980 yen)
  List<IAPOffer> generateTieredOffers(SpendingProfile profile) {
    try {
      final offers = <IAPOffer>[];
      
      // Base tier offers (120-980 yen as specified)
      final basePrices = [120.0, 250.0, 480.0, 980.0];
      
      for (int i = 0; i < basePrices.length; i++) {
        final price = basePrices[i];
        final coinMultiplier = (i + 1) * 100; // 100, 200, 300, 400 coins
        final bonusMultiplier = i * 0.2; // 0%, 20%, 40%, 60% bonus
        
        offers.add(IAPOffer(
          id: 'coins_tier_${i + 1}',
          title: _getTierTitle(i),
          description: _getTierDescription(i, coinMultiplier, bonusMultiplier),
          price: price,
          currency: 'JPY',
          value: {
            'coins': (coinMultiplier * (1 + bonusMultiplier)).round(),
            'gems': i > 1 ? (i - 1) * 5 : 0, // Gems for higher tiers
          },
          discountPercentage: bonusMultiplier * 100,
          urgency: _calculateOfferUrgency(profile, price),
          personalizedReason: _generatePersonalizedReason(profile, i),
        ));
      }

      // Sort offers based on user's preferred price range
      offers.sort((a, b) => _scoreOfferForUser(b, profile).compareTo(_scoreOfferForUser(a, profile)));
      
      return offers;
    } catch (error, stackTrace) {
      _logger.error('Error generating tiered offers', error: error, stackTrace: stackTrace);
      return [];
    }
  }

  /// Optimizes subscription offer based on user data
  /// Requirement 2.6: VIP Pass (480 yen/month) subscription
  Future<SubscriptionOffer> optimizeSubscriptionOffer(MonetizationData userData) async {
    try {
      final basePrice = 480.0; // As specified in requirements
      final fatigueLevel = userData.adInteractionHistory.fatigueLevel;
      
      // Offer bigger discount for users with high ad fatigue
      final discountPercentage = switch (fatigueLevel) {
        AdFatigueLevel.critical => 50.0,
        AdFatigueLevel.high => 30.0,
        AdFatigueLevel.medium => 20.0,
        AdFatigueLevel.low => 10.0,
        AdFatigueLevel.none => 0.0,
      };

      final trialDays = userData.subscriptionStatus.trialUsed ? 0 : 7;
      
      return SubscriptionOffer(
        id: 'vip_pass_monthly',
        title: 'VIPパス',
        description: '広告なし + プレミアム特典',
        monthlyPrice: basePrice * (1 - discountPercentage / 100),
        currency: 'JPY',
        benefits: [
          '広告完全削除',
          'デイリーコイン2倍',
          '限定スキン・テーマ',
          'プレミアム描画ツール',
          '優先サポート',
        ],
        trialDays: trialDays,
        discountPercentage: discountPercentage,
        personalizedPitch: _generateSubscriptionPitch(userData, fatigueLevel),
      );
    } catch (error, stackTrace) {
      _logger.error('Error optimizing subscription offer', 
          error: error, stackTrace: stackTrace);
      
      // Return default offer on error
      return const SubscriptionOffer(
        id: 'vip_pass_monthly',
        title: 'VIPパス',
        description: '広告なし + プレミアム特典',
        monthlyPrice: 480.0,
        currency: 'JPY',
        benefits: ['広告完全削除', 'プレミアム特典'],
        trialDays: 7,
        discountPercentage: 0.0,
        personalizedPitch: 'より快適なゲーム体験をお楽しみください',
      );
    }
  }

  /// Suggests alternative monetization when ad fatigue is high
  Future<void> _suggestAlternativeMonetization(String userId, AdInteractionHistory history) async {
    try {
      final alternatives = <String>[];
      
      if (history.fatigueLevel == AdFatigueLevel.critical) {
        alternatives.addAll([
          'subscription_offer',
          'premium_currency_bundle',
          'cosmetic_items',
        ]);
      } else if (history.fatigueLevel == AdFatigueLevel.high) {
        alternatives.addAll([
          'subscription_trial',
          'small_currency_pack',
        ]);
      }

      await _storageService.updateAlternativeMonetizationSuggestions(userId, alternatives);
      
      _logger.info('Suggested alternative monetization for user $userId: $alternatives');
    } catch (error, stackTrace) {
      _logger.error('Error suggesting alternative monetization', 
          error: error, stackTrace: stackTrace);
    }
  }

  String _getTierTitle(int tier) {
    return switch (tier) {
      0 => 'スターターパック',
      1 => 'バリューパック',
      2 => 'プレミアムパック',
      3 => 'メガパック',
      _ => 'スペシャルパック',
    };
  }

  String _getTierDescription(int tier, int coins, double bonusMultiplier) {
    final bonus = bonusMultiplier > 0 ? ' + ${(bonusMultiplier * 100).round()}%ボーナス' : '';
    return '$coinsコイン$bonus';
  }

  OfferUrgency _calculateOfferUrgency(SpendingProfile profile, double price) {
    if (profile.conversionRate > 0.8 && price <= profile.averageTransactionValue * 1.2) {
      return OfferUrgency.high;
    } else if (profile.conversionRate > 0.5) {
      return OfferUrgency.medium;
    } else if (profile.conversionRate > 0.2) {
      return OfferUrgency.low;
    }
    return OfferUrgency.none;
  }

  String _generatePersonalizedReason(SpendingProfile profile, int tier) {
    if (profile.totalSpent == 0) {
      return tier == 0 ? '初回購入特典付き！' : 'お得にスタート！';
    } else if (profile.purchaseFrequency > 2) {
      return 'いつもありがとうございます！特別価格でご提供';
    } else {
      return 'あなたにおすすめのパック';
    }
  }

  double _scoreOfferForUser(IAPOffer offer, SpendingProfile profile) {
    double score = 0.0;
    
    // Price preference scoring
    final priceRatio = offer.price / (profile.averageTransactionValue + 1);
    if (priceRatio >= 0.8 && priceRatio <= 1.2) {
      score += 10.0; // Perfect price range
    } else if (priceRatio <= 2.0) {
      score += 5.0; // Acceptable range
    }
    
    // Conversion rate influence
    score += profile.conversionRate * 5.0;
    
    // Discount bonus
    score += offer.discountPercentage * 0.1;
    
    return score;
  }

  String _generateSubscriptionPitch(MonetizationData userData, AdFatigueLevel fatigueLevel) {
    if (fatigueLevel == AdFatigueLevel.critical) {
      return '広告にお疲れですか？VIPパスで快適なゲーム体験を！';
    } else if (fatigueLevel == AdFatigueLevel.high) {
      return '広告なしでもっと集中してプレイしませんか？';
    } else if (userData.spendingProfile.totalSpent > 500) {
      return 'いつもありがとうございます！VIPパスでさらにお得に';
    } else {
      return 'プレミアム体験で新しいゲームの楽しさを発見';
    }
  }
}