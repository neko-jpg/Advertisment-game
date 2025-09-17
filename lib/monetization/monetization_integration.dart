import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/analytics/models/behavior_models.dart';
import '../core/logging/logger.dart';
import 'ad_experience_manager.dart' as ad_experience_manager;
import 'billing_system.dart';
import 'models/monetization_models.dart';
import 'monetization_orchestrator.dart';
import 'multi_network_ad_system.dart';
import 'services/monetization_storage_service.dart';
import 'tiered_pricing_system.dart';

/// Comprehensive monetization integration system
/// 
/// Integrates all monetization components:
/// - MonetizationOrchestrator for UX-considerate ad management
/// - AdExperienceManager for natural ad timing
/// - TieredPricingSystem for staged pricing and subscriptions
/// - BillingSystem for Google Play Billing
/// - MultiNetworkAdSystem for revenue optimization
class MonetizationIntegration {
  MonetizationIntegration({
    required AppLogger logger,
  }) : _logger = logger {
    _initializeComponents();
  }

  final AppLogger _logger;
  
  late final MonetizationStorageService _storageService;
  late final MonetizationOrchestrator _orchestrator;
  late final ad_experience_manager.AdExperienceManager _adExperienceManager;
  late final TieredPricingSystem _pricingSystem;
  late final BillingSystem _billingSystem;
  late final MultiNetworkAdSystem _multiNetworkAdSystem;

  bool _isInitialized = false;

  /// Initializes all monetization components
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _logger.info('Initializing monetization integration system...');

      // Initialize storage service first
      await _storageService.initialize();

      // Initialize all components
      await Future.wait([
        _billingSystem.initialize(),
        _multiNetworkAdSystem.initialize(),
      ]);

