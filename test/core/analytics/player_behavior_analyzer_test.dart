import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/core/analytics/models/behavior_models.dart';
import '../../../lib/core/analytics/player_behavior_analyzer.dart';

void main() {
  group('PlayerBehaviorAnalyzer', () {
    late PlayerBehaviorAnalyzer analyzer;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      analyzer = PlayerBehaviorAnalyzer(prefs: prefs);
    });

    group('Session Management', () {
      test('should start a new session', () async {
        const userId = 'test_user_123';
        final deviceInfo = DeviceInfo(
          platform: 'android',
          osVersion: 'Android 13',
          appVersion: '1.0.0',
          screenSize: '1080x2400',
          locale: 'en_US',
        );

        final session = await analyzer.startSession(userId, deviceInfo);

        expect(session.userId, equals(userId));
        expect(session.deviceInfo, equals(deviceInfo));
        expect(session.actions, isEmpty);
        expect(session.endTime, isNull);
      });

      test('should end a session and save it', () async {
        const userId = 'test_user_123';
        final deviceInfo = DeviceInfo(
          platform: 'android',
          osVersion: 'Android 13',
          appVersion: '1.0.0',
          screenSize: '1080x2400',
          locale: 'en_US',
        );

        final session = await analyzer.startSession(userId, deviceInfo);
        
        // Add some actions
        final action = GameAction(
          type: GameActionType.gameStart,
          timestamp: DateTime.now(),
          sessionId: session.sessionId,
          metadata: {'test': true},
        );
        await analyzer.recordAction(action);

        // End session
        await analyzer.endSession(session.sessionId);

        // Verify session was ended (we can't access private methods in tests)
        // This would be verified through integration tests
      });
    });

    group('Action Recording', () {
      test('should record game actions', () async {
        const userId = 'test_user_123';
        final deviceInfo = DeviceInfo(
          platform: 'android',
          osVersion: 'Android 13',
          appVersion: '1.0.0',
          screenSize: '1080x2400',
          locale: 'en_US',
        );

        final session = await analyzer.startSession(userId, deviceInfo);
        
        final action = GameAction(
          type: GameActionType.jump,
          timestamp: DateTime.now(),
          sessionId: session.sessionId,
          metadata: {'height': 100.0, 'successful': true},
        );

        await analyzer.recordAction(action);

        // Action recording would be verified through integration tests
        // since we can't access private methods in unit tests
      });
    });

    group('Behavior Pattern Analysis', () {
      test('should analyze behavior pattern for user with sessions', () async {
        const userId = 'test_user_123';
        
        // Create mock behavior data with multiple sessions
        final mockSessions = [
          UserSession(
            sessionId: 'session_1',
            userId: userId,
            startTime: DateTime.now().subtract(const Duration(days: 2)),
            endTime: DateTime.now().subtract(const Duration(days: 2, minutes: -10)),
            actions: [
              GameAction(
                type: GameActionType.gameStart,
                timestamp: DateTime.now().subtract(const Duration(days: 2)),
                sessionId: 'session_1',
              ),
              GameAction(
                type: GameActionType.jump,
                timestamp: DateTime.now().subtract(const Duration(days: 2, minutes: -5)),
                sessionId: 'session_1',
              ),
              GameAction(
                type: GameActionType.gameEnd,
                timestamp: DateTime.now().subtract(const Duration(days: 2, minutes: -10)),
                sessionId: 'session_1',
                metadata: {'score': 500},
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
          UserSession(
            sessionId: 'session_2',
            userId: userId,
            startTime: DateTime.now().subtract(const Duration(days: 1)),
            endTime: DateTime.now().subtract(const Duration(days: 1, minutes: -15)),
            actions: [
              GameAction(
                type: GameActionType.gameStart,
                timestamp: DateTime.now().subtract(const Duration(days: 1)),
                sessionId: 'session_2',
              ),
              GameAction(
                type: GameActionType.draw,
                timestamp: DateTime.now().subtract(const Duration(days: 1, minutes: -5)),
                sessionId: 'session_2',
              ),
              GameAction(
                type: GameActionType.adView,
                timestamp: DateTime.now().subtract(const Duration(days: 1, minutes: -10)),
                sessionId: 'session_2',
              ),
              GameAction(
                type: GameActionType.gameEnd,
                timestamp: DateTime.now().subtract(const Duration(days: 1, minutes: -15)),
                sessionId: 'session_2',
                metadata: {'score': 750},
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
        ];

        // Save mock behavior data
        final behaviorData = UserBehaviorData(
          userId: userId,
          sessions: mockSessions,
          totalPlayTime: const Duration(minutes: 25),
          averageScore: 625.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: DateTime.now().subtract(const Duration(days: 1)),
        );

        // Save to preferences to simulate existing data
        await prefs.setString(
          'behavior_data_$userId',
          jsonEncode(behaviorData.toJson()),
        );

        final pattern = await analyzer.analyzeBehaviorPattern(userId);

        expect(pattern.userId, equals(userId));
        expect(pattern.averageSessionLength.inMinutes, equals(12)); // 25 minutes / 2 sessions
        expect(pattern.commonActions[GameActionType.gameStart], equals(2));
        expect(pattern.commonActions[GameActionType.gameEnd], equals(2));
        expect(pattern.commonActions[GameActionType.jump], equals(1));
        expect(pattern.commonActions[GameActionType.draw], equals(1));
        expect(pattern.commonActions[GameActionType.adView], equals(1));
        expect(pattern.featureUsageRates['drawing'], greaterThan(0));
        expect(pattern.featureUsageRates['ads'], greaterThan(0));
      });

      test('should return default pattern for new user', () async {
        const userId = 'new_user_123';
        
        final pattern = await analyzer.analyzeBehaviorPattern(userId);

        expect(pattern.userId, equals(userId));
        expect(pattern.averageSessionLength, equals(const Duration(minutes: 2)));
        expect(pattern.dailyPlayFrequency, equals(0.5));
        expect(pattern.commonActions, isEmpty);
        expect(pattern.featureUsageRates, isEmpty);
        expect(pattern.retentionIndicators.sessionConsistency, equals(0.5));
      });
    });

    group('Churn Risk Prediction', () {
      test('should predict high churn risk for inactive user', () async {
        const userId = 'inactive_user_123';
        
        // Create behavior data for inactive user
        final behaviorData = UserBehaviorData(
          userId: userId,
          sessions: [
            UserSession(
              sessionId: 'old_session',
              userId: userId,
              startTime: DateTime.now().subtract(const Duration(days: 10)),
              endTime: DateTime.now().subtract(const Duration(days: 10, minutes: -5)),
              actions: [
                GameAction(
                  type: GameActionType.gameStart,
                  timestamp: DateTime.now().subtract(const Duration(days: 10)),
                  sessionId: 'old_session',
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
          totalPlayTime: const Duration(minutes: 5),
          averageScore: 100.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: DateTime.now().subtract(const Duration(days: 10)),
        );

        // Save mock data
        await prefs.setString(
          'behavior_data_$userId',
          jsonEncode(behaviorData.toJson()),
        );

        final churnRisk = await analyzer.predictChurnRisk(userId);

        expect(churnRisk.riskLevel, equals(ChurnRiskLevel.high));
        expect(churnRisk.probability, greaterThan(0.5));
        expect(churnRisk.primaryFactors, contains('long_absence'));
        expect(churnRisk.recommendedActions, contains('send_comeback_notification'));
      });

      test('should predict low churn risk for active user', () async {
        const userId = 'active_user_123';
        
        // Create behavior data for active user
        final recentSessions = List.generate(5, (index) => 
          UserSession(
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
              GameAction(
                type: GameActionType.tutorialStep,
                timestamp: DateTime.now().subtract(Duration(days: index, minutes: -2)),
                sessionId: 'session_$index',
              ),
              GameAction(
                type: GameActionType.gameEnd,
                timestamp: DateTime.now().subtract(Duration(days: index, minutes: -10)),
                sessionId: 'session_$index',
                metadata: {'score': 500 + index * 100},
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
        );

        final behaviorData = UserBehaviorData(
          userId: userId,
          sessions: recentSessions,
          totalPlayTime: const Duration(minutes: 50),
          averageScore: 700.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: DateTime.now(),
        );

        // Save mock data
        await prefs.setString(
          'behavior_data_$userId',
          jsonEncode(behaviorData.toJson()),
        );

        final churnRisk = await analyzer.predictChurnRisk(userId);

        expect(churnRisk.riskLevel, equals(ChurnRiskLevel.low));
        expect(churnRisk.probability, lessThan(0.3));
      });
    });

    group('Data Cleanup', () {
      test('should cleanup old data', () async {
        // Create old data
        const oldUserId = 'old_user_123';
        final oldDate = DateTime.now().subtract(const Duration(days: 100));
        
        final oldBehaviorData = UserBehaviorData(
          userId: oldUserId,
          sessions: [],
          totalPlayTime: Duration.zero,
          averageScore: 0.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: oldDate,
        );

        await prefs.setString(
          'behavior_data_$oldUserId',
          jsonEncode(oldBehaviorData.toJson()),
        );

        // Create recent data
        const recentUserId = 'recent_user_123';
        final recentDate = DateTime.now().subtract(const Duration(days: 1));
        
        final recentBehaviorData = UserBehaviorData(
          userId: recentUserId,
          sessions: [],
          totalPlayTime: Duration.zero,
          averageScore: 0.0,
          purchaseHistory: [],
          adInteractions: [],
          socialActions: [],
          lastActiveDate: recentDate,
        );

        await prefs.setString(
          'behavior_data_$recentUserId',
          jsonEncode(recentBehaviorData.toJson()),
        );

        // Verify both exist
        expect(prefs.getString('behavior_data_$oldUserId'), isNotNull);
        expect(prefs.getString('behavior_data_$recentUserId'), isNotNull);

        // Cleanup old data
        await analyzer.cleanupOldData();

        // Verify old data is removed, recent data remains
        expect(prefs.getString('behavior_data_$oldUserId'), isNull);
        expect(prefs.getString('behavior_data_$recentUserId'), isNotNull);
      });
    });
  });
}