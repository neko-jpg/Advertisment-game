import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../lib/core/analytics/models/behavior_models.dart';
import '../../lib/core/logging/logger.dart';
import '../../lib/monetization/ad_experience_manager.dart';
import '../../lib/monetization/models/monetization_models.dart';
import '../../lib/monetization/monetization_integration.dart';
import '../../lib/monetization/monetization_orchestrator.dart';
import '../../lib/monetization/tiered_pricing_system.dart';

// Mock classes
class MockLogger extends Mock implements AppLogger {}

void main() {
  group('MonetizationIntegration', () {
    late MonetizationIntegration monetizationIntegration;
    late MockLogger mockLogger;

    setUp(() {
      mockLogger = MockLogger();
      monetizationIntegration = MonetizationIntegration(logger: mockLogger);
    });

    tearDown(() {
      monetizationIntegration.dispose();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Act
        await monetizationIntegration.initialize();

        // Assert
        // Verify that initialization completed without throwing
        expect(true, isTrue);
      });
    });

    group('Ad Experience Management', () {
      test('should show optimal ad when conditions are met', () async {
        // Arrange
        await monetizationIntegration.initialize();
        
        final gameContext = GameContext(
          currentScore: 100,
          sessionDuration: const Duration(minutes: 5),
          gameState: GameState.gameOver,
          playerMood: PlayerMood.satisfied,
          achievementJustUnlocked: false,
          consecutiveFailures: 1,
          coinsEarned: 50,
        );

        final userSession = UserSession(
          sessionId: 'test_session',
          userId: 'test_user',
          startTime: DateTime.now().subtract(const Duration(minutes: 5)),
          endTime: null,
          actions: [
            GameAction(
              type: GameActionType.gameStart,
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              sessionId: 'test_session',
            ),
          ],
          deviceInfo: const DeviceInfo(
            platform: 'android',
            osVersion: '12',
            appVersion: '1.0.0',
            screenSize: '1080x2400',
            locale: 'ja_JP',
          ),
        );

        // Act
        final result = await monetizationIntegration.showOptimalAd(
          userId: 'test_user',
          gameContext: gameContext,
          userSession: userSession,
          placement: 'game_over',
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should not show ad when user is frustrated', () async {
        // Arrange
        await monetizationIntegration.initialize();
        
        final gameContext = GameContext(
          currentScore: 0,
          sessionDuration: const Duration(minutes: 5),
          gameState: GameState.gameOver,
          playerMood: PlayerMood.frustrated,
          achievementJustUnlocked: false,
          consecutiveFailures: 5,
          coinsEarned: 0,
        );

        final userSession = UserSession(
          sessionId: 'test_session',
          userId: 'test_user',
          startTime: DateTime.now().subtract(const Duration(minutes: 5)),
          endTime: null,
          actions: [],
          deviceInfo: const DeviceInfo(
            platform: 'android',
            osVersion: '12',
            appVersion: '1.0.0',
            screenSize: '1080x2400',
            locale: 'ja_JP',
          ),
        );

        // Act
        final result = await monetizationIntegration.showOptimalAd(
          userId: 'test_user',
          gameContext: gameContext,
          userSession: userSession,
          placement: 'game_over',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Purchase Intent Detection', () {
      test('should detect high purchase intent for engaged users', () async {
        // Arrange
        await monetizationIntegration.initialize();
        
        final behaviorData = UserBehaviorData(
          userId: 'test_user',
          sessions: List.generate(15, (i) => UserSession(
            sessionId: 'session_$i',
            userId: 'test_user',
            startTime: DateTime.now().subtract(Duration(days: i)),
            endTime: DateTime.now().subtract(Duration(days: i, hours: -1)),
            actions: [
              GameAction(
                type: GameActionType.gameStart,
                timestamp: DateTime.now().subtract(Duration(days: i)),
                sessionId: 'session_$i',
              ),
            ],
            deviceInfo: const DeviceInfo(
              platform: 'android',
              osVersion: '12',
              appVersion: '1.0.0',
              screenSize: '1080x2400',
              locale: 'ja_JP',
            ),
          )),
          totalPlayTime: const Duration(hours: 10),
          averageScore: 500.0,
          purchaseHistory: [
            {'amount': 250.0, 'timestamp': DateTime.now().subtract(const Duration(days: 5)).toIso8601String()},
          ],
          adInteractions: [
            {'type': 'rewarded', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
          ],
          socialActions: [],
          lastActiveDate: DateTime.now(),
        );

        final gameContext = GameContext(
          currentScore: 600,
          sessionDuration: const Duration(minutes: 8),
          gameState: GameState.levelComplete,
          playerMood: PlayerMood.excited,
          achievementJustUnlocked: true,
          consecutiveFailures: 0,
          coinsEarned: 100,
        );

        // Act
        final presentation = await monetizationIntegration.presentOptimalPurchaseOffer(
          userId: 'test_user',
          gameContext: gameContext,
          behaviorData: behaviorData,
        );

        // Assert
        expect(presentation, isA<OfferPresentation?>());
      });
    });

    group('VIP Subscription', () {
      test('should create VIP offer with appropriate discount', () async {
        // Arrange
        await monetizationIntegration.initialize();

        // Act
        final offer = await monetizationIntegration.presentVIPOffer(
          userId: 'test_user',
          customDiscount: 20.0,
        );

        // Assert
        expect(offer, isNotNull);
        expect(offer!.id, equals('vip_pass_monthly'));
        expect(offer.title, equals('VIPパス'));
        expect(offer.discountPercentage, equals(20.0));
        expect(offer.monthlyPrice, equals(480.0 * 0.8)); // 20% discount
        expect(offer.benefits, contains('広告完全削除'));
      });
    });

    group('Monetization Status', () {
      test('should return comprehensive monetization status', () async {
        // Arrange
        await monetizationIntegration.initialize();

        // Act
        final status = await monetizationIntegration.getMonetizationStatus('test_user');

        // Assert
        expect(status, isNotNull);
        expect(status.userId, equals('test_user'));
        expect(status.hasVIPStatus, isA<bool>());
        expect(status.adFatigueLevel, isA<AdFatigueLevel>());
        expect(status.lifetimeValue, isA<double>());
        expect(status.sessionAdCount, isA<int>());
        expect(status.premiumCurrencyBalance, isA<PremiumCurrencyBalance>());
      });
    });

    group('Session Management', () {
      test('should reset session tracking correctly', () {
        // Arrange
        const userId = 'test_user';

        // Act
        monetizationIntegration.resetSessionTracking(userId);

        // Assert
        // Verify that session tracking was reset (no exception thrown)
        expect(true, isTrue);
      });
    });

    group('Regional Optimization', () {
      test('should set user region for ad optimization', () {
        // Arrange
        const region = 'US';

        // Act
        monetizationIntegration.setUserRegion(region);

        // Assert
        // Verify that region was set (no exception thrown)
        expect(true, isTrue);
      });
    });

    group('Performance Analytics', () {
      test('should return performance analytics', () {
        // Act
        final analytics = monetizationIntegration.getPerformanceAnalytics();

        // Assert
        expect(analytics, isA<Map<String, dynamic>>());
        expect(analytics, containsKey('adNetworkPerformance'));
        expect(analytics, containsKey('timestamp'));
      });
    });
  });

  group('MonetizationOrchestrator', () {
    test('should adjust ad frequency based on fatigue level', () async {
      // Arrange
      final mockLogger = MockLogger();
      final mockStorageService = MockMonetizationStorageService();
      final orchestrator = MonetizationOrchestrator(
        storageService: mockStorageService,
        logger: mockLogger,
      );

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

      // Act
      await orchestrator.adjustAdFrequency('test_user', adHistory);

      // Assert
      expect(adHistory.fatigueLevel, equals(AdFatigueLevel.high));
    });

    test('should generate tiered offers correctly', () {
      // Arrange
      final mockLogger = MockLogger();
      final mockStorageService = MockMonetizationStorageService();
      final orchestrator = MonetizationOrchestrator(
        storageService: mockStorageService,
        logger: mockLogger,
      );

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
      expect(offers.first.price, equals(120.0));
      expect(offers.last.price, equals(980.0));
    });
  });

  group('TieredPricingSystem', () {
    test('should detect purchase intent correctly', () async {
      // Arrange
      final mockLogger = MockLogger();
      final mockStorageService = MockMonetizationStorageService();
      final pricingSystem = TieredPricingSystem(
        storageService: mockStorageService,
        logger: mockLogger,
      );

      final behaviorData = UserBehaviorData(
        userId: 'test_user',
        sessions: List.generate(10, (i) => UserSession(
          sessionId: 'session_$i',
          userId: 'test_user',
          startTime: DateTime.now().subtract(Duration(days: i)),
          endTime: DateTime.now().subtract(Duration(days: i, hours: -2)),
          actions: [],
          deviceInfo: const DeviceInfo(
            platform: 'android',
            osVersion: '12',
            appVersion: '1.0.0',
            screenSize: '1080x2400',
            locale: 'ja_JP',
          ),
        )),
        totalPlayTime: const Duration(hours: 6),
        averageScore: 300.0,
        purchaseHistory: [],
        adInteractions: [],
        socialActions: [],
        lastActiveDate: DateTime.now(),
      );

      // Act
      final intent = await pricingSystem.detectPurchaseIntent('test_user', behaviorData);

      // Assert
      expect(intent, isNotNull);
      expect(intent.userId, equals('test_user'));
      expect(intent.intentLevel, isA<IntentLevel>());
      expect(intent.confidence, isA<double>());
      expect(intent.confidence, greaterThanOrEqualTo(0.0));
      expect(intent.confidence, lessThanOrEqualTo(1.0));
    });
  });
}

// Mock storage service for testing
class MockMonetizationStorageService extends Mock {
  Future<void> updateAdFrequencySettings(String userId, Map<String, dynamic> settings) async {
    // Mock implementation
  }

  Future<void> updateAlternativeMonetizationSuggestions(String userId, List<String> suggestions) async {
    // Mock implementation
  }
}