      _isInitialized = true;
      _logger.info('Monetization integration system initialized successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize monetization integration', 
          error: error, stackTrace: stackTrace);
    }
  }

  /// Shows ad with comprehensive UX consideration and optimization
  Future<bool> showOptimalAd({
    required String userId,
    required GameContext gameContext,
    required UserSession userSession,
    required String placement,
    ad_experience_manager.AdType adType = ad_experience_manager.AdType.interstitial,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Check if this is a natural moment for ads
      if (!_adExperienceManager.isNaturalAdMoment(gameContext.gameState, userSession)) {
        _logger.debug('Not a natural moment for ads');
        return false;
      }

      // Get user's ad interaction history
      final adHistory = await _storageService.getAdInteractionHistory(userId);
      if (adHistory != null) {
        // Adjust ad frequency based on fatigue
        await _orchestrator.adjustAdFrequency(userId, adHistory);
        
        // Check if user has reached ad limits
        if (_adExperienceManager.hasReachedSessionAdLimit(userId)) {
          _logger.debug('User has reached session ad limit');
          return false;
        }
      }

      // Check if we should show value proposition ad
      final shouldShow = await _orchestrator.shouldShowValuePropositionAd(gameContext);
      if (!shouldShow) {
        _logger.debug('Value proposition check failed');
        return false;
      }

      // Generate ad value proposition
      final valueProposition = _adExperienceManager.generateAdValueProposition(adType, gameContext);
      _logger.info('Showing ad with proposition: $valueProposition');

      // Show ad through multi-network system
      final adResult = await _multiNetworkAdSystem.showOptimalAd(adType, placement);
      
      if (adResult != null && adResult.success) {
        // Handle post-ad experience
        final adResultForExperience = ad_experience_manager.AdResult(
          userId: userId,
          adType: adType,
          completed: adResult.success,
          viewDuration: adResult.latency,
          rewardEarned: adType == AdType.rewarded && adResult.success,
          rewardDescription: adType == AdType.rewarded ? 'コイン2倍' : null,
        );

        await _adExperienceManager.handlePostAdExperience(adResultForExperience);
        
        _logger.info('Successfully showed ad for user $userId via ${adResult.network?.name}');
        return true;
      } else {
        _logger.warn('Failed to show ad for user $userId');
        return false;
      }
    } catch (error, stackTrace) {
      _logger.error('Error showing optimal ad', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Presents optimal purchase offer based on user behavior
  Future<OfferPresentation?> presentOptimalPurchaseOffer({
    required String userId,
    required GameContext gameContext,
    required UserBehaviorData behaviorData,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Detect purchase intent
      final intent = await _pricingSystem.detectPurchaseIntent(userId, behaviorData);
      
      if (intent.intentLevel == IntentLevel.none || intent.confidence < 0.3) {
        _logger.debug('Purchase intent too low for user $userId');
        return null;
      }

      // Present optimal offer
      final presentation = await _pricingSystem.presentOptimalOffer(userId, gameContext);
      
      if (presentation != null) {
        _logger.info('Presenting purchase offer to user $userId: ${presentation.primaryOffer.title}');
      }

      return presentation;
    } catch (error, stackTrace) {
      _logger.error('Error presenting optimal purchase offer', 
          error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Presents VIP subscription offer
  Future<SubscriptionOffer?> presentVIPOffer({
    required String userId,
    double? customDiscount,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final offer = await _pricingSystem.createVIPPassOffer(
        userId,
        discountPercentage: customDiscount,
      );

      _logger.info('Created VIP offer for user $userId: '
          '${offer.monthlyPrice} ${offer.currency} (${offer.discountPercentage}% off)');

      return offer;
    } catch (error, stackTrace) {
      _logger.error('Error presenting VIP offer', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// Processes purchase through billing system
  Future<bool> processPurchase({
    required String userId,
    required String productId,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      _logger.info('Processing purchase for user $userId: $productId');

      final success = await _billingSystem.purchaseProduct(productId, userId);
      
      if (success) {
        _logger.info('Purchase initiated successfully for user $userId: $productId');
      } else {
        _logger.warn('Failed to initiate purchase for user $userId: $productId');
      }

      return success;
    } catch (error, stackTrace) {
      _logger.error('Error processing purchase', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Processes subscription purchase
  Future<bool> processSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      _logger.info('Processing subscription for user $userId: $subscriptionId');

      final success = await _billingSystem.purchaseSubscription(subscriptionId, userId);
      
      if (success) {
        _logger.info('Subscription initiated successfully for user $userId: $subscriptionId');
      } else {
        _logger.warn('Failed to initiate subscription for user $userId: $subscriptionId');
      }

      return success;
    } catch (error, stackTrace) {
      _logger.error('Error processing subscription', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets comprehensive monetization status for user
  Future<MonetizationStatus> getMonetizationStatus(String userId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final monetizationData = await _storageService.getMonetizationData(userId);
      final hasVIP = await _billingSystem.hasVIPStatus(userId);
      final currencyBalance = await _billingSystem.getPremiumCurrencyBalance(userId);
      final sessionAdCount = _adExperienceManager.getSessionAdCount(userId);

      return MonetizationStatus(
        userId: userId,
        hasVIPStatus: hasVIP,
        adFatigueLevel: monetizationData?.adInteractionHistory.fatigueLevel ?? AdFatigueLevel.none,
        lifetimeValue: monetizationData?.lifetimeValue ?? 0.0,
        sessionAdCount: sessionAdCount,
        premiumCurrencyBalance: currencyBalance,
        lastUpdated: DateTime.now(),
      );
    } catch (error, stackTrace) {
      _logger.error('Error getting monetization status', 
          error: error, stackTrace: stackTrace);
      
      return MonetizationStatus(
        userId: userId,
        hasVIPStatus: false,
        adFatigueLevel: AdFatigueLevel.none,
        lifetimeValue: 0.0,
        sessionAdCount: 0,
        premiumCurrencyBalance: const PremiumCurrencyBalance(coins: 0, gems: 0, lastUpdated: null),
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Resets session tracking (call when new session starts)
  void resetSessionTracking(String userId) {
    _adExperienceManager.resetSessionTracking(userId);
    _logger.debug('Reset session tracking for user $userId');
  }

  /// Sets user region for ad optimization
  void setUserRegion(String region) {
    _multiNetworkAdSystem.setRegion(region);
    _logger.info('Set user region to: $region');
  }

  /// Gets performance analytics
  Map<String, dynamic> getPerformanceAnalytics() {
    return {
      'adNetworkPerformance': _multiNetworkAdSystem.getPerformanceReport(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      await _billingSystem.restorePurchases();
      _logger.info('Restored purchases');
    } catch (error, stackTrace) {
      _logger.error('Error restoring purchases', error: error, stackTrace: stackTrace);
    }
  }

  void _initializeComponents() {
    _storageService = MonetizationStorageService(logger: _logger);
    _orchestrator = MonetizationOrchestrator(
      storageService: _storageService,
      logger: _logger,
    );
    _adExperienceManager = ad_experience_manager.AdExperienceManager(
      storageService: _storageService,
      logger: _logger,
    );
    _pricingSystem = TieredPricingSystem(
      storageService: _storageService,
      logger: _logger,
    );
    _billingSystem = BillingSystem(
      storageService: _storageService,
      logger: _logger,
    );
    _multiNetworkAdSystem = MultiNetworkAdSystem(logger: _logger);
  }

  /// Disposes all resources
  void dispose() {
    _billingSystem.dispose();
    _multiNetworkAdSystem.dispose();
    _logger.info('Disposed monetization integration system');
  }
}

/// Comprehensive monetization status
class MonetizationStatus {
  const MonetizationStatus({
    required this.userId,
    required this.hasVIPStatus,
    required this.adFatigueLevel,
    required this.lifetimeValue,
    required this.sessionAdCount,
    required this.premiumCurrencyBalance,
    required this.lastUpdated,
  });

  final String userId;
  final bool hasVIPStatus;
  final AdFatigueLevel adFatigueLevel;
  final double lifetimeValue;
  final int sessionAdCount;
  final PremiumCurrencyBalance premiumCurrencyBalance;
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'hasVIPStatus': hasVIPStatus,
      'adFatigueLevel': adFatigueLevel.name,
      'lifetimeValue': lifetimeValue,
      'sessionAdCount': sessionAdCount,
      'premiumCurrencyBalance': premiumCurrencyBalance.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  static MonetizationStatus fromJson(Map<String, dynamic> json) {
    return MonetizationStatus(
      userId: json['userId'] as String,
      hasVIPStatus: json['hasVIPStatus'] as bool,
      adFatigueLevel: AdFatigueLevel.values.firstWhere(
        (e) => e.name == json['adFatigueLevel'],
        orElse: () => AdFatigueLevel.none,
      ),
      lifetimeValue: (json['lifetimeValue'] as num).toDouble(),
      sessionAdCount: json['sessionAdCount'] as int,
      premiumCurrencyBalance: PremiumCurrencyBalance.fromJson(
        json['premiumCurrencyBalance'] as Map<String, dynamic>,
      ),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}