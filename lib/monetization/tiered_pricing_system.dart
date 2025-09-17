import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/analytics/models/behavior_models.dart';
import '../core/logging/logger.dart';
import 'models/monetization_models.dart';
import 'services/monetization_storage_service.dart';

/// Manages tiered pricing and subscription system
/// 
/// Implements requirements:
/// - 2.5: 4-tier pricing system (120, 250, 480, 980 yen)
/// - 2.6: VIP Pass subscription (480 yen/month) with purchase intent detection
class TieredPricingSystem {
  TieredPricingSystem({
    required MonetizationStorageService storageService,
    required AppLogger logger,
  }) : _storageService = storageService,
       _logger = logger;

  final MonetizationStorageService _storageService;
  final AppLogger _logger;

  // Tier definitions as specified in requirements
  static const List<PriceTier> _priceTiers = [
    PriceTier(
      id: 'starter_pack',
      price: 120.0,
      currency: 'JPY',
      coins: 100,
      bonusPercentage: 0.0,
      gems: 0,
      title: 'スターターパック',
      description: '100コイン',
    ),
    PriceTier(
      id: 'value_pack',
      price: 250.0,
      currency: 'JPY',
      coins: 200,
      bonusPercentage: 25.0,
      gems: 5,
      title: 'バリューパック',
      description: '250コイン + 5ジェム',
    ),
    PriceTier(
      id: 'premium_pack',
      price: 480.0,
      currency: 'JPY',
      coins: 400,
      bonusPercentage: 50.0,
      gems: 15,
      title: 'プレミアムパック',
      description: '600コイン + 15ジェム',
    ),
    PriceTier(
      id: 'mega_pack',
      price: 980.0,
      currency: 'JPY',
      coins: 800,
      bonusPercentage: 75.0,
      gems: 40,
      title: 'メガパック',
      description: '1400コイン + 40ジェム',
    ),
  ];

  // VIP Pass subscription as specified
  static const SubscriptionTier _vipPassTier = SubscriptionTier(
    id: 'vip_pass_monthly',
    monthlyPrice: 480.0,
    currency: 'JPY',
    title: 'VIPパス',
    description: '広告なし + プレミアム特典',
    benefits: [
      '広告完全削除',
      'デイリーコイン2倍',
      '限定スキン・テーマ',
      'プレミアム描画ツール',
      '優先サポート',
      '特別イベント先行参加',
    ],
  );

