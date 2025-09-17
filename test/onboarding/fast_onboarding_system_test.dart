import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:advertisement_game/onboarding/fast_onboarding_system.dart';
import 'package:advertisement_game/onboarding/models/onboarding_models.dart';
import 'package:advertisement_game/core/analytics/analytics_service.dart';

@GenerateMocks([AnalyticsService])
import 'fast_onboarding_system_test.mocks.dart';

void main() {
  group('FastOnboardingSystem', () {
    late FastOnboardingSystem onboardingSystem;
    late MockAnalyticsService mockAnalytics;

    setUp(() {
      mockAnalytics = MockAnalyticsService();
      onboardingSystem = FastOnboardingSystem(analytics: mockAnalytics);
    });

    tearDown(() {
      onboardingSystem.dispose();
    });

    group('initialization', () {
      test('should start in not started state', () {
        expect(onboardingSystem.state, OnboardingState.notStarted);
        expect(onboardingSystem.isActive, false);
        expect(onboardingSystem.isCompleted, false);
      });
    });

    group('startOnboarding', () {
      test('should start onboarding with tutorial state', () async {
        await onboardingSystem.startOnboarding();

        expect(onboardingSystem.state, OnboardingState.tutorial);
        expect(onboardingSystem.isActive, true);
        expect(onboardingSystem.progress, isNotNull);
        expect(onboardingSystem.progress!.currentStep, TutorialStep.welcome);
        
        verify(mockAnalytics.trackEvent('onboarding_started')).called(1);
      });

      test('should skip onboarding if user preferences indicate skip', () async {
        const preferences = OnboardingPreferences(skipTutorial: true);
        
        await onboardingSystem.startOnboarding(userPreferences: preferences);

        expect(onboardingSystem.state, OnboardingState.skipped);
        expect(onboardingSystem.isActive, false);
      });

      test('should not start if already started', () async {
        await onboardingSystem.startOnboarding();
        final firstProgress = onboardingSystem.progress;

        await onboardingSystem.startOnboarding();
        
        expect(onboardingSystem.progress, equals(firstProgress));
      });
    });

    group('recordInteraction', () {
      setUp(() async {
        await onboardingSystem.startOnboarding();
      });

      test('should record successful interaction and advance step', () {
        onboardingSystem.recordInteraction('jump', success: true);

        expect(onboardingSystem.progress!.interactions.length, 1);
        expect(onboardingSystem.progress!.interactions.first.action, 'jump');
        expect(onboardingSystem.progress!.interactions.first.success, true);
      });

      test('should record failed interaction without advancing', () {
        final initialStep = onboardingSystem.progress!.currentStep;
        
        onboardingSystem.recordInteraction('jump', success: false);

        expect(onboardingSystem.progress!.currentStep, initialStep);
        expect(onboardingSystem.progress!.interactions.length, 1);
        expect(onboardingSystem.progress!.interactions.first.success, false);
      });
    });

    group('tutorial messages', () {
      setUp(() async {
        await onboardingSystem.startOnboarding();
      });

      test('should provide appropriate message for current step', () {
        expect(onboardingSystem.getTutorialMessage(), 'Welcome to Quick Draw Dash!');
        
        // Advance to next step
        onboardingSystem.recordInteraction('advance', success: true);
        expect(onboardingSystem.getTutorialMessage(), 'Tap to jump over obstacles!');
      });

      test('should provide hint when help is needed', () {
        // Simulate needing help
        onboardingSystem.progress = onboardingSystem.progress!.copyWith(needsHelp: true);
        
        expect(onboardingSystem.getTutorialHint(), isNotEmpty);
      });
    });

    group('skipOnboarding', () {
      test('should skip active onboarding', () async {
        await onboardingSystem.startOnboarding();
        
        await onboardingSystem.skipOnboarding();

        expect(onboardingSystem.state, OnboardingState.skipped);
        verify(mockAnalytics.trackEvent('onboarding_skipped', parameters: anyNamed('parameters'))).called(1);
      });

      test('should not skip if not in tutorial state', () async {
        await onboardingSystem.skipOnboarding();

        expect(onboardingSystem.state, OnboardingState.notStarted);
        verifyNever(mockAnalytics.trackEvent('onboarding_skipped', parameters: anyNamed('parameters')));
      });
    });

    group('fast tracking', () {
      setUp(() async {
        await onboardingSystem.startOnboarding();
      });

      test('should suggest fast tracking after 12 seconds', () {
        // Simulate time passage by creating progress with old start time
        final oldStartTime = DateTime.now().subtract(const Duration(seconds: 13));
        onboardingSystem.progress = onboardingSystem.progress!.copyWith(startTime: oldStartTime);

        expect(onboardingSystem.shouldFastTrack(), true);
      });

      test('should not suggest fast tracking before 12 seconds', () {
        expect(onboardingSystem.shouldFastTrack(), false);
      });
    });

    group('completion', () {
      setUp(() async {
        await onboardingSystem.startOnboarding();
      });

      test('should complete onboarding after all steps', () async {
        // Complete all tutorial steps
        final steps = [
          TutorialStep.welcome,
          TutorialStep.tapToJump,
          TutorialStep.drawPlatform,
          TutorialStep.collectCoin,
          TutorialStep.avoidObstacle,
        ];

        for (final step in steps) {
          onboardingSystem.recordInteraction('test', success: true);
          await Future.delayed(const Duration(milliseconds: 10));
        }

        expect(onboardingSystem.state, OnboardingState.completed);
        expect(onboardingSystem.isCompleted, true);
        verify(mockAnalytics.trackEvent('onboarding_completed', parameters: anyNamed('parameters'))).called(1);
      });
    });

    group('preferences', () {
      test('should update preferences', () {
        const newPreferences = OnboardingPreferences(
          hapticFeedback: false,
          autoHelp: false,
        );

        onboardingSystem.updatePreferences(newPreferences);

        expect(onboardingSystem.preferences, newPreferences);
      });
    });
  });
}