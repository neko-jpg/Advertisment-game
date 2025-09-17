import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// バッテリー最適化システム - 消費電力を最小化
class BatteryOptimizer {
  static final BatteryOptimizer _instance = BatteryOptimizer._internal();
  factory BatteryOptimizer() => _instance;
  BatteryOptimizer._internal();

  // バッテリー状態
  int _batteryLevel = 100;
  bool _isCharging = false;
  bool _isLowPowerMode = false;
  
  // 最適化設定
  bool _enableAdaptiveFrameRate = true;
  bool _enableBackgroundThrottling = true;
  bool _enableHapticOptimization = true;
  bool _enableAudioOptimization = true;
  
  // フレームレート制御
  double _targetFrameRate = 60.0;
  double _currentFrameRate = 60.0;
  
  // タイマー
  Timer? _batteryCheckTimer;
  Timer? _optimizationTimer;
  
  // コールバック
  VoidCallback? _onLowBattery;
  VoidCallback? _onPowerModeChanged;

  /// バッテリー最適化開始
  void startOptimization({
    VoidCallback? onLowBattery,
    VoidCallback? onPowerModeChanged,
  }) {
    _onLowBattery = onLowBattery;
    _onPowerModeChanged = onPowerModeChanged;
    
    // バッテリー状態の定期チェック（30秒間隔）
    _batteryCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkBatteryStatus(),
    );
    