  /// Detects purchase intent based on user behavior
  /// Requirement 2.6: Purchase intent detection
  Future<PurchaseIntent> detectPurchaseIntent(String userId, UserBehaviorData behaviorData) async {
    try {
      final intent = PurchaseIntent(
        userId: userId,
        intentLevel: await _calculateIntentLevel(behaviorData),
        recommendedTier: await _recommendOptimalTier(userId, behaviorData),
        triggerEvents: _identifyTriggerEvents(behaviorData),
        confidence: await _calculateConfidence(behaviorData),
        timestamp: DateTime.now(),
      );

      _logger.info('Detected purchase intent for user $userId: '
          'level=${intent.intentLevel.name}, confidence=${intent.confidence}');

      return intent;
    } catch (error, stackTrace) {
      _logger.error('Error detecting purchase intent', 
          error: error, stackTrace: stackTrace);
      
      return PurchaseIntent(
        userId: userId,
        intentLevel: IntentLevel.none,
        recommendedTier: _priceTiers.first,
        triggerEvents: [],
        confidence: 0.0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Generates appropriate offer based on purchase intent
  /// Requirement 2.5: Staged pricing presentation
  Future<List<IAPOffer>> generateAppropriateOffers(PurchaseIntent intent) async {
    try {
      final offers = <IAPOffer>[];
      final spendingProfile = await _storageService.getSpendingProfile(intent.userId);
      
      // Select tiers based on intent level
      final selectedTiers = _selectTiersForIntent(intent);
      
      for (final tier in selectedTiers) {
        final personalizedOffer = _createPersonalizedOffer(tier, intent, spendingProfile);
        offers.add(personalizedOffer);
      }

      // Sort by recommendation score
      offers.sort((a, b) => _scoreOfferForUser(b, intent, spendingProfile)
          .compareTo(_scoreOfferForUser(a, intent, spendingProfile)));

      _logger.debug('Generated ${offers.length} offers for user ${intent.userId}');
      return offers;
    } catch (error, stackTrace) {
      _logger.error('Error generating offers', error: error, stackTrace: stackTrace);
      return [];
    }
  }

  /// Creates VIP Pass subscription offer
  /// Requirement 2.6: VIP Pass (480 yen/month)
  Future<SubscriptionOffer> createVIPPassOffer(String userId, {
    double? discountPercentage,
    int? trialDays,
  }) async {
    try {
      final monetizationData = await _storageService.getMonetizationData(userId);
      final adFatigueLevel = monetizationData?.adInteractionHistory.fatigueLevel ?? AdFatigueLevel.none;
      
      // Calculate personalized discount based on ad fatigue
      final finalDiscount = discountPercentage ?? _calculateVIPDiscount(adFatigueLevel);
      final finalTrialDays = trialDays ?? _calculateTrialDays(monetizationData);
      
      final offer = SubscriptionOffer(
        id: _vipPassTier.id,
        title: _vipPassTier.title,
        description: _vipPassTier.description,
        monthlyPrice: _vipPassTier.monthlyPrice * (1 - finalDiscount / 100),
        currency: _vipPassTier.currency,
        benefits: _vipPassTier.benefits,
        trialDays: finalTrialDays,
        discountPercentage: finalDiscount,
        personalizedPitch: _generateVIPPitch(userId, adFatigueLevel, monetizationData),
      );

      _logger.info('Created VIP Pass offer for user $userId: '
          'discount=${finalDiscount}%, trial=${finalTrialDays}days');

      return offer;
    } catch (error, stackTrace) {
      _logger.error('Error creating VIP Pass offer', 
          error: error, stackTrace: stackTrace);
      
      // Return default offer on error
      return SubscriptionOffer(
        id: _vipPassTier.id,
        title: _vipPassTier.title,
        description: _vipPassTier.description,
        monthlyPrice: _vipPassTier.monthlyPrice,
        currency: _vipPassTier.currency,
        benefits: _vipPassTier.benefits,
        trialDays: 7,
        discountPercentage: 0.0,
        personalizedPitch: 'プレミアム体験で新しいゲームの楽しさを発見',
      );
    }
  }

  /// Presents appropriate offer at optimal timing
  Future<OfferPresentation?> presentOptimalOffer(String userId, GameContext context) async {
    try {
      // Check if user is in appropriate state for offers
      if (!_isAppropriateForOffers(context)) {
        return null;
      }

      // Get user data
      final behaviorData = await _getUserBehaviorData(userId);
      if (behaviorData == null) return null;

      // Detect purchase intent
      final intent = await detectPurchaseIntent(userId, behaviorData);
      
      // Don't show offers if intent is too low
      if (intent.intentLevel == IntentLevel.none || intent.confidence < 0.3) {
        return null;
      }

      // Generate appropriate offers
      final offers = await generateAppropriateOffers(intent);
      if (offers.isEmpty) return null;

      // Create presentation
      final presentation = OfferPresentation(
        userId: userId,
        primaryOffer: offers.first,
        alternativeOffers: offers.skip(1).take(2).toList(),
        presentationReason: _generatePresentationReason(context, intent),
        urgencyLevel: _calculateUrgencyLevel(intent, context),
        timestamp: DateTime.now(),
      );

      _logger.info('Presenting offer to user $userId: ${presentation.primaryOffer.title}');
      return presentation;
    } catch (error, stackTrace) {
      _logger.error('Error presenting optimal offer', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<IntentLevel> _calculateIntentLevel(UserBehaviorData behaviorData) async {
    double score = 0.0;

    // Session frequency indicates engagement
    if (behaviorData.sessions.length >= 10) score += 2.0;
    else if (behaviorData.sessions.length >= 5) score += 1.0;

    // Total play time indicates investment
    if (behaviorData.totalPlayTime.inHours >= 5) score += 2.0;
    else if (behaviorData.totalPlayTime.inHours >= 2) score += 1.0;

    // Recent activity indicates current interest
    if (behaviorData.daysSinceLastActive <= 1) score += 1.5;
    else if (behaviorData.daysSinceLastActive <= 3) score += 1.0;

    // Previous purchases indicate willingness to spend
    if (behaviorData.purchaseHistory.isNotEmpty) score += 3.0;

    // Ad interactions indicate tolerance for monetization
    final adEngagement = behaviorData.adInteractions.length / math.max(1, behaviorData.sessions.length);
    if (adEngagement >= 0.5) score += 1.0;

    // Convert score to intent level
    if (score >= 7.0) return IntentLevel.high;
    if (score >= 4.0) return IntentLevel.medium;
    if (score >= 2.0) return IntentLevel.low;
    return IntentLevel.none;
  }

  Future<PriceTier> _recommendOptimalTier(String userId, UserBehaviorData behaviorData) async {
    final spendingProfile = await _storageService.getSpendingProfile(userId);
    
    if (spendingProfile == null || spendingProfile.totalSpent == 0) {
      // New spender - recommend starter pack
      return _priceTiers.first;
    }

    // Recommend based on average transaction value
    final avgSpend = spendingProfile.averageTransactionValue;
    
    for (int i = _priceTiers.length - 1; i >= 0; i--) {
      if (avgSpend >= _priceTiers[i].price * 0.8) {
        return _priceTiers[i];
      }
    }
    
    return _priceTiers.first;
  }

  List<String> _identifyTriggerEvents(UserBehaviorData behaviorData) {
    final triggers = <String>[];
    
    // Analyze recent sessions for trigger patterns
    final recentSessions = behaviorData.sessions
        .where((s) => DateTime.now().difference(s.startTime).inDays <= 7)
        .toList();

    for (final session in recentSessions) {
      // Look for frustration patterns
      final gameOverActions = session.actions
          .where((a) => a.type == GameActionType.gameEnd)
          .length;
      if (gameOverActions >= 5) {
        triggers.add('multiple_failures');
      }

      // Look for achievement patterns
      final achievements = session.actions
          .where((a) => a.type == GameActionType.missionComplete)
          .length;
      if (achievements >= 2) {
        triggers.add('achievement_streak');
      }

      // Look for progression blocks
      if (session.duration.inMinutes >= 10 && gameOverActions >= 3) {
        triggers.add('progression_block');
      }
    }

    return triggers;
  }

  Future<double> _calculateConfidence(UserBehaviorData behaviorData) async {
    double confidence = 0.0;

    // Data quality affects confidence
    if (behaviorData.sessions.length >= 5) confidence += 0.3;
    if (behaviorData.totalPlayTime.inHours >= 2) confidence += 0.2;

    // Consistent behavior patterns increase confidence
    final sessionLengths = behaviorData.sessions.map((s) => s.duration.inMinutes).toList();
    if (sessionLengths.isNotEmpty) {
      final avgLength = sessionLengths.reduce((a, b) => a + b) / sessionLengths.length;
      final variance = sessionLengths.map((l) => math.pow(l - avgLength, 2)).reduce((a, b) => a + b) / sessionLengths.length;
      final consistency = 1.0 / (1.0 + variance / 100); // Normalize variance
      confidence += consistency * 0.3;
    }

    // Purchase history increases confidence
    if (behaviorData.purchaseHistory.isNotEmpty) confidence += 0.2;

    return math.min(1.0, confidence);
  }

  List<PriceTier> _selectTiersForIntent(PurchaseIntent intent) {
    return switch (intent.intentLevel) {
      IntentLevel.high => _priceTiers, // Show all options
      IntentLevel.medium => _priceTiers.take(3).toList(), // Show first 3 tiers
      IntentLevel.low => _priceTiers.take(2).toList(), // Show first 2 tiers
      IntentLevel.none => [_priceTiers.first], // Show only starter pack
    };
  }

  IAPOffer _createPersonalizedOffer(PriceTier tier, PurchaseIntent intent, SpendingProfile? profile) {
    final bonusCoins = (tier.coins * tier.bonusPercentage / 100).round();
    final totalCoins = tier.coins + bonusCoins;

    return IAPOffer(
      id: tier.id,
      title: tier.title,
      description: tier.bonusPercentage > 0 
          ? '${tier.coins}コイン + ${bonusCoins}ボーナス${tier.gems > 0 ? " + ${tier.gems}ジェム" : ""}'
          : tier.description,
      price: tier.price,
      currency: tier.currency,
      value: {
        'coins': totalCoins,
        'gems': tier.gems,
      },
      discountPercentage: tier.bonusPercentage,
      urgency: _calculateOfferUrgency(intent),
      personalizedReason: _generatePersonalizedReason(intent, tier, profile),
    );
  }

  double _scoreOfferForUser(IAPOffer offer, PurchaseIntent intent, SpendingProfile? profile) {
    double score = 0.0;

    // Intent level scoring
    score += switch (intent.intentLevel) {
      IntentLevel.high => 10.0,
      IntentLevel.medium => 7.0,
      IntentLevel.low => 4.0,
      IntentLevel.none => 1.0,
    };

    // Price preference scoring
    if (profile != null) {
      final priceRatio = offer.price / (profile.averageTransactionValue + 1);
      if (priceRatio >= 0.8 && priceRatio <= 1.2) {
        score += 5.0; // Perfect price range
      } else if (priceRatio <= 2.0) {
        score += 2.0; // Acceptable range
      }
    }

    // Confidence scoring
    score += intent.confidence * 3.0;

    return score;
  }

  double _calculateVIPDiscount(AdFatigueLevel fatigueLevel) {
    return switch (fatigueLevel) {
      AdFatigueLevel.critical => 50.0,
      AdFatigueLevel.high => 30.0,
      AdFatigueLevel.medium => 20.0,
      AdFatigueLevel.low => 10.0,
      AdFatigueLevel.none => 0.0,
    };
  }

  int _calculateTrialDays(MonetizationData? data) {
    if (data?.subscriptionStatus.trialUsed == true) return 0;
    
    // Offer longer trial for high-value users
    if (data?.lifetimeValue != null && data!.lifetimeValue > 1000) return 14;
    
    return 7; // Default trial period
  }

  String _generateVIPPitch(String userId, AdFatigueLevel fatigueLevel, MonetizationData? data) {
    if (fatigueLevel == AdFatigueLevel.critical) {
      return '広告にお疲れですか？VIPパスで快適なゲーム体験を！';
    } else if (fatigueLevel == AdFatigueLevel.high) {
      return '広告なしでもっと集中してプレイしませんか？';
    } else if (data?.spendingProfile.totalSpent != null && data!.spendingProfile.totalSpent > 500) {
      return 'いつもありがとうございます！VIPパスでさらにお得に';
    } else {
      return 'プレミアム体験で新しいゲームの楽しさを発見';
    }
  }

  bool _isAppropriateForOffers(GameContext context) {
    // Don't interrupt active gameplay
    if (context.gameState == GameState.playing) return false;
    
    // Don't show offers when user is frustrated
    if (context.playerMood == PlayerMood.frustrated) return false;
    
    // Good times for offers
    return context.gameState == GameState.gameOver || 
           context.gameState == GameState.levelComplete ||
           (context.gameState == GameState.menu && context.sessionDuration.inMinutes >= 5);
  }

  Future<UserBehaviorData?> _getUserBehaviorData(String userId) async {
    // This would typically fetch from your analytics service
    // For now, return null to indicate no data available
    return null;
  }

  String _generatePresentationReason(GameContext context, PurchaseIntent intent) {
    if (intent.triggerEvents.contains('multiple_failures')) {
      return 'もっと楽にプレイしませんか？';
    } else if (intent.triggerEvents.contains('achievement_streak')) {
      return '素晴らしい成果です！さらなる挑戦はいかがですか？';
    } else if (context.achievementJustUnlocked) {
      return '達成おめでとうございます！記念に特別オファーをどうぞ';
    } else {
      return 'あなたにおすすめの特別オファー';
    }
  }

  OfferUrgency _calculateOfferUrgency(PurchaseIntent intent) {
    return switch (intent.intentLevel) {
      IntentLevel.high => OfferUrgency.high,
      IntentLevel.medium => OfferUrgency.medium,
      IntentLevel.low => OfferUrgency.low,
      IntentLevel.none => OfferUrgency.none,
    };
  }

  OfferUrgency _calculateUrgencyLevel(PurchaseIntent intent, GameContext context) {
    var urgency = _calculateOfferUrgency(intent);
    
    // Increase urgency for special moments
    if (context.achievementJustUnlocked) {
      urgency = OfferUrgency.values[math.min(urgency.index + 1, OfferUrgency.values.length - 1)];
    }
    
    return urgency;
  }

  String _generatePersonalizedReason(PurchaseIntent intent, PriceTier tier, SpendingProfile? profile) {
    if (profile?.totalSpent == 0 || profile == null) {
      return tier.price <= 250 ? '初回購入特典付き！' : 'お得にスタート！';
    } else if (profile.purchaseFrequency > 2) {
      return 'いつもありがとうございます！特別価格でご提供';
    } else if (intent.triggerEvents.contains('progression_block')) {
      return 'プレイをもっと楽しくしませんか？';
    } else {
      return 'あなたにおすすめのパック';
    }
  }
}

/// Price tier definition
class PriceTier {
  const PriceTier({
    required this.id,
    required this.price,
    required this.currency,
    required this.coins,
    required this.bonusPercentage,
    required this.gems,
    required this.title,
    required this.description,
  });

  final String id;
  final double price;
  final String currency;
  final int coins;
  final double bonusPercentage;
  final int gems;
  final String title;
  final String description;
}

/// Subscription tier definition
class SubscriptionTier {
  const SubscriptionTier({
    required this.id,
    required this.monthlyPrice,
    required this.currency,
    required this.title,
    required this.description,
    required this.benefits,
  });

  final String id;
  final double monthlyPrice;
  final String currency;
  final String title;
  final String description;
  final List<String> benefits;
}

/// Purchase intent analysis result
class PurchaseIntent {
  const PurchaseIntent({
    required this.userId,
    required this.intentLevel,
    required this.recommendedTier,
    required this.triggerEvents,
    required this.confidence,
    required this.timestamp,
  });

  final String userId;
  final IntentLevel intentLevel;
  final PriceTier recommendedTier;
  final List<String> triggerEvents;
  final double confidence; // 0-1
  final DateTime timestamp;
}

enum IntentLevel { none, low, medium, high }

/// Offer presentation data
class OfferPresentation {
  const OfferPresentation({
    required this.userId,
    required this.primaryOffer,
    required this.alternativeOffers,
    required this.presentationReason,
    required this.urgencyLevel,
    required this.timestamp,
  });

  final String userId;
  final IAPOffer primaryOffer;
  final List<IAPOffer> alternativeOffers;
  final String presentationReason;
  final OfferUrgency urgencyLevel;
  final DateTime timestamp;
}