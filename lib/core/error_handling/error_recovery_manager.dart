import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/logger.dart';
import '../../game/models/game_models.dart';

/// エラー回復とクラッシュ対策を管理するクラス
/// 要件6.3, 6.4に対応
class ErrorRecoveryManager {
  ErrorRecoveryManager({
    required AppLogger logger,
  }) : _logger = logger;

  final AppLogger _logger;
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isOfflineMode = false;
  Timer? _networkRetryTimer;
  Timer? _autoSaveTimer;
  
  // ゲーム状態の自動保存用キー
  static const String _gameStateKey = 'error_recovery_game_state';
  static const String _lastSaveTimeKey = 'error_recovery_last_save_time';
  static const String _crashCountKey = 'error_recovery_crash_count';
  static const String _networkErrorCountKey = 'error_recovery_network_error_count';
  
  // 設定値
  static const Duration _autoSaveInterval = Duration(seconds: 30);
  static const Duration _networkRetryInterval = Duration(seconds: 5);
  static const int _maxNetworkRetries = 3;
  static const int _maxCrashCount = 5;

  bool get isInitialized => _isInitialized;
  bool get isOfflineMode => _isOfflineMode;

  /// 初期化処理
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      
      // クラッシュカウントをチェック
      await _checkCrashHistory();
      
      // 自動保存タイマーを開始
      _startAutoSaveTimer();
      
      _logger.info('ErrorRecoveryManager initialized successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize ErrorRecoveryManager', 
                   error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ネットワークエラー時のオフライン継続機能を有効化
  Future<void> enableOfflineMode() async {
    if (_isOfflineMode) return;
    
    _isOfflineMode = true;
    _logger.info('Offline mode enabled due to network error');
    
    // ネットワーク復旧を定期的にチェック
    _startNetworkRetryTimer();
    
    // オフラインモード用の設定を適用
    await _applyOfflineConfiguration();
  }

  /// ネットワーク復旧時の処理
  Future<void> disableOfflineMode() async {
    if (!_isOfflineMode) return;
    
    _isOfflineMode = false;
    _networkRetryTimer?.cancel();
    _networkRetryTimer = null;
    
    _logger.info('Offline mode disabled - network recovered');
    
    // オフライン中に蓄積されたデータを同期
    await _syncOfflineData();
  }

  /// ゲーム状態の自動保存
  Future<void> saveGameState(GameStateSnapshot state) async {
    if (!_isInitialized || _prefs == null) return;
    
    try {
      final stateJson = json.encode(state.toJson());
      await _prefs!.setString(_gameStateKey, stateJson);
      await _prefs!.setInt(_lastSaveTimeKey, DateTime.now().millisecondsSinceEpoch);
      
      _logger.debug('Game state saved successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to save game state', error: error, stackTrace: stackTrace);
    }
  }

  /// ゲーム状態の復元
  Future<GameStateSnapshot?> restoreGameState() async {
    if (!_isInitialized || _prefs == null) return null;
    
    try {
      final stateJson = _prefs!.getString(_gameStateKey);
      if (stateJson == null) return null;
      
      final stateMap = json.decode(stateJson) as Map<String, dynamic>;
      final state = GameStateSnapshot.fromJson(stateMap);
      
      // 保存時刻をチェック（古すぎる場合は無効）
      final timeDiff = DateTime.now().difference(state.timestamp).inHours;
      
      if (timeDiff > 24) {
        _logger.info('Saved game state is too old, ignoring');
        await _clearSavedGameState();
        return null;
      }
      
      _logger.info('Game state restored successfully');
      return state;
    } catch (error, stackTrace) {
      _logger.error('Failed to restore game state', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  /// データ不整合の自動修復
  Future<void> repairDataInconsistency() async {
    _logger.info('Starting data inconsistency repair');
    
    try {
      // SharedPreferencesの整合性チェック
      await _validateAndRepairPreferences();
      
      // ゲーム状態の整合性チェック
      await _validateAndRepairGameState();
      
      _logger.info('Data inconsistency repair completed');
    } catch (error, stackTrace) {
      _logger.error('Failed to repair data inconsistency', 
                   error: error, stackTrace: stackTrace);
    }
  }

  /// 広告読み込み失敗時の代替収益化
  Future<void> fallbackMonetization() async {
    _logger.info('Activating fallback monetization due to ad failure');
    
    try {
      // 代替収益化ロジック（例：コイン購入促進、プレミアム機能提案など）
      await _activateAlternativeMonetization();
      
      _logger.info('Fallback monetization activated');
    } catch (error, stackTrace) {
      _logger.error('Failed to activate fallback monetization', 
                   error: error, stackTrace: stackTrace);
    }
  }

  /// ネットワークエラーハンドリング
  Future<bool> handleNetworkError(Object error) async {
    _logger.warn('Network error detected', error: error);
    
    final errorCount = await _incrementNetworkErrorCount();
    
    if (errorCount >= _maxNetworkRetries) {
      await enableOfflineMode();
      return true; // オフラインモードで継続
    }
    
    return false; // リトライ可能
  }

  /// クラッシュハンドリング
  Future<void> handleCrash(Object error, StackTrace stackTrace) async {
    _logger.error('Crash detected', error: error, stackTrace: stackTrace);
    
    try {
      // クラッシュカウントを増加
      await _incrementCrashCount();
      
      // 現在のゲーム状態を緊急保存
      await _emergencySaveGameState();
      
      // クラッシュレポートを準備（オフラインでも後で送信）
      await _prepareCrashReport(error, stackTrace);
      
    } catch (e, st) {
      // クラッシュハンドリング自体でエラーが発生した場合
      _logger.error('Failed to handle crash', error: e, stackTrace: st);
    }
  }

  /// リソースクリーンアップ
  void dispose() {
    _autoSaveTimer?.cancel();
    _networkRetryTimer?.cancel();
    _logger.info('ErrorRecoveryManager disposed');
  }

  // プライベートメソッド

  Future<void> _checkCrashHistory() async {
    if (_prefs == null) return;
    
    final crashCount = _prefs!.getInt(_crashCountKey) ?? 0;
    if (crashCount >= _maxCrashCount) {
      _logger.warn('High crash count detected: $crashCount');
      // セーフモードの提案やデータリセットの検討
      await _suggestSafeMode();
    }
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) {
      // ゲーム状態の定期保存はGameProviderから呼び出される
      _logger.debug('Auto-save timer tick');
    });
  }

  void _startNetworkRetryTimer() {
    _networkRetryTimer = Timer.periodic(_networkRetryInterval, (timer) async {
      if (await _checkNetworkConnectivity()) {
        await disableOfflineMode();
      }
    });
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _applyOfflineConfiguration() async {
    // オフラインモード用の設定
    // 例：広告を無効化、ローカルデータのみ使用など
    _logger.info('Applied offline configuration');
  }

  Future<void> _syncOfflineData() async {
    // オフライン中に蓄積されたデータをサーバーと同期
    _logger.info('Syncing offline data');
  }

  Future<void> _validateAndRepairPreferences() async {
    if (_prefs == null) return;
    
    // 必要なキーが存在するかチェック
    final requiredKeys = [
      'meta_total_coins',
      'meta_owned_skins',
      'meta_selected_skin',
    ];
    
    for (final key in requiredKeys) {
      if (!_prefs!.containsKey(key)) {
        _logger.warn('Missing preference key: $key, setting default');
        await _setDefaultPreference(key);
      }
    }
  }

  Future<void> _setDefaultPreference(String key) async {
    if (_prefs == null) return;
    
    switch (key) {
      case 'meta_total_coins':
        await _prefs!.setInt(key, 0);
        break;
      case 'meta_owned_skins':
        await _prefs!.setStringList(key, ['default']);
        break;
      case 'meta_selected_skin':
        await _prefs!.setString(key, 'default');
        break;
    }
  }

  Future<void> _validateAndRepairGameState() async {
    final state = await restoreGameState();
    if (state != null) {
      // ゲーム状態の妥当性をチェック
      if (state.score < 0 || state.coins < 0) {
        _logger.warn('Invalid game state detected, clearing');
        await _clearSavedGameState();
      }
    }
  }

  Future<void> _clearSavedGameState() async {
    if (_prefs == null) return;
    
    await _prefs!.remove(_gameStateKey);
    await _prefs!.remove(_lastSaveTimeKey);
  }

  Future<void> _activateAlternativeMonetization() async {
    // 代替収益化の実装
    // 例：特別オファーの表示、プレミアム機能の提案など
  }

  Future<int> _incrementNetworkErrorCount() async {
    if (_prefs == null) return 0;
    
    final count = (_prefs!.getInt(_networkErrorCountKey) ?? 0) + 1;
    await _prefs!.setInt(_networkErrorCountKey, count);
    return count;
  }

  Future<int> _incrementCrashCount() async {
    if (_prefs == null) return 0;
    
    final count = (_prefs!.getInt(_crashCountKey) ?? 0) + 1;
    await _prefs!.setInt(_crashCountKey, count);
    return count;
  }

  Future<void> _emergencySaveGameState() async {
    // 緊急時のゲーム状態保存
    // 現在のゲーム状態を可能な限り保存
    _logger.info('Emergency game state save initiated');
  }

  Future<void> _prepareCrashReport(Object error, StackTrace stackTrace) async {
    // クラッシュレポートの準備
    final report = {
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'isOfflineMode': _isOfflineMode,
    };
    
    // オフラインでも後で送信できるようにローカルに保存
    if (_prefs != null) {
      await _prefs!.setString('crash_report_${DateTime.now().millisecondsSinceEpoch}', 
                             json.encode(report));
    }
  }

  Future<void> _suggestSafeMode() async {
    // セーフモードの提案
    _logger.info('Suggesting safe mode due to high crash count');
  }
}

/// ゲーム状態のスナップショット
class GameStateSnapshot {
  const GameStateSnapshot({
    required this.score,
    required this.coins,
    required this.playerY,
    required this.elapsedTime,
    required this.gameState,
    required this.timestamp,
  });

  final int score;
  final int coins;
  final double playerY;
  final double elapsedTime;
  final String gameState;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'coins': coins,
      'playerY': playerY,
      'elapsedTime': elapsedTime,
      'gameState': gameState,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    return GameStateSnapshot(
      score: json['score'] as int,
      coins: json['coins'] as int,
      playerY: (json['playerY'] as num).toDouble(),
      elapsedTime: (json['elapsedTime'] as num).toDouble(),
      gameState: json['gameState'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}