    // 最適化の定期実行（5秒間隔）
    _optimizationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _applyOptimizations(),
    );
    
    // 初回チェック
    _checkBatteryStatus();
    
    debugPrint('BatteryOptimizer: 最適化開始');
  }

  /// バッテリー最適化停止
  void stopOptimization() {
    _batteryCheckTimer?.cancel();
    _optimizationTimer?.cancel();
    _batteryCheckTimer = null;
    _optimizationTimer = null;
    
    debugPrint('BatteryOptimizer: 最適化停止');
  }

  /// バッテリー状態のチェック
  Future<void> _checkBatteryStatus() async {
    try {
      // プラットフォーム固有のバッテリー情報取得
      if (Platform.isAndroid || Platform.isIOS) {
        const platform = MethodChannel('battery_optimization');
        
        final batteryInfo = await platform.invokeMethod('getBatteryInfo');
        if (batteryInfo != null) {
          final oldLevel = _batteryLevel;
          final oldCharging = _isCharging;
          
          _batteryLevel = batteryInfo['level'] ?? 100;
          _isCharging = batteryInfo['isCharging'] ?? false;
          
          // 低バッテリー警告
          if (_batteryLevel <= 20 && oldLevel > 20) {
            _isLowPowerMode = true;
            _onLowBattery?.call();
            debugPrint('BatteryOptimizer: 低バッテリーモード有効');
          }
          
          // 充電状態変化
          if (_isCharging != oldCharging) {
            _onPowerModeChanged?.call();
            debugPrint('BatteryOptimizer: 充電状態変化 - $_isCharging');
          }
          
          // バッテリーレベルが回復した場合
          if (_batteryLevel > 30 && _isLowPowerMode) {
            _isLowPowerMode = false;
            debugPrint('BatteryOptimizer: 低バッテリーモード解除');
          }
        }
      }
    } catch (e) {
      debugPrint('BatteryOptimizer: バッテリー情報取得エラー: $e');
      // フォールバック：デフォルト値を使用
      _batteryLevel = 50;
      _isCharging = false;
    }
  }

  /// 最適化の適用
  void _applyOptimizations() {
    if (_enableAdaptiveFrameRate) {
      _adjustFrameRate();
    }
    
    if (_enableBackgroundThrottling) {
      _applyBackgroundThrottling();
    }
  }

  /// フレームレートの動的調整
  void _adjustFrameRate() {
    double newTargetFrameRate = 60.0;
    
    if (_isLowPowerMode) {
      // 低バッテリー時は30FPSに制限
      newTargetFrameRate = 30.0;
    } else if (_batteryLevel < 50 && !_isCharging) {
      // バッテリー50%以下で充電していない場合は45FPSに制限
      newTargetFrameRate = 45.0;
    } else if (_isCharging) {
      // 充電中は60FPS維持
      newTargetFrameRate = 60.0;
    }
    
    if (newTargetFrameRate != _targetFrameRate) {
      _targetFrameRate = newTargetFrameRate;
      debugPrint('BatteryOptimizer: フレームレート調整 - ${_targetFrameRate}FPS');
    }
  }

  /// バックグラウンド処理の制限
  void _applyBackgroundThrottling() {
    if (_isLowPowerMode) {
      // 低バッテリー時は非必須処理を停止
      debugPrint('BatteryOptimizer: バックグラウンド処理制限中');
    }
  }

  /// ハプティックフィードバックの最適化
  bool shouldEnableHaptic() {
    if (!_enableHapticOptimization) return true;
    
    // 低バッテリー時はハプティックを無効化
    return !_isLowPowerMode;
  }

  /// オーディオ処理の最適化
  bool shouldEnableAudio() {
    if (!_enableAudioOptimization) return true;
    
    // 極低バッテリー時（10%以下）はオーディオを無効化
    return _batteryLevel > 10;
  }

  /// CPU使用率の制限
  bool shouldLimitCpuUsage() {
    return _isLowPowerMode || (_batteryLevel < 30 && !_isCharging);
  }

  /// GPU使用率の制限
  bool shouldLimitGpuUsage() {
    return _isLowPowerMode || (_batteryLevel < 20 && !_isCharging);
  }

  /// ネットワーク使用の制限
  bool shouldLimitNetworkUsage() {
    return _isLowPowerMode;
  }

  /// 画面輝度の推奨値
  double getRecommendedBrightness() {
    if (_isLowPowerMode) {
      return 0.3; // 30%
    } else if (_batteryLevel < 50 && !_isCharging) {
      return 0.5; // 50%
    }
    return 1.0; // 100%
  }

  /// バッテリー効率的な更新間隔の取得
  Duration getOptimalUpdateInterval() {
    if (_isLowPowerMode) {
      return const Duration(milliseconds: 33); // 30FPS
    } else if (_batteryLevel < 50 && !_isCharging) {
      return const Duration(milliseconds: 22); // 45FPS
    }
    return const Duration(milliseconds: 16); // 60FPS
  }

  /// 省電力プロファイルの適用
  void applyPowerSavingProfile(PowerSavingLevel level) {
    switch (level) {
      case PowerSavingLevel.none:
        _targetFrameRate = 60.0;
        _enableAdaptiveFrameRate = true;
        _enableBackgroundThrottling = false;
        _enableHapticOptimization = false;
        _enableAudioOptimization = false;
        break;
        
      case PowerSavingLevel.moderate:
        _targetFrameRate = 45.0;
        _enableAdaptiveFrameRate = true;
        _enableBackgroundThrottling = true;
        _enableHapticOptimization = true;
        _enableAudioOptimization = false;
        break;
        
      case PowerSavingLevel.aggressive:
        _targetFrameRate = 30.0;
        _enableAdaptiveFrameRate = true;
        _enableBackgroundThrottling = true;
        _enableHapticOptimization = true;
        _enableAudioOptimization = true;
        break;
    }
    
    debugPrint('BatteryOptimizer: 省電力プロファイル適用 - $level');
  }

  /// 最適化設定の更新
  void updateOptimizationSettings({
    bool? enableAdaptiveFrameRate,
    bool? enableBackgroundThrottling,
    bool? enableHapticOptimization,
    bool? enableAudioOptimization,
  }) {
    _enableAdaptiveFrameRate = enableAdaptiveFrameRate ?? _enableAdaptiveFrameRate;
    _enableBackgroundThrottling = enableBackgroundThrottling ?? _enableBackgroundThrottling;
    _enableHapticOptimization = enableHapticOptimization ?? _enableHapticOptimization;
    _enableAudioOptimization = enableAudioOptimization ?? _enableAudioOptimization;
    
    debugPrint('BatteryOptimizer: 設定更新完了');
  }

  // Getters
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  bool get isLowPowerMode => _isLowPowerMode;
  double get targetFrameRate => _targetFrameRate;
  double get currentFrameRate => _currentFrameRate;

  /// バッテリー統計の取得
  Map<String, dynamic> getBatteryStatistics() {
    return {
      'batteryLevel': _batteryLevel,
      'isCharging': _isCharging,
      'isLowPowerMode': _isLowPowerMode,
      'targetFrameRate': _targetFrameRate,
      'currentFrameRate': _currentFrameRate,
      'optimizationSettings': {
        'adaptiveFrameRate': _enableAdaptiveFrameRate,
        'backgroundThrottling': _enableBackgroundThrottling,
        'hapticOptimization': _enableHapticOptimization,
        'audioOptimization': _enableAudioOptimization,
      },
      'recommendations': {
        'shouldLimitCpu': shouldLimitCpuUsage(),
        'shouldLimitGpu': shouldLimitGpuUsage(),
        'shouldLimitNetwork': shouldLimitNetworkUsage(),
        'recommendedBrightness': getRecommendedBrightness(),
        'optimalUpdateInterval': getOptimalUpdateInterval().inMilliseconds,
      },
    };
  }

  /// リソースの解放
  void dispose() {
    stopOptimization();
  }
}

/// 省電力レベル
enum PowerSavingLevel {
  none,      // 省電力なし
  moderate,  // 中程度の省電力
  aggressive, // 積極的な省電力
}