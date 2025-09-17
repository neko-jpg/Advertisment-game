import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/core/error_handling/error_recovery_manager.dart';
import '../../../lib/core/logging/logger.dart';
import '../../../lib/core/env.dart';

void main() {
  group('ErrorRecoveryManager', () {
    late ErrorRecoveryManager errorRecoveryManager;
    late AppLogger logger;

    setUp(() async {
      // SharedPreferencesのモックを設定
      SharedPreferences.setMockInitialValues({});
      
      logger = AppLogger(environment: AppEnvironment(
        name: 'test',
        isTestBuild: true,
        analyticsEnabled: false,
        adsEnabled: false,
        adUnits: const AdUnitConfiguration(
          bannerAdUnitId: 'test',
          interstitialAdUnitId: 'test',
          rewardedAdUnitId: 'test',
          appId: 'test',
        ),
      ));
      errorRecoveryManager = ErrorRecoveryManager(logger: logger);
    });

    tearDown(() {
      errorRecoveryManager.dispose();
    });

    test('should initialize successfully', () async {
      await errorRecoveryManager.initialize();
      expect(errorRecoveryManager.isInitialized, isTrue);
      expect(errorRecoveryManager.isOfflineMode, isFalse);
    });

    test('should save and restore game state', () async {
      await errorRecoveryManager.initialize();

      final gameState = GameStateSnapshot(
        score: 100,
        coins: 50,
        playerY: 200.0,
        elapsedTime: 30000.0,
        gameState: 'running',
        timestamp: DateTime.now(),
      );

      // ゲーム状態を保存
      await errorRecoveryManager.saveGameState(gameState);

      // ゲーム状態を復元
      final restoredState = await errorRecoveryManager.restoreGameState();

      expect(restoredState, isNotNull);
      expect(restoredState!.score, equals(100));
      expect(restoredState.coins, equals(50));
      expect(restoredState.playerY, equals(200.0));
      expect(restoredState.elapsedTime, equals(30000.0));
      expect(restoredState.gameState, equals('running'));
    });

    test('should handle network errors and enable offline mode', () async {
      await errorRecoveryManager.initialize();

      final networkError = Exception('Network connection failed');
      
      // 最初のネットワークエラー
      bool shouldContinueOffline = await errorRecoveryManager.handleNetworkError(networkError);
      expect(shouldContinueOffline, isFalse);
      expect(errorRecoveryManager.isOfflineMode, isFalse);

      // 複数回のネットワークエラー後にオフラインモードが有効になる
      await errorRecoveryManager.handleNetworkError(networkError);
      await errorRecoveryManager.handleNetworkError(networkError);
      shouldContinueOffline = await errorRecoveryManager.handleNetworkError(networkError);
      
      expect(shouldContinueOffline, isTrue);
      expect(errorRecoveryManager.isOfflineMode, isTrue);
    });

    test('should handle crash and increment crash count', () async {
      await errorRecoveryManager.initialize();

      final error = Exception('Test crash');
      final stackTrace = StackTrace.current;

      await errorRecoveryManager.handleCrash(error, stackTrace);

      // クラッシュカウントが増加したことを確認
      final prefs = await SharedPreferences.getInstance();
      final crashCount = prefs.getInt('error_recovery_crash_count') ?? 0;
      expect(crashCount, equals(1));
    });

    test('should repair data inconsistency', () async {
      await errorRecoveryManager.initialize();

      // データ不整合の修復をテスト
      await expectLater(
        errorRecoveryManager.repairDataInconsistency(),
        completes,
      );
    });

    test('should not restore old game state', () async {
      await errorRecoveryManager.initialize();

      // 古いタイムスタンプのゲーム状態を作成
      final oldGameState = GameStateSnapshot(
        score: 100,
        coins: 50,
        playerY: 200.0,
        elapsedTime: 30000.0,
        gameState: 'running',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      );

      await errorRecoveryManager.saveGameState(oldGameState);

      // 古すぎる状態は復元されない
      final restoredState = await errorRecoveryManager.restoreGameState();
      expect(restoredState, isNull);
    });

    test('should handle invalid game state data', () async {
      await errorRecoveryManager.initialize();

      // 無効なJSONデータを設定
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('error_recovery_game_state', 'invalid json');

      // 無効なデータの場合はnullを返す
      final restoredState = await errorRecoveryManager.restoreGameState();
      expect(restoredState, isNull);
    });

    test('should enable and disable offline mode', () async {
      await errorRecoveryManager.initialize();

      expect(errorRecoveryManager.isOfflineMode, isFalse);

      await errorRecoveryManager.enableOfflineMode();
      expect(errorRecoveryManager.isOfflineMode, isTrue);

      await errorRecoveryManager.disableOfflineMode();
      expect(errorRecoveryManager.isOfflineMode, isFalse);
    });
  });

  group('GameStateSnapshot', () {
    test('should serialize and deserialize correctly', () {
      final originalState = GameStateSnapshot(
        score: 150,
        coins: 75,
        playerY: 300.0,
        elapsedTime: 45000.0,
        gameState: 'running',
        timestamp: DateTime.now(),
      );

      final json = originalState.toJson();
      final restoredState = GameStateSnapshot.fromJson(json);

      expect(restoredState.score, equals(originalState.score));
      expect(restoredState.coins, equals(originalState.coins));
      expect(restoredState.playerY, equals(originalState.playerY));
      expect(restoredState.elapsedTime, equals(originalState.elapsedTime));
      expect(restoredState.gameState, equals(originalState.gameState));
      expect(restoredState.timestamp, equals(originalState.timestamp));
    });

    test('should handle JSON with missing fields gracefully', () {
      final incompleteJson = {
        'score': 100,
        'coins': 50,
        // playerY missing
        'elapsedTime': 30000.0,
        'gameState': 'running',
        'timestamp': DateTime.now().toIso8601String(),
      };

      expect(
        () => GameStateSnapshot.fromJson(incompleteJson),
        throwsA(isA<TypeError>()),
      );
    });
  });
}