import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 動的カメラシステム - プレイヤー追従とエフェクト管理
class DynamicCameraSystem {
  // カメラ位置とターゲット
  Offset _position = Offset.zero;
  Offset _target = Offset.zero;
  Offset _velocity = Offset.zero;
  
  // 追従設定
  double _followSpeed = 0.1;
  double _maxFollowDistance = 200.0;
  double _predictionFactor = 0.3;
  double _dampingFactor = 0.8;
  
  // 境界制限
  Rect? _bounds;
  EdgeInsets _safeArea = const EdgeInsets.all(50);
  
  // エフェクト状態
  bool _isShaking = false;
  double _shakeIntensity = 0.0;
  double _shakeDuration = 0.0;
  double _shakeTimer = 0.0;
  Offset _shakeOffset = Offset.zero;
  
  bool _isZooming = false;
  double _currentZoom = 1.0;
  double _targetZoom = 1.0;
  double _zoomSpeed = 0.05;
  
  // 視差効果
  final List<ParallaxLayer> _parallaxLayers = [];
  
  // ゲッター
  Offset get position => _position + _shakeOffset;
  Offset get target => _target;
  double get zoom => _currentZoom;
  bool get isShaking => _isShaking;
  bool get isZooming => _isZooming;
  
  /// カメラシステム初期化
  void initialize({
    Offset? initialPosition,
    Rect? bounds,
    EdgeInsets? safeArea,
  }) {
    _position = initialPosition ?? Offset.zero;
    _target = _position;
    _bounds = bounds;
    _safeArea = safeArea ?? const EdgeInsets.all(50);
    
    // デフォルト視差レイヤーを追加
    _initializeParallaxLayers();
  }
  
  /// 視差レイヤーの初期化
  void _initializeParallaxLayers() {
    _parallaxLayers.clear();
    
    // 背景レイヤー（遠景）
    _parallaxLayers.add(ParallaxLayer(
      depth: 0.1,
      speed: 0.2,
      offset: Offset.zero,
    ));
    
    // 中景レイヤー
    _parallaxLayers.add(ParallaxLayer(
      depth: 0.5,
      speed: 0.6,
      offset: Offset.zero,
    ));
    
    // 近景レイヤー
    _parallaxLayers.add(ParallaxLayer(
      depth: 0.8,
      speed: 0.9,
      offset: Offset.zero,
    ));
  }
  
  /// カメラ更新（メインループから呼び出し）
  void update(double deltaTime) {
    _updateSmoothFollow(deltaTime);
    _updateShakeEffect(deltaTime);
    _updateZoomEffect(deltaTime);
    _updateParallaxLayers(deltaTime);
    _applyBoundaryConstraints();
  }
  
  /// スムーズ追従アルゴリズム
  void _updateSmoothFollow(double deltaTime) {
    if (_target == Offset.zero) return;
    
    // ターゲットとの距離を計算
    final distance = (_target - _position).distance;
    
    // 予測移動を計算（プレイヤーの移動方向を予測）
    final predictedTarget = _target + (_velocity * _predictionFactor);
    
    // 追従速度を距離に応じて調整
    double adaptiveSpeed = _followSpeed;
    if (distance > _maxFollowDistance) {
      adaptiveSpeed = _followSpeed * (1.0 + (distance - _maxFollowDistance) / 100.0);
    }
    
    // スムーズな移動計算
    final targetDirection = predictedTarget - _position;
    final moveDistance = targetDirection.distance * adaptiveSpeed * deltaTime * 60;
    
    if (targetDirection.distance > 0.1) {
      final normalizedDirection = Offset(
        targetDirection.dx / targetDirection.distance,
        targetDirection.dy / targetDirection.distance,
      );
      
      // 慣性システム適用
      _velocity = _velocity * _dampingFactor + 
                  (normalizedDirection * moveDistance) * (1.0 - _dampingFactor);
      
      _position = Offset(
        _position.dx + _velocity.dx,
        _position.dy + _velocity.dy,
      );
    } else {
      // ターゲットに近い場合は慣性を減衰
      _velocity = _velocity * _dampingFactor;
    }
  }
  
  /// 境界制限の適用
  void _applyBoundaryConstraints() {
    if (_bounds == null) return;
    
    final constrainedX = _position.dx.clamp(
      _bounds!.left + _safeArea.left,
      _bounds!.right - _safeArea.right,
    );
    
    final constrainedY = _position.dy.clamp(
      _bounds!.top + _safeArea.top,
      _bounds!.bottom - _safeArea.bottom,
    );
    
    _position = Offset(constrainedX, constrainedY);
  }
  
  /// カメラターゲット設定
  void setTarget(Offset target, {Offset? velocity}) {
    _target = target;
    if (velocity != null) {
      _velocity = velocity;
    }
  }
  
