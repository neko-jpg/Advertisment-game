import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// パフォーマンス監視システム - 60FPS維持とメモリ使用量を監視
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Queue<double> _frameTimeHistory = Queue<double>();
  final Queue<int> _memoryHistory = Queue<int>();

  static const int _maxHistorySize = 120; // 2秒分のフレーム履歴
  static const double _warningFrameTime = 20.0; // 50FPS以下で警告
  static const int _memoryWarningThreshold = 150 * 1024 * 1024; // 150MB

  Timer? _memoryTimer;
  bool _isMonitoring = false;

  double _frameTimeSum = 0.0;
  double _frameTimeMax = 0.0;

  // パフォーマンス統計
  double _averageFps = 60.0;
  double _minFps = 60.0;
  int _droppedFrames = 0;
  int _currentMemoryUsage = 0;
  int _peakMemoryUsage = 0;
  
  // コールバック
  VoidCallback? _onPerformanceWarning;
  VoidCallback? _onMemoryWarning;

  /// 監視開始
  void startMonitoring({
    VoidCallback? onPerformanceWarning,
    VoidCallback? onMemoryWarning,
  }) {
    if (_isMonitoring) return;
    
    _onPerformanceWarning = onPerformanceWarning;
    _onMemoryWarning = onMemoryWarning;
    _isMonitoring = true;
    
    // フレーム時間監視
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    
    // メモリ使用量監視（1秒間隔）
    _memoryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateMemoryUsage();
    });
    
    debugPrint('PerformanceMonitor: 監視開始');
  }

  /// 監視停止
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _memoryTimer?.cancel();
    _memoryTimer = null;
    
    debugPrint('PerformanceMonitor: 監視停止');
  }

  /// フレーム時間の処理
  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_isMonitoring) return;
    
    for (final timing in timings) {
      final frameTime = timing.totalSpan.inMicroseconds / 1000.0; // ms
      
      _frameTimeHistory.add(frameTime);
      _frameTimeSum += frameTime;
      if (frameTime > _frameTimeMax) {
        _frameTimeMax = frameTime;
      }
      if (_frameTimeHistory.length > _maxHistorySize) {
        final removed = _frameTimeHistory.removeFirst();
        _frameTimeSum -= removed;
        if (_frameTimeHistory.isEmpty) {
          _frameTimeMax = 0.0;
        } else if (removed == _frameTimeMax) {
          _recalculateFrameExtrema();
        }
      }

      // フレームドロップ検知
      if (frameTime > _warningFrameTime) {
        _droppedFrames++;
        if (_droppedFrames % 10 == 0) { // 10フレーム毎に警告
          _onPerformanceWarning?.call();
        }
      }
    }
    
    _updateFpsStatistics();
  }

  /// FPS統計の更新
  void _updateFpsStatistics() {
    final count = _frameTimeHistory.length;
    if (count == 0) {
      return;
    }

    final averageFrameTime = _frameTimeSum / count;
    final worstFrameTime = _frameTimeMax == 0.0 ? averageFrameTime : _frameTimeMax;

    _averageFps = 1000.0 / averageFrameTime;
    _minFps = 1000.0 / worstFrameTime;
  }

  void _recalculateFrameExtrema() {
    var maxFrame = 0.0;
    for (final value in _frameTimeHistory) {
      if (value > maxFrame) {
        maxFrame = value;
      }
    }
    _frameTimeMax = maxFrame;
  }

  /// メモリ使用量の更新
  void _updateMemoryUsage() {
    if (!_isMonitoring) return;
    
    try {
      final info = ProcessInfo.currentRss;
      _currentMemoryUsage = info;
      
      if (info > _peakMemoryUsage) {
        _peakMemoryUsage = info;
      }
      
      _memoryHistory.add(info);
      if (_memoryHistory.length > 60) { // 1分間の履歴
        _memoryHistory.removeFirst();
      }
      
      // メモリ警告
      if (info > _memoryWarningThreshold) {
        _onMemoryWarning?.call();
      }
      
    } catch (e) {
      debugPrint('PerformanceMonitor: メモリ情報取得エラー: $e');
    }
  }

  /// パフォーマンス最適化の提案
  List<String> getOptimizationSuggestions() {
    final suggestions = <String>[];
    
    if (_averageFps < 55) {
      suggestions.add('フレームレートが低下しています。レンダリング負荷を軽減してください。');
    }
    
    if (_droppedFrames > 30) {
      suggestions.add('フレームドロップが多発しています。更新頻度を調整してください。');
    }
    
    if (_currentMemoryUsage > _memoryWarningThreshold) {
      suggestions.add('メモリ使用量が高くなっています。不要なオブジェクトを解放してください。');
    }
    
    if (_frameTimeHistory.isNotEmpty) {
      final frames = _frameTimeHistory.toList(growable: false);
      var count = 0;
      var mean = 0.0;
      var m2 = 0.0;
      for (var i = frames.length - 1; i >= 0 && count < 30; i--) {
        final value = frames[i];
        count++;
        final delta = value - mean;
        mean += delta / count;
        final delta2 = value - mean;
        m2 += delta * delta2;
      }
      final variance = count > 0 ? m2 / count : 0.0;
      if (variance > 25) {
        suggestions.add('フレーム時間のばらつきが大きいです。処理の平準化を検討してください。');
      }
    }
    
    return suggestions;
  }

  /// 強制ガベージコレクション（デバッグ用）
  void forceGarbageCollection() {
    if (kDebugMode) {
      developer.Service.getInfo().then((_) {
        debugPrint('PerformanceMonitor: ガベージコレクション実行');
      });
    }
  }

  // Getters
  bool get isMonitoring => _isMonitoring;
  double get averageFps => _averageFps;
  double get minFps => _minFps;
  int get droppedFrames => _droppedFrames;
  int get currentMemoryUsageMB => (_currentMemoryUsage / (1024 * 1024)).round();
  int get peakMemoryUsageMB => (_peakMemoryUsage / (1024 * 1024)).round();
  
  /// パフォーマンス統計のリセット
  void resetStatistics() {
    _frameTimeHistory.clear();
    _memoryHistory.clear();
    _droppedFrames = 0;
    _peakMemoryUsage = 0;
    _averageFps = 60.0;
    _minFps = 60.0;
    _frameTimeSum = 0.0;
    _frameTimeMax = 0.0;
  }

  /// パフォーマンスレポートの生成
  Map<String, dynamic> generateReport() {
    return {
      'averageFps': _averageFps.toStringAsFixed(1),
      'minFps': _minFps.toStringAsFixed(1),
      'droppedFrames': _droppedFrames,
      'currentMemoryMB': currentMemoryUsageMB,
      'peakMemoryMB': peakMemoryUsageMB,
      'frameTimeHistory': _frameTimeHistory.length,
      'suggestions': getOptimizationSuggestions(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// リソースの解放
  void dispose() {
    stopMonitoring();
    _frameTimeHistory.clear();
  }
}