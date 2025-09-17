# エラーハンドリング・クラッシュ対策システム

このシステムは要件6.3、6.4に対応し、ゲームの安定性とユーザー体験を向上させるための包括的なエラー処理機能を提供します。

## 主な機能

### 1. ErrorRecoveryManager
- **ネットワークエラー時のオフライン継続機能**
- **ゲーム状態の自動保存・復元機能**
- **データ不整合の自動修復**
- **クラッシュ検知と回復処理**

### 2. ErrorHandlingService
- **グローバルエラーハンドラーの設定**
- **統合的なエラー処理管理**
- **自動エラー報告機能**

### 3. ErrorHandlingMixin
- **GameProviderへの簡単な統合**
- **安全な操作実行**
- **自動保存機能**

## 使用方法

### 基本的な統合

```dart
// GameProviderにミックスインを追加
class GameProvider extends ChangeNotifier with ErrorHandlingMixin {
  // 既存のコード...

  // コンストラクタでエラーハンドリングを初期化
  GameProvider({
    required AppLogger logger,
    // その他のパラメータ...
  }) {
    initializeErrorHandling(logger);
  }

  // 現在のゲーム状態を返す実装
  @override
  GameStateSnapshot? getCurrentGameState() {
    if (_gameState == GameState.running) {
      return GameStateSnapshot(
        score: _score,
        coins: coinProvider.coinsCollected,
        playerY: _playerY,
        elapsedTime: _elapsedRunMs,
        gameState: _gameState.name,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  // ゲーム状態復元時の処理
  @override
  Future<void> onGameStateRestored(GameStateSnapshot savedState) async {
    _score = savedState.score;
    _playerY = savedState.playerY;
    _elapsedRunMs = savedState.elapsedTime;
    // 復元完了をユーザーに通知
    showToastMessage(
      'Previous game restored',
      Icons.restore_rounded,
      const Color(0xFF22C55E),
    );
    notifyListeners();
  }

  // トーストメッセージ表示の実装
  @override
  void showToastMessage(String message, IconData icon, Color color) {
    _pushToast(GameToast(
      message: message,
      icon: icon,
      color: color,
    ));
  }

  // リソース解放時にエラーハンドリングも解放
  @override
  void dispose() {
    disposeErrorHandling();
    super.dispose();
  }
}
```

### 安全な操作の実行

```dart
// 非同期操作を安全に実行
Future<void> saveUserProgress() async {
  final result = await safeAsyncOperation(() async {
    // ネットワーク操作やファイル保存など
    return await apiService.saveProgress(gameData);
  }, context: 'Save user progress');
  
  if (result != null) {
    // 成功時の処理
  }
}

// 同期操作を安全に実行
void updateGameLogic() {
  safeSyncOperation(() {
    // ゲームロジックの更新
    _updatePlayerPosition();
    _checkCollisions();
  }, context: 'Game logic update');
}
```

### ネットワークエラーの処理

```dart
Future<void> loadRemoteConfig() async {
  try {
    final config = await remoteConfigService.fetch();
    applyConfig(config);
  } catch (error) {
    final shouldContinueOffline = await handleNetworkError(error);
    if (shouldContinueOffline) {
      // オフラインモードで継続
      applyDefaultConfig();
    }
  }
}
```

## 設定とカスタマイズ

### 自動保存間隔の調整
```dart
// ErrorRecoveryManagerの設定値を変更
static const Duration _autoSaveInterval = Duration(seconds: 30); // デフォルト
```

### ネットワークリトライ回数の調整
```dart
static const int _maxNetworkRetries = 3; // デフォルト
```

### クラッシュ許容回数の調整
```dart
static const int _maxCrashCount = 5; // デフォルト
```

## テスト

システムには包括的なテストが含まれています：

```bash
# エラー回復マネージャーのテスト
flutter test test/core/error_handling/error_recovery_manager_test.dart

# 統合テスト
flutter test test/game/engine/error_integration_test.dart
```

## ログ出力

システムは詳細なログを出力します：

- **INFO**: 正常な動作状況
- **WARN**: 警告レベルのエラー（ネットワークエラーなど）
- **ERROR**: 重大なエラー（クラッシュなど）
- **DEBUG**: デバッグ情報（テストビルドのみ）

## パフォーマンスへの影響

- **メモリ使用量**: 最小限（主にログとタイマー）
- **CPU使用量**: 自動保存時のみ軽微な負荷
- **ストレージ**: ゲーム状態とエラーログの保存（数KB程度）

## 今後の拡張

- **リモートエラー報告**: Firebase Crashlyticsとの統合
- **A/Bテスト**: エラー回復戦略の最適化
- **機械学習**: エラーパターンの予測と予防