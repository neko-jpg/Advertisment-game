import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logging/logger.dart';
import 'error_recovery_manager.dart';

/// ゲーム専用のエラーハンドラー
/// GameProviderと連携してエラー処理を行う
class GameErrorHandler {
  GameErrorHandler({
    required AppLogger logger,
    required ErrorRecoveryManager errorRecoveryManager,
  }) : _logger = logger,
       _errorRecoveryManager = errorRecoveryManager;

  final AppLogger _logger;
  final ErrorRecoveryManager _errorRecoveryManager;
  Timer? _autoSaveTimer;

  /// ゲームループ内でのエラーハンドリング
  Future<T> handleGameLoopError<T>(
    Future<T> Function() operation,
    T fallbackValue,
  ) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      _logger.error('Game loop error', error: error, stackTrace: stackTrace);
      await _errorRecoveryManager.handleCrash(error, stackTrace);
      return fallbackValue;
    }
  }

  /// 同期処理のエラーハンドリング
  T handleSyncError<T>(
    T Function() operation,
    T fallbackValue,
  ) {
    try {
      return operation();
    } catch (error, stackTrace) {
      _logger.error('Sync operation error', error: error, stackTrace: stackTrace);
      // 非同期でクラッシュハンドリング
      unawaited(_errorRecoveryManager.handleCrash(error, stackTrace));
      return fallbackValue;
    }
  }

  /// ネットワーク操作のエラーハンドリング
  Future<T?> handleNetworkError<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      _logger.warn('Network operation failed', error: error);
      
      final shouldContinueOffline = await _errorRecoveryManager.handleNetworkError(error);
      if (shouldContinueOffline) {
        _logger.info('Continuing in offline mode');
      }
      
      return null;
    }
  }

  /// 自動保存タイマーの開始
  void startAutoSave(Future<void> Function() saveOperation) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          await saveOperation();
        } catch (error, stackTrace) {
          _logger.error('Auto-save failed', error: error, stackTrace: stackTrace);
        }
      },
    );
  }

  /// リソースクリーンアップ
  void dispose() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }
}