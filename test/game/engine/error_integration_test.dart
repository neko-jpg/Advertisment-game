import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../lib/core/error_handling/error_recovery_manager.dart';
import '../../../lib/core/logging/logger.dart';
import '../../../lib/core/env.dart';
import '../../../lib/game/engine/error_integration.dart';

// テスト用のGameProviderモック
class TestGameProvider extends ChangeNotifier with ErrorHandlingMixin {
  int score = 0;
  int coins = 0;
  double playerY = 100.0;
  double elapsedTime = 0.0;
  String gameState = 'ready';
  
  String? lastToastMessage;
  IconData? lastToastIcon;
  Color? lastToastColor;

  @override
  GameStateSnapshot? getCurrentGameState() {
    if (gameState == 'running') {
      return GameStateSnapshot(
        score: score,
        coins: coins,
        playerY: playerY,
        elapsedTime: elapsedTime,
        gameState: gameState,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  @override
  Future<void> onGameStateRestored(GameStateSnapshot savedState) async {
    score = savedState.score;
    coins = savedState.coins;
    playerY = savedState.playerY;
    elapsedTime = savedState.elapsedTime;
    gameState = savedState.gameState;
    notifyListeners();
  }

  @override
  void showToastMessage(String message, IconData icon, Color color) {
    lastToastMessage = message;
    lastToastIcon = icon;
    lastToastColor = color;
  }

  void startGame() {
    gameState = 'running';
    score = 0;
    coins = 0;
    elapsedTime = 0.0;
    notifyListeners();
  }

  void updateGame() {
    if (gameState == 'running') {
      score += 10;
      coins += 5;
      elapsedTime += 1000.0;
      notifyListeners();
    }
  }

  Future<void> simulateNetworkOperation() async {
    // ネットワーク操作のシミュレーション
    await safeAsyncOperation(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      throw Exception('Network error');
    }, context: 'Network operation');
  }

  void simulateSyncOperation() {
    safeSyncOperation(() {
      throw Exception('Sync error');
    }, context: 'Sync operation');
  }
}

void main() {
  group('ErrorHandlingMixin Integration', () {
    late TestGameProvider gameProvider;
    late AppLogger logger;

    setUp(() async {
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
      gameProvider = TestGameProvider();
    });

    tearDown(() {
      gameProvider.disposeErrorHandling();
      gameProvider.dispose();
    });

    test('should initialize error handling successfully', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      // エラーハンドリングが初期化されたことを確認
      expect(gameProvider.getCurrentGameState(), isNull); // ゲームが開始されていない
    });

    test('should save and restore game state automatically', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      // ゲームを開始
      gameProvider.startGame();
      gameProvider.updateGame();
      
      expect(gameProvider.score, equals(10));
      expect(gameProvider.coins, equals(5));
      
      // 現在の状態を取得
      final currentState = gameProvider.getCurrentGameState();
      expect(currentState, isNotNull);
      expect(currentState!.score, equals(10));
      expect(currentState.coins, equals(5));
      
      // 新しいプロバイダーで状態復元をテスト
      final newGameProvider = TestGameProvider();
      await newGameProvider.initializeErrorHandling(logger);
      
      // 手動で状態を保存して復元
      await newGameProvider.onGameStateRestored(currentState);
      
      expect(newGameProvider.score, equals(10));
      expect(newGameProvider.coins, equals(5));
      
      newGameProvider.disposeErrorHandling();
      newGameProvider.dispose();
    });

    test('should handle async operations safely', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      // ネットワークエラーをシミュレート
      await gameProvider.simulateNetworkOperation();
      
      // エラーが安全に処理されることを確認（例外が投げられない）
      expect(true, isTrue); // テストが完了すれば成功
    });

    test('should handle sync operations safely', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      // 同期エラーをシミュレート
      gameProvider.simulateSyncOperation();
      
      // エラーが安全に処理されることを確認（例外が投げられない）
      expect(true, isTrue); // テストが完了すれば成功
    });

    test('should handle network errors and suggest offline mode', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      final networkError = Exception('Network connection failed');
      
      // ネットワークエラーを処理
      final shouldContinueOffline = await gameProvider.handleNetworkError(networkError);
      
      // 最初のエラーではオフラインモードにならない
      expect(shouldContinueOffline, isFalse);
    });

    test('should repair data inconsistency', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      // データ不整合の修復をテスト
      await expectLater(
        gameProvider.repairDataInconsistency(),
        completes,
      );
    });

    test('should dispose resources properly', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      // リソースの解放をテスト
      gameProvider.disposeErrorHandling();
      
      // 解放後は安全な操作が無効になる
      final result = await gameProvider.safeAsyncOperation(() async {
        return 'test';
      });
      
      expect(result, isNull);
    });

    test('should handle multiple game state updates', () async {
      await gameProvider.initializeErrorHandling(logger);
      
      gameProvider.startGame();
      
      // 複数回の更新
      for (int i = 0; i < 5; i++) {
        gameProvider.updateGame();
      }
      
      expect(gameProvider.score, equals(50));
      expect(gameProvider.coins, equals(25));
      
      final currentState = gameProvider.getCurrentGameState();
      expect(currentState, isNotNull);
      expect(currentState!.score, equals(50));
      expect(currentState.coins, equals(25));
    });
  });
}