import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:advertisement_game/onboarding/onboarding_manager.dart';
import 'package:advertisement_game/onboarding/models/onboarding_models.dart';
import 'package:advertisement_game/core/analytics/analytics_service.dart';

@GenerateMocks([AnalyticsService])
import 'onboarding_integration_test.mocks.dart';

void main() {
  group('OnboardingManager Integration', () {
    late OnboardingManager onboardingManager;
    late MockAnalyticsService mockAnalytics;

    setUp(() {
      mockAnalytics = MockAnalyticsService();
      onboardingManager = OnboardingManager(analytics: mockAnalytics);
    });

    tearDown(() {
      onboardingManager.dispose();
    });

    group('initialization', () {
      test('should initialize successfully', () async {
        await onboardingManager.initialize();

        expect(onboardingManager.needsOnboarding, true);
        verify(mockAnalytics.trackEvent('onboarding_manager_initialized')).called(1);
      });
    });

    group('complete onboarding flow', () {
      test('should handle complete onboarding experience', () async {
        // Start onboarding
        await onboardingManager.startOnboarding();

        expect(onboardingManager.isOnboardingActive, true);
        verify(mockAnalytics.trackEvent('complete_onboarding_started')).called(1);

        // Simulate user interactions
        onboardingManager.handleUserInteraction(
          action: 'jump',
          successful: true,
          position: const Offset(100, 200),
        );

        onboardingManager.handleUserInteraction(
          action: 'draw',
          successful: true,
          position: const Offset(150, 250),
        );

        // Check that systems are tracking interactions
        expect(onboardingManager.visualGuide.skillProgress.containsKey('jump'), true);
        expect(onboardingManager.visualGuide.skillProgress.containsKey('draw'), true);
      });

      test('should handle first game over correctly', () async {
        await onboardingManager.startOnboarding();

        await onboardingManager.handleGameOver(
          score: 150,
          coinsCollected: 5,
          playTime: const Duration(seconds: 45),
          bestScore: 0,
        );

        expect(onboardingManager.motivation.isFirstGameOver, false);
        expect(onboardingManager.motivation.currentMessage, isNotNull);
        expect(onboardingManager.motivation.currentMessage!.type, MotivationType.encouragement);
      });

      test('should show contextual guides for failed interactions', () async {
        await onboardingManager.startOnboarding();

        onboardingManager.handleUserInteraction(
          action: 'jump',
          successful: false,
          position: const Offset(100, 200),
        );

        // Should trigger visual guide system
        expect(onboardingManager.visualGuide.currentGuide, isNotNull);
      });
    });

    group('progress tracking', () {
      test('should calculate overall progress correctly', () async {
        await onboardingManager.startOnboarding();

        // Simulate some progress
        for (int i = 0; i < 3; i++) {
          onboardingManager.handleUserInteraction(
            action: 'jump',
            successful: true,
          );
        }

        final status = onboardingManager.getOnboardingStatus();
        expect(status['overall_progress'], greaterThan(0.0));
        expect(status['is_active'], true);
      });

      test('should show progress milestones', () async {
        await onboardingManager.startOnboarding();

        // Simulate significant progress to trigger milestone
        for (int i = 0; i < 10; i++) {
          onboardingManager.handleUserInteraction(
            action: 'jump',
            successful: true,
          );
          onboardingManager.handleUserInteraction(
            action: 'draw',
            successful: true,
          );
        }

        // Allow time for milestone checking
        await Future.delayed(const Duration(milliseconds: 100));

        // Should have triggered some achievements
        expect(onboardingManager.visualGuide.achievements.isNotEmpty, true);
      });
    });

    group('motivation system integration', () {
      test('should show login bonus preview', () async {
        await onboardingManager.showLoginBonusPreview(
          tomorrowBonus: 100,
          currentStreak: 2,
        );

        expect(onboardingManager.motivation.currentMessage, isNotNull);
        expect(onboardingManager.motivation.currentMessage!.type, MotivationType.reward);
        verify(mockAnalytics.trackEvent('login_bonus_preview_shown', parameters: anyNamed('parameters'))).called(1);
      });

      test('should show continuous player rewards', () async {
        await onboardingManager.showContinuousPlayerReward(
          daysPlayed: 7,
          bonusCoins: 500,
          specialItem: 'Golden Skin',
        );

        expect(onboardingManager.motivation.currentMessage, isNotNull);
        expect(onboardingManager.motivation.currentMessage!.reward, 500);
        verify(mockAnalytics.trackEvent('continuous_player_reward', parameters: anyNamed('parameters'))).called(1);
      });
    });

    group('skip functionality', () {
      test('should skip entire onboarding process', () async {
        await onboardingManager.startOnboarding();
        
        await onboardingManager.skipOnboarding();

        expect(onboardingManager.isOnboardingActive, false);
        expect(onboardingManager.visualGuide.currentGuide, isNull);
        expect(onboardingManager.motivation.currentMessage, isNull);
        verify(mockAnalytics.trackEvent('complete_onboarding_skipped')).called(1);
      });
    });

    group('reset functionality', () {
      test('should reset all onboarding systems', () async {
        await onboardingManager.startOnboarding();
        
        // Make some progress
        onboardingManager.handleUserInteraction(action: 'jump', successful: true);
        
        onboardingManager.resetOnboarding();

        expect(onboardingManager.needsOnboarding, true);
        expect(onboardingManager.isOnboardingActive, false);
        expect(onboardingManager.visualGuide.skillProgress.isEmpty, true);
        expect(onboardingManager.motivation.gameOverCount, 0);
      });
    });

    group('user help detection', () {
      test('should detect when user needs help', () async {
        await onboardingManager.startOnboarding();

        // Simulate confusion by not interacting for a while
        // This would normally be triggered by timers in the visual guide system
        onboardingManager.visualGuide.recordInteraction('failed_action', successful: false);
        
        // The visual guide system should detect confusion after some time
        // In a real scenario, this would be handled by internal timers
        expect(onboardingManager.userNeedsHelp, false); // Initially false
      });

      test('should provide contextual tutorial messages', () async {
        await onboardingManager.startOnboarding();

        expect(onboardingManager.currentTutorialMessage.isNotEmpty, true);
        expect(onboardingManager.currentTutorialHint.isEmpty, true); // No hint until help is needed
      });
    });

    group('preferences management', () {
      test('should update onboarding preferences', () {
        const preferences = OnboardingPreferences(
          skipTutorial: false,
          hapticFeedback: false,
          autoHelp: true,
        );

        onboardingManager.updatePreferences(preferences);

        expect(onboardingManager.fastOnboarding.preferences, preferences);
      });
    });

    group('comprehensive status', () {
      test('should provide comprehensive onboarding status', () async {
        await onboardingManager.startOnboarding();

        final status = onboardingManager.getOnboardingStatus();

        expect(status['is_initialized'], true);
        expect(status['onboarding_state'], isNotNull);
        expect(status['overall_progress'], isA<double>());
        expect(status['visual_guide_data'], isA<Map>());
        expect(status['motivation_stats'], isA<Map>());
        expect(status['needs_onboarding'], isA<bool>());
        expect(status['is_active'], isA<bool>());
        expect(status['is_completed'], isA<bool>());
      });
    });
  });
}