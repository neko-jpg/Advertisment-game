import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/logging/logger.dart';
import '../../lib/monetization/models/monetization_models.dart';
import '../../lib/monetization/monetization_orchestrator.dart';
import '../../lib/monetization/services/monetization_storage_service.dart';

// Simple mock logger for testing
class SimpleLogger implements AppLogger {
  @override
  void debug(String message) => print('DEBUG: $message');

  @override
  void info(String message) => print('INFO: $message');

  @override
  void warn(String message, {Object? error}) => print('WARN: $message');

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) => 
      print('ERROR: $message');
}

void main() {
  group('Monetization System Tests', () {
    late MonetizationOrchestrator orchestrator;
    late MonetizationStorageService storageService;
    late SimpleLogger logger;

    setUp(() {
      logger = SimpleLogger();
      storageService = MonetizationStorageService(logger: logger);
      orchestrator = MonetizationOrchestrator(
        storageService: storageService,
        logger: logger,
      );
    });

    test('should generate tiered offers', () {
      // Arrange
      final spendingProfile = SpendingProfile(
        userId: 'test_user',
        totalSpent: 500.0,
        averageTransactionValue: 250.0,
        purchaseFrequency: 2.0,
        preferredPriceRange: PriceRange.medium,
        lastPurchaseDate: DateTime.now().subtract(const Duration(days: 10)),
        conversionRate: 0.8,
      );

      // Act
      final offers = orchestrator.generateTieredOffers(spendingProfile);

      // Assert
      expect(offers, isNotEmpty);
      expect(offers.length, equals(4)); // 4 tiers as specified
      
      // Offers are sorted by recommendation score, so order may vary
      final prices = offers.map((o) => o.price).toSet();
      expect(prices, contains(120.0));
      expect(prices, contains(250.0));
      expect(prices, contains(480.0));
      expect(prices, contains(980.0));
    });

    test('should detect ad fatigue levels', () {
      // Arrange
      final adHistory = AdInteractionHistory(
        userId: 'test_user',
        totalAdsViewed: 25,
        adsViewedToday: 15,
        lastAdViewTime: DateTime.now().subtract(const Duration(minutes: 5)),
        averageViewDuration: const Duration(seconds: 20),
        skipRate: 0.7,
        rewardedAdEngagement: 0.3,
        interstitialTolerance: 0.2,
      );

      // Act & Assert
      expect(adHistory.fatigueLevel, equals(AdFatigueLevel.high));
    });

    test('should create monetization data', () {
      // Arrange
      final adHistory = AdInteractionHistory(
        userId: 'test_user',
        totalAdsViewed: 10,
        adsViewedToday: 3,
        lastAdViewTime: DateTime.now(),
        averageViewDuration: const Duration(seconds: 30),
        skipRate: 0.2,
        rewardedAdEngagement: 0.8,
        interstitialTolerance: 0.6,
      );

      final spendingProfile = SpendingProfile(
        userId: 'test_user',
        totalSpent: 250.0,
        averageTransactionValue: 125.0,
        purchaseFrequency: 1.0,
        preferredPriceRange: PriceRange.low,
        lastPurchaseDate: DateTime.now(),
        conversionRate: 0.5,
      );

      final subscriptionStatus = SubscriptionStatus(
        isActive: false,
        tier: 'none',
        startDate: null,
        expiryDate: null,
        autoRenew: false,
        trialUsed: false,
      );

      // Act
      final monetizationData = MonetizationData(
        userId: 'test_user',
        adInteractionHistory: adHistory,
        spendingProfile: spendingProfile,
        subscriptionStatus: subscriptionStatus,
        lifetimeValue: 250.0,
        lastOfferShown: null,
        offerConversionRate: 0.5,
      );

      // Assert
      expect(monetizationData.userId, equals('test_user'));
      expect(monetizationData.lifetimeValue, equals(250.0));
      expect(monetizationData.adInteractionHistory.fatigueLevel, equals(AdFatigueLevel.none));
    });
  });
}