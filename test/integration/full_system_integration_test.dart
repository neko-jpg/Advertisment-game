import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../lib/app/bootstrap.dart';
import '../../lib/app/app.dart';
import '../../lib/app/di/injector.dart';
import '../../lib/core/analytics/analytics_service.dart';
import '../../lib/core/analytics/retention_manager.dart';
import '../../lib/core/analytics/player_behavior_analyzer.dart';
import '../../lib/monetization/monetization_orchestrator.dart';
import '../../lib/monetization/ad_experience_manager.dart';
import '../../lib/game/engine/difficulty_adjustment_engine.dart';
import '../../lib/game/content/content_variation_engine.dart';
import '../../lib/social/social_system.dart';
import '../../lib/onboarding/onboarding_manager.dart';
import '../../lib/core/kpi/kpi_monitoring_system.dart';
import '../../lib/core/competitive/competitive_advantage_system.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full System Integration Tests', () {
    setUpAll(() async {
      // Initialize the app with test configuration
      await bootstrap();
    });

    tearDownAll(() async {
      // Clean up after all tests
      await serviceLocator.reset();
    });

    testWidgets('App launches and initializes all core systems', (tester) async {
      // Test app launch
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      // Verify main screen is displayed
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Verify core services are initialized
      expect(serviceLocator.isRegistered<AnalyticsService>(), isTrue);
      expect(serviceLocator.isRegistered<RetentionManager>(), isTrue);
      expect(serviceLocator.isRegistered<MonetizationOrchestrator>(), isTrue);
      expect(serviceLocator.isRegistered<DifficultyAdjustmentEngine>(), isTrue);
    });

    testWidgets('Analytics and behavior tracking integration', (tester) async {
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      final analytics = serviceLocator<AnalyticsService>();
      final behaviorAnalyzer = serviceLocator<PlayerBehaviorAnalyzer>();
      final retentionManager = serviceLocator<RetentionManager>();

      // Test analytics event tracking
      await analytics.trackEvent('test_event', {'test_param': 'test_value'});
      
      // Test behavior analysis
      final behaviorData = await behaviorAnalyzer.analyzeBehaviorPattern('test_user');
      expect(behaviorData, isNotNull);

      // Test retention system
      final churnRisk = await retentionManager.detectChurnRisk(behaviorData);
      expect(churnRisk, isA<bool>());
    });

    testWidgets('Monetization system integration', (tester) async {
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      final monetizationOrchestrator = serviceLocator<MonetizationOrchestrator>();
      final adExperienceManager = serviceLocator<AdExperienceManager>();

      // Test monetization orchestration
      final shouldShowAd = await monetizationOrchestrator.shouldShowValuePropositionAd(
        MockGameContext(),
      );
      expect(shouldShowAd, isA<bool>());

      // Test ad experience management
      final isNaturalMoment = adExperienceManager.isNaturalAdMoment(
        MockGameState(),
        MockUserSession(),
      );
      expect(isNaturalMoment, isA<bool>());
    });

    testWidgets('Game engine and difficulty adjustment integration', (tester) async {
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      final difficultyEngine = serviceLocator<DifficultyAdjustmentEngine>();

      // Test difficulty adjustment
      final multiplier = difficultyEngine.calculateDifficultyMultiplier(3);
      expect(multiplier, lessThan(1.0)); // Should reduce difficulty after failures

      // Test skill assessment
      final skillLevel = difficultyEngine.assessPlayerSkill([]);
      expect(skillLevel, isNotNull);
    });

    testWidgets('Content variation and social systems integration', (tester) async {
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      final contentEngine = serviceLocator<ContentVariationEngine>();
      final socialSystem = serviceLocator<SocialSystem>();

      // Test content variation
      final theme = await contentEngine.selectOptimalTheme(MockUserPreferences());
      expect(theme, isNotNull);

      // Test social features
      final leaderboard = await socialSystem.getLeaderboard('global');
      expect(leaderboard, isNotNull);
    });

    testWidgets('Onboarding system integration', (tester) async {
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      final onboardingManager = serviceLocator<OnboardingManager>();

      // Test onboarding flow
      final shouldShowOnboarding = await onboardingManager.shouldShowOnboarding('new_user');
      expect(shouldShowOnboarding, isTrue);

      // Test tutorial completion
      await onboardingManager.completeTutorialStep('basic_controls');
      final progress = await onboardingManager.getOnboardingProgress('new_user');
      expect(progress.completedSteps, contains('basic_controls'));
    });

    testWidgets('KPI monitoring and competitive analysis integration', (tester) async {
      await tester.pumpWidget(const QuickDrawDashApp());
      await tester.pumpAndSettle();

      final kpiSystem = serviceLocator<KPIMonitoringSystem>();
      final competitiveSystem = serviceLocator<CompetitiveAdvantageSystem>();

      // Test KPI monitoring
      final kpiData = await kpiSystem.getCurrentKPIs();
      expect(kpiData, isNotNull);

      // Test competitive analysis
      final competitiveData = await competitiveSystem.analyzeCompetitivePosition();
      expect(competitiveData, isNotNull);
    });
  });
}

// Mock classes for testing
class MockGameContext {
  final String gameMode = 'normal';
  final int currentScore = 100;
  final Duration sessionTime = Duration(minutes: 5);
}

class MockGameState {
  final bool isGameOver = false;
  final int currentLevel = 1;
  final double playerProgress = 0.5;
}

class MockUserSession {
  final DateTime startTime = DateTime.now();
  final int adViewCount = 2;
  final Duration totalPlayTime = Duration(minutes: 10);
}

class MockUserPreferences {
  final String preferredTheme = 'neon';
  final bool soundEnabled = true;
  final double difficultyPreference = 0.7;
}