  /// 境界設定
  void setBounds(Rect bounds, {EdgeInsets? safeArea}) {
    _bounds = bounds;
    if (safeArea != null) {
      _safeArea = safeArea;
    }
  }
  
  /// 追従設定の調整
  void configureFollow({
    double? followSpeed,
    double? maxFollowDistance,
    double? predictionFactor,
    double? dampingFactor,
  }) {
    _followSpeed = followSpeed ?? _followSpeed;
    _maxFollowDistance = maxFollowDistance ?? _maxFollowDistance;
    _predictionFactor = predictionFactor ?? _predictionFactor;
    _dampingFactor = dampingFactor ?? _dampingFactor;
  }
  
  /// 振動エフェクト更新
  void _updateShakeEffect(double deltaTime) {
    if (!_isShaking) return;
    
    _shakeTimer += deltaTime;
    
    if (_shakeTimer >= _shakeDuration) {
      _stopShake();
      return;
    }
    
    // 振動の減衰計算
    final progress = _shakeTimer / _shakeDuration;
    final currentIntensity = _shakeIntensity * (1.0 - progress);
    
    // ランダムな振動オフセット生成
    final random = math.Random();
    _shakeOffset = Offset(
      (random.nextDouble() - 0.5) * currentIntensity * 2,
      (random.nextDouble() - 0.5) * currentIntensity * 2,
    );
  }
  
  /// ズームエフェクト更新
  void _updateZoomEffect(double deltaTime) {
    if (!_isZooming) return;
    
    final zoomDifference = _targetZoom - _currentZoom;
    if (zoomDifference.abs() < 0.01) {
      _currentZoom = _targetZoom;
      _isZooming = false;
      return;
    }
    
    _currentZoom += zoomDifference * _zoomSpeed * deltaTime * 60;
  }
  
  /// 視差レイヤー更新
  void _updateParallaxLayers(double deltaTime) {
    final cameraMovement = _velocity * deltaTime;
    
    for (final layer in _parallaxLayers) {
      layer.offset = Offset(
        layer.offset.dx + cameraMovement.dx * layer.speed,
        layer.offset.dy + cameraMovement.dy * layer.speed,
      );
    }
  }
  
  /// 振動エフェクト開始
  void startShake({
    required double intensity,
    required double duration,
  }) {
    _isShaking = true;
    _shakeIntensity = intensity;
    _shakeDuration = duration;
    _shakeTimer = 0.0;
  }
  
  /// 振動エフェクト停止
  void _stopShake() {
    _isShaking = false;
    _shakeOffset = Offset.zero;
    _shakeTimer = 0.0;
  }
  
  /// ズームエフェクト開始
  void startZoom({
    required double targetZoom,
    double? speed,
  }) {
    _isZooming = true;
    _targetZoom = targetZoom.clamp(0.5, 3.0);
    _zoomSpeed = speed ?? 0.05;
  }
  
  /// ズームリセット
  void resetZoom({double? speed}) {
    startZoom(targetZoom: 1.0, speed: speed);
  }
  
  /// 視差レイヤー取得
  List<ParallaxLayer> getParallaxLayers() => List.unmodifiable(_parallaxLayers);
  
  /// カメラリセット
  void reset() {
    _position = Offset.zero;
    _target = Offset.zero;
    _velocity = Offset.zero;
    _stopShake();
    _currentZoom = 1.0;
    _targetZoom = 1.0;
    _isZooming = false;
    
    for (final layer in _parallaxLayers) {
      layer.offset = Offset.zero;
    }
  }
  
  /// ワールド座標をスクリーン座標に変換
  Offset worldToScreen(Offset worldPosition, Size screenSize) {
    final cameraOffset = position;
    final zoomedPosition = Offset(
      (worldPosition.dx - cameraOffset.dx) * _currentZoom,
      (worldPosition.dy - cameraOffset.dy) * _currentZoom,
    );
    
    return Offset(
      zoomedPosition.dx + screenSize.width / 2,
      zoomedPosition.dy + screenSize.height / 2,
    );
  }
  
  /// スクリーン座標をワールド座標に変換
  Offset screenToWorld(Offset screenPosition, Size screenSize) {
    final centeredPosition = Offset(
      screenPosition.dx - screenSize.width / 2,
      screenPosition.dy - screenSize.height / 2,
    );
    
    final unzoomedPosition = Offset(
      centeredPosition.dx / _currentZoom,
      centeredPosition.dy / _currentZoom,
    );
    
    return unzoomedPosition + position;
  }
}

/// 視差効果用レイヤー
class ParallaxLayer {
  final double depth;
  final double speed;
  Offset offset;
  
  ParallaxLayer({
    required this.depth,
    required this.speed,
    this.offset = Offset.zero,
  });
}