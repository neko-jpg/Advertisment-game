import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/error_handling/error_handling_service.dart';
import '../../core/error_handling/error_recovery_manager.dart';
import '../../core/logging/logger.dart';
import '../models/game_models.dart';

/// GameProviderにエラーハンドリング機能を統合するためのミックスイン
mixin ErrorHandlingMixin on ChangeNotifier {
  ErrorHandlingService? _errorHandlingService;
  Timer? _autoSaveTimer;

  /// エラーハンドリングサービスの初期化
  Future<void> initializeErrorHandling(AppLogger logger) async {
    try {
      _errorHandlingService = ErrorHandlingService.getInstance(logger: logger);
      await _errorHandlingService!.initialize();
      
      // 自動保存タイマーの開始
      _startAutoSaveTimer();
      
      // 保存されたゲーム状態の復元を試行
      await _attemptGameStateRestore();
    } catch (error, stackTrace) {
      logger.error('Failed to initialize error handling', 
                  error: error, stackTrace: stackTrace);
    }
  }

  /// ゲーム状態の復元を試行
  Future<void> _attemptGameStateRestore() async {
    if (_errorHandlingService == null) return;

    try {
      final savedState = await _errorHandlingService!.restoreGameState();
      if (savedState != null) {
        await onGameStateRestored(savedState);
      }
    } catch (error, stackTrace) {
      await _errorHandlingService!.reportError(error, stackTrace, 
                                              context: 'Game state restore');
    }
  }

  /// 自動保存タイマーの開始
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _performAutoSave(),
    );
  }

  /// 自動保存の実行
  Future<void> _performAutoSave() async {
    if (_errorHandlingService == null) return;

    try {
      final currentState = getCurrentGameState();
      if (currentState != null) {
        await _errorHandlingService!.saveGameState(currentState);
      }
    } catch (error, stackTrace) {
      await _errorHandlingService!.reportError(error, stackTrace, 
                                              context: 'Auto save');
    }
  }

  /// 安全な非同期操作の実行
  Future<T?> safeAsyncOperation<T>(
    Future<T> Function() operation, {
    String? context,
  }) async {
    if (_errorHandlingService == null || !_errorHandlingService!.isInitialized) return null;

    try {
      return await operation();
    } catch (error, stackTrace) {
      await _errorHandlingService!.reportError(error, stackTrace, 
                                              context: context);
      return null;
    }
  }

  /// 安全な同期操作の実行
  T? safeSyncOperation<T>(
    T Function() operation, {
    String? context,
  }) {
    if (_errorHandlingService == null || !_errorHandlingService!.isInitialized) return null;

    try {
      return operation();
    } catch (error, stackTrace) {
      unawaited(_errorHandlingService!.reportError(error, stackTrace, 
                                                  context: context));
      return null;
    }
  }

  /// ネットワークエラーの処理
  Future<bool> handleNetworkError(Object error) async {
    if (_errorHandlingService == null) return false;
    return await _errorHandlingService!.handleNetworkError(error);
  }

  /// データ不整合の修復
  Future<void> repairDataInconsistency() async {
    if (_errorHandlingService == null) return;
    await _errorHandlingService!.repairDataInconsistency();
  }

  /// エラーハンドリングリソースの解放
  void disposeErrorHandling() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _errorHandlingService?.dispose();
    _errorHandlingService = null;
  }

  // 継承クラスで実装する必要があるメソッド

  /// 現在のゲーム状態を取得（継承クラスで実装）
  GameStateSnapshot? getCurrentGameState();

  /// ゲーム状態が復元された時の処理（継承クラスで実装）
  Future<void> onGameStateRestored(GameStateSnapshot savedState);

  /// トーストメッセージの表示（継承クラスで実装）
  void showToastMessage(String message, IconData icon, Color color);
}