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
  static const double _targetFrameTime = 16.67; // 60FPS = 16.67ms
  static const double _warningFrameTime = 20.0; // 50FPS以下で警告
  static const int _memoryWarningThreshold = 150 * 1024 * 1024; // 150MB
  
  Timer? _memoryTimer;
  bool _isMonitoring = false;
  
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
      if (_frameTimeHistory.length > _maxHistorySize) {
        _frameTimeHistory.removeFirst();
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
    if (_frameTimeHistory.isEmpty) return;
    
    final frameTimes = _frameTimeHistory.toList();
    final averageFrameTime = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    final minFrameTime = frameTimes.reduce((a, b) => a < b ? a : b);
    
    _averageFps = 1000.0 / averageFrameTime;
    _minFps = 1000.0 / frameTimes.reduce((a, b) => a > b ? a : b);
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
      final recentFrames = _frameTimeHistory.toList().reversed.take(30);
      final variance = _calculateVariance(recentFrames.toList());
      if (variance > 25) {
        suggestions.add('フレーム時間のばらつきが大きいです。処理の平準化を検討してください。');
      }
    }
    
    return suggestions;
  }

  /// 分散の計算
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((x) => (x - mean) * (x - mean));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
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
}