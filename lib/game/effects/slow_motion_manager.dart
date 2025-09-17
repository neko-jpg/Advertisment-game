import 'dart:math' as math;
import 'package:flutter/material.dart';

/// スローモーション管理システム - 時間減速効果と精密描画モード
class SlowMotionManager {
  // スローモーション状態
  bool _isActive = false;
  double _currentFactor = 1.0;
  double _targetFactor = 1.0;
  double _duration = 0.0;
  double _remainingTime = 0.0;
  
  // トランジション
  double _transitionSpeed = 5.0;
  
  // 視覚効果
  double _chromaticAberration = 0.0;
  double _vignette = 0.0;
  Color _tintColor = Colors.blue;
  
  // 音響効果（将来の拡張用）
  double _pitchShift = 1.0;
  
  SlowMotionManager();
  
  /// スローモーション開始
  void startSlowMotion({
    double factor = 0.3,
    double duration = 2.0,
    SlowMotionType type = SlowMotionType.precision,
  }) {
    _isActive = true;
    _targetFactor = math.max(0.1, math.min(1.0, factor));
    _duration = duration;
    _remainingTime = duration;
    
    // タイプ別設定
    switch (type) {
      case SlowMotionType.precision:
        _tintColor = Colors.blue;
        _transitionSpeed = 8.0;
        break;
      case SlowMotionType.dramatic:
        _tintColor = Colors.purple;
        _transitionSpeed = 3.0;
        break;
      case SlowMotionType.danger:
        _tintColor = Colors.red;
        _transitionSpeed = 10.0;
        break;
    }
  }
  
  /// スローモーション終了
  void stopSlowMotion() {
    _targetFactor = 1.0;
    _remainingTime = 0.0;
  }
  
  /// 強制終了
  void forceStop() {
    _isActive = false;
    _currentFactor = 1.0;
    _targetFactor = 1.0;
    _remainingTime = 0.0;
    _chromaticAberration = 0.0;
    _vignette = 0.0;
    _pitchShift = 1.0;
  }
  
  /// 更新処理
  void update(double deltaTime) {
    if (!_isActive && _currentFactor >= 0.99) return;
    
    // 残り時間更新
    if (_remainingTime > 0) {
      _remainingTime -= deltaTime;
      if (_remainingTime <= 0) {
        _targetFactor = 1.0;
      }
    }
    
    // ファクター補間
    final factorDiff = _targetFactor - _currentFactor;
    if (factorDiff.abs() > 0.01) {
      _currentFactor += factorDiff * _transitionSpeed * deltaTime;
    } else {
      _currentFactor = _targetFactor;
    }
    
    // 非アクティブ判定
    if (_currentFactor >= 0.99 && _targetFactor >= 0.99) {
      _isActive = false;
      _currentFactor = 1.0;
    }
    
    // 視覚効果更新
    _updateVisualEffects();
  }
  
  void _updateVisualEffects() {
    final intensity = 1.0 - _currentFactor; // スローほど強い効果
    
    // 色収差効果
    _chromaticAberration = intensity * 0.3;
    
    // ビネット効果
    _vignette = intensity * 0.4;
    
    // 音響ピッチシフト
    _pitchShift = 0.7 + (_currentFactor * 0.3);
  }
  
  /// スローモーション用の調整されたデルタタイムを取得
  double getAdjustedDeltaTime(double deltaTime) {
    return deltaTime * _currentFactor;
  }
  
  /// UI用の調整されたデルタタイムを取得（UIは通常速度を維持）
  double getUIDeltaTime(double deltaTime) {
    return deltaTime; // UIは常に通常速度
  }
  
  /// 視覚効果を描画
  void renderEffects(Canvas canvas, Size size) {
    if (!_isActive && _currentFactor >= 0.99) return;
    
    final intensity = 1.0 - _currentFactor;
    
    // ビネット効果
    if (_vignette > 0) {
      _renderVignette(canvas, size, intensity);
    }
    
    // 色収差効果（簡易版）
    if (_chromaticAberration > 0) {
      _renderChromaticAberration(canvas, size, intensity);
    }
    
    // 色調効果
    _renderColorTint(canvas, size, intensity);
  }
  
  void _renderVignette(Canvas canvas, Size size, double intensity) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.8;
    
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(intensity * 0.6),
      ],
      stops: const [0.3, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  
  void _renderChromaticAberration(Canvas canvas, Size size, double intensity) {
    // 簡易色収差効果（境界にカラーフリンジ）
    final paint = Paint()
      ..color = _tintColor.withOpacity(intensity * 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);
  }
  
  void _renderColorTint(Canvas canvas, Size size, double intensity) {
    final paint = Paint()
      ..color = _tintColor.withOpacity(intensity * 0.15)
      ..blendMode = BlendMode.overlay;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  
  // Getters
  bool get isActive => _isActive;
  double get currentFactor => _currentFactor;
  double get remainingTime => _remainingTime;
  double get duration => _duration;
  double get progress => _duration > 0 ? 1.0 - (_remainingTime / _duration) : 1.0;
  double get pitchShift => _pitchShift;
  
  /// スローモーション強度を取得（0.0-1.0）
  double get intensity => 1.0 - _currentFactor;
  
  /// 精密モードかどうか
  bool get isPrecisionMode => _isActive && _currentFactor < 0.8;
}

/// スローモーションタイプ
enum SlowMotionType {
  precision,  // 精密描画用
  dramatic,   // 演出用
  danger,     // 危険回避用
}