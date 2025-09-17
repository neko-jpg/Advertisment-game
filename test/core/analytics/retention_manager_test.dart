import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/core/analytics/models/behavior_models.dart';
import '../../../lib/core/analytics/player_behavior_analyzer.dart';
import '../../../lib/core/analytics/retention_manager.dart';

void main() {
  group('RetentionManager', () {
    late RetentionManager retentionManager;
    late PlayerBehaviorAnalyzer behaviorAnalyzer;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      behaviorAnalyzer = PlayerBehaviorAnalyzer(prefs: prefs);
      retentionManager = RetentionManager(
        behaviorAnalyzer: behaviorAnalyzer,
        prefs: prefs,
      );
    });

    group('Churn Risk Detection', () {
      test('should detect high churn risk for inactive user', () async {
        const userId = 'inactive_user';
        
        final behaviorData = UserBehaviorData(
          userId: userId,
          sessions: [
            UserSession(
              sessionId: 'old_session',
              userId: userId,
              startTime: DateTime.now().subtract(const Duration(days: 10)),
              endTime: DateTime.now().subtract(const Duration(days: 10, minutes: -5)),
              actions: [],
              deviceInfo: const DeviceInfo(
                platform: 'android',
                osVersion: 'Android 13',
                appVersion: '1.0.0',
                screenSize: '1080x2400',
                locale: 'en_US',
              ),
            ),
          ],
          totalPlayTime: const Duration(minutes: 5),
          averageScore: 100.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: DateTime.now().subtract(const Duration(days: 10)),
        );

        // Save behavior data so it can be analyzed
        await prefs.setString(
          'behavior_data_$userId',
          jsonEncode(behaviorData.toJson()),
        );

        final isAtRisk = await retentionManager.detectChurnRisk(behaviorData);
        expect(isAtRisk, isTrue);
      });

      test('should not detect churn risk for active user', () async {
        const userId = 'active_user';
        
        final behaviorData = UserBehaviorData(
          userId: userId,
          sessions: [
            UserSession(
              sessionId: 'recent_session',
              userId: userId,
              startTime: DateTime.now().subtract(const Duration(hours: 2)),
              endTime: DateTime.now().subtract(const Duration(hours: 2, minutes: -10)),
              actions: [
                GameAction(
                  type: GameActionType.gameStart,
                  timestamp: DateTime.now().subtract(const Duration(hours: 2)),
                  sessionId: 'recent_session',
                ),
                GameAction(
                  type: GameActionType.tutorialStep,
                  timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: -5)),
                  sessionId: 'recent_session',
                ),
              ],
              deviceInfo: const DeviceInfo(
                platform: 'android',
                osVersion: 'Android 13',
                appVersion: '1.0.0',
                screenSize: '1080x2400',
                locale: 'en_US',
              ),
            ),
          ],
          totalPlayTime: const Duration(minutes: 30),
          averageScore: 500.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: DateTime.now().subtract(const Duration(hours: 2)),
        );

        // Save behavior data so it can be analyzed
        await prefs.setString(
          'behavior_data_$userId',
          jsonEncode(behaviorData.toJson()),
        );

        final isAtRisk = await retentionManager.detectChurnRisk(behaviorData);
        expect(isAtRisk, isFalse);
      });
    });

    group('Difficulty Adjustment', () {
      test('should adjust difficulty for poor performance', () {
        const userId = 'struggling_user';
        
        final session = UserSession(
          sessionId: 'poor_session',
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(minutes: 5)),
          endTime: DateTime.now(),
          actions: [
            GameAction(
              type: GameActionType.gameStart,
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              sessionId: 'poor_session',
            ),
            GameAction(
              type: GameActionType.gameEnd,
              timestamp: DateTime.now(),
              sessionId: 'poor_session',
              metadata: {
                'score': 50,
                'accident_death': true,
              },
            ),
          ],
          deviceInfo: const DeviceInfo(
            platform: 'android',
            osVersion: 'Android 13',
            appVersion: '1.0.0',
            screenSize: '1080x2400',
            locale: 'en_US',
          ),
        );

        // Set up consecutive failures
        prefs.setInt('recent_failures_$userId', 3);

        // Get initial difficulty
        final initialSpeed = prefs.getDouble('difficulty_speed_$userId') ?? 1.0;

        // Adjust difficulty
        retentionManager.adjustDifficultyBasedOnPerformance(session);

        // Check if difficulty was reduced
        final newSpeed = prefs.getDouble('difficulty_speed_$userId') ?? 1.0;
        expect(newSpeed, lessThan(initialSpeed));
      });

      test('should increase difficulty for good performance', () {
        const userId = 'skilled_user';
        
        final session = UserSession(
          sessionId: 'good_session',
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(minutes: 10)),
          endTime: DateTime.now(),
          actions: [
            GameAction(
              type: GameActionType.gameStart,
              timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
              sessionId: 'good_session',
            ),
            GameAction(
              type: GameActionType.gameEnd,
              timestamp: DateTime.now(),
              sessionId: 'good_session',
              metadata: {
                'score': 1000,
                'accident_death': false,
              },
            ),
          ],
          deviceInfo: const DeviceInfo(
            platform: 'android',
            osVersion: 'Android 13',
            appVersion: '1.0.0',
            screenSize: '1080x2400',
            locale: 'en_US',
          ),
        );

        // Set up good recent scores to simulate improvement
        prefs.setString('recent_scores_$userId', '800,900,950,1000');
        prefs.setInt('recent_failures_$userId', 0);

        // Get initial difficulty
        final initialSpeed = prefs.getDouble('difficulty_speed_$userId') ?? 1.0;

        // Adjust difficulty
        retentionManager.adjustDifficultyBasedOnPerformance(session);

        // Check if difficulty was increased (or stayed same if already at max)
        final newSpeed = prefs.getDouble('difficulty_speed_$userId') ?? 1.0;
        expect(newSpeed, greaterThanOrEqualTo(initialSpeed));
      });
    });

    group('Surprise Rewards', () {
      test('should generate appropriate reward for consistent player', () async {
        const userId = 'consistent_user';
        
        // Create behavior data that shows high consistency
        final behaviorData = UserBehaviorData(
          userId: userId,
          sessions: List.generate(10, (index) => UserSession(
            sessionId: 'session_$index',
            userId: userId,
            startTime: DateTime.now().subtract(Duration(days: index)),
            endTime: DateTime.now().subtract(Duration(days: index, minutes: -10)),
            actions: [
              GameAction(
                type: GameActionType.gameStart,
                timestamp: DateTime.now().subtract(Duration(days: index)),
                sessionId: 'session_$index',
              ),
            ],
            deviceInfo: const DeviceInfo(
              platform: 'android',
              osVersion: 'Android 13',
              appVersion: '1.0.0',
              screenSize: '1080x2400',
              locale: 'en_US',
            ),
          )),
          totalPlayTime: const Duration(hours: 10),
          averageScore: 500.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: DateTime.now(),
        );

        // Save behavior data
        await prefs.setString(
          'behavior_data_$userId',
          jsonEncode(behaviorData.toJson()),
        );
        
        final userProfile = UserProfile(
          userId: userId,
          firstPlayDate: DateTime.now().subtract(const Duration(days: 30)),
          totalPlayTime: const Duration(hours: 10),
          skillLevel: SkillLevel.intermediate,
          achievements: [
            Achievement(
              id: 'consistency',
              name: 'Consistent Player',
              unlockedAt: DateTime.now().subtract(const Duration(days: 5)),
            ),
          ],
          spendingProfile: const SpendingProfile(
            totalSpent: 5.0,
            averageTransactionValue: 2.5,
          ),
          behaviorMetrics: const BehaviorMetrics(
            averageSessionLength: Duration(minutes: 8),
            dailyPlayFrequency: 2.5,
          ),
          retentionRisk: const RetentionRisk(
            level: ChurnRiskLevel.low,
            factors: [],
          ),
        );

        final reward = await retentionManager.generateSurpriseReward(userProfile);

        expect(reward.coins, greaterThan(100)); // Should get bonus for consistency
        expect(reward.message, contains('consistency'));
        expect(reward.type, equals(RewardType.surprise));
      });

      test('should generate default reward on error', () async {
        const userId = 'error_user';
        
        final userProfile = UserProfile(
          userId: userId,
          firstPlayDate: DateTime.now(),
          totalPlayTime: Duration.zero,
          skillLevel: SkillLevel.beginner,
          achievements: [],
          spendingProfile: const SpendingProfile(
            totalSpent: 0.0,
            averageTransactionValue: 0.0,
          ),
          behaviorMetrics: const BehaviorMetrics(
            averageSessionLength: Duration.zero,
            dailyPlayFrequency: 0.0,
          ),
          retentionRisk: const RetentionRisk(
            level: ChurnRiskLevel.low,
            factors: [],
          ),
        );

        final reward = await retentionManager.generateSurpriseReward(userProfile);

        expect(reward.coins, equals(100)); // Default reward
        expect(reward.type, equals(RewardType.surprise));
        expect(reward.message, isNotEmpty);
      });
    });

    group('Personalized Retention', () {
      test('should skip intervention if too recent', () async {
        const userId = 'recent_intervention_user';
        
        // Set recent intervention
        await prefs.setString(
          'last_intervention_$userId',
          DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
        );

        final churnRisk = ChurnRisk(
          riskLevel: ChurnRiskLevel.high,
          probability: 0.8,
          primaryFactors: ['long_absence'],
          recommendedActions: ['send_comeback_notification'],
        );

        // Should not execute intervention
        await retentionManager.executePersonalizedRetention(userId, churnRisk);

        // Verify no new intervention was recorded
        final lastIntervention = prefs.getString('last_intervention_$userId');
        final lastInterventionTime = DateTime.parse(lastIntervention!);
        expect(DateTime.now().difference(lastInterventionTime).inHours, greaterThan(10));
      });

      test('should execute intervention for high risk user', () async {
        const userId = 'high_risk_user';
        
        final churnRisk = ChurnRisk(
          riskLevel: ChurnRiskLevel.high,
          probability: 0.8,
          primaryFactors: ['long_absence', 'slow_progression'],
          recommendedActions: ['send_comeback_notification', 'adjust_difficulty'],
        );

        await retentionManager.executePersonalizedRetention(userId, churnRisk);

        // Verify intervention was recorded
        final lastIntervention = prefs.getString('last_intervention_$userId');
        expect(lastIntervention, isNotNull);
        
        final retentionActions = prefs.getString('retention_actions_$userId');
        expect(retentionActions, isNotNull);
        expect(retentionActions, contains('comebackNotification'));
      });
    });

    group('Difficulty Settings', () {
      test('should clamp difficulty values within valid ranges', () {
        const userId = 'test_user';
        
        // Set extreme values
        prefs.setDouble('difficulty_speed_$userId', 10.0); // Too high
        prefs.setDouble('difficulty_density_$userId', -1.0); // Too low
        prefs.setDouble('difficulty_safe_window_$userId', 500.0); // Too high

        final session = UserSession(
          sessionId: 'test_session',
          userId: userId,
          startTime: DateTime.now().subtract(const Duration(minutes: 5)),
          endTime: DateTime.now(),
          actions: [
            GameAction(
              type: GameActionType.gameEnd,
              timestamp: DateTime.now(),
              sessionId: 'test_session',
              metadata: {'score': 100, 'accident_death': true},
            ),
          ],
          deviceInfo: const DeviceInfo(
            platform: 'android',
            osVersion: 'Android 13',
            appVersion: '1.0.0',
            screenSize: '1080x2400',
            locale: 'en_US',
          ),
        );

        retentionManager.adjustDifficultyBasedOnPerformance(session);

        // Check values are clamped
        final speed = prefs.getDouble('difficulty_speed_$userId')!;
        final density = prefs.getDouble('difficulty_density_$userId')!;
        final safeWindow = prefs.getDouble('difficulty_safe_window_$userId')!;

        expect(speed, inInclusiveRange(0.5, 2.0));
        expect(density, inInclusiveRange(0.3, 2.5));
        expect(safeWindow, inInclusiveRange(120.0, 300.0));
      });
    });
  });
}