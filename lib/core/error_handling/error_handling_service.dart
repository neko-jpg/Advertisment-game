import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logging/logger.dart';
import 'error_recovery_manager.dart';
import 'game_error_handler.dart';

/// エラーハンドリングサービスの統合クラス
/// アプリ全体のエラー処理を統括する
class ErrorHandlingService {
  ErrorHandlingService._({
    required AppLogger logger,
  }) : _logger = logger {
    _errorRecoveryManager = ErrorRecoveryManager(logger: logger);
    _gameErrorHandler = GameErrorHandler(
      logger: logger,
      errorRecoveryManager: _errorRecoveryManager,
    );
  }

  static ErrorHandlingService? _instance;
  
  static ErrorHandlingService getInstance({required AppLogger logger}) {
    return _instance ??= ErrorHandlingService._(logger: logger);
  }

  final AppLogger _logger;
  late final ErrorRecoveryManager _errorRecoveryManager;
  late final GameErrorHandler _gameErrorHandler;
  bool _isInitialized = false;

  ErrorRecoveryManager get errorRecoveryManager => _errorRecoveryManager;
  GameErrorHandler get gameErrorHandler => _gameErrorHandler;
  bool get isInitialized => _isInitialized;

  /// サービスの初期化
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // グローバルエラーハンドラーの設定
      FlutterError.onError = _handleFlutterError;
      
      // 非同期エラーハンドラーの設定
      PlatformDispatcher.instance.onError = _handlePlatformError;

      // エラー回復マネージャーの初期化
      await _errorRecoveryManager.initialize();

      _isInitialized = true;
      _logger.info('ErrorHandlingService initialized successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize ErrorHandlingService', 
                   error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Flutterエラーのハンドリング
  void _handleFlutterError(FlutterErrorDetails details) {
    _logger.error(
      'Flutter error: ${details.summary}',
      error: details.exception,
      stackTrace: details.stack,
    );

    // クラッシュハンドリング
    unawaited(_errorRecoveryManager.handleCrash(
      details.exception,
      details.stack ?? StackTrace.current,
    ));

    // デバッグモードでは元の処理も実行
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// プラットフォームエラーのハンドリング
  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    _logger.error('Platform error', error: error, stackTrace: stackTrace);

    // クラッシュハンドリング
    unawaited(_errorRecoveryManager.handleCrash(error, stackTrace));

    return true; // エラーを処理済みとしてマーク
  }

  /// 手動でのエラー報告
  Future<void> reportError(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) async {
    _logger.error(
      context != null ? '$context: $error' : error.toString(),
      error: error,
      stackTrace: stackTrace,
    );

    await _errorRecoveryManager.handleCrash(error, stackTrace);
  }

  /// ネットワークエラーの処理
  Future<bool> handleNetworkError(Object error) async {
    return await _errorRecoveryManager.handleNetworkError(error);
  }

  /// データ不整合の修復
  Future<void> repairDataInconsistency() async {
    await _errorRecoveryManager.repairDataInconsistency();
  }

  /// オフラインモードの有効化
  Future<void> enableOfflineMode() async {
    await _errorRecoveryManager.enableOfflineMode();
  }

  /// オフラインモードの無効化
  Future<void> disableOfflineMode() async {
    await _errorRecoveryManager.disableOfflineMode();
  }

  /// ゲーム状態の保存
  Future<void> saveGameState(GameStateSnapshot state) async {
    await _errorRecoveryManager.saveGameState(state);
  }

  /// ゲーム状態の復元
  Future<GameStateSnapshot?> restoreGameState() async {
    return await _errorRecoveryManager.restoreGameState();
  }

  /// サービスの終了処理
  void dispose() {
    _gameErrorHandler.dispose();
    _errorRecoveryManager.dispose();
    _instance = null;
    _logger.info('ErrorHandlingService disposed');
  }
}