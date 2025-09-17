import 'dart:math' as math;
import 'package:flutter/material.dart';

/// カメラエフェクトの種類
enum CameraEffectType {
  shake,
  zoom,
  parallax,
  cinematic,
  impact,
}

/// カメラエフェクトシステム - 各種視覚効果の管理
class CameraEffectSystem {
  final List<CameraEffect> _activeEffects = [];
  
  /// アクティブなエフェクト一覧
  List<CameraEffect> get activeEffects => List.unmodifiable(_activeEffects);
  
  /// エフェクト更新
  void update(double deltaTime) {
    _activeEffects.removeWhere((effect) {
      effect.update(deltaTime);
      return effect.isFinished;
    });
  }
  
  /// 振動エフェクト追加
  void addShakeEffect({
    required double intensity,
    required double duration,
    ShakePattern pattern = ShakePattern.random,
    Curve curve = Curves.easeOut,
  }) {
    final effect = ShakeEffect(
      intensity: intensity,
      duration: duration,
      pattern: pattern,
      curve: curve,
    );
    _activeEffects.add(effect);
  }
  
  /// ズームエフェクト追加
  void addZoomEffect({
    required double targetZoom,
    required double duration,
    Curve curve = Curves.easeInOut,
  }) {
    final effect = ZoomEffect(
      targetZoom: targetZoom,
      duration: duration,
      curve: curve,
    );
    _activeEffects.add(effect);
  }
  
  /// 視差エフェクト追加
  void addParallaxEffect({
    required List<ParallaxLayer> layers,
    required double intensity,
  }) {
    final effect = ParallaxEffect(
      layers: layers,
      intensity: intensity,
    );
    _activeEffects.add(effect);
  }
  
  /// インパクトエフェクト追加（振動+ズーム+時間停止）
  void addImpactEffect({
    required double intensity,
    double duration = 0.3,
    double zoomAmount = 1.2,
  }) {
    // 振動エフェクト
    addShakeEffect(
      intensity: intensity * 15,
      duration: duration,
      pattern: ShakePattern.impact,
      curve: Curves.easeOut,
    );
    
    // ズームエフェクト
    addZoomEffect(
      targetZoom: zoomAmount,
      duration: duration * 0.5,
      curve: Curves.easeOut,
    );
    
    // ズーム戻し
    Future.delayed(Duration(milliseconds: (duration * 500).round()), () {
      addZoomEffect(
        targetZoom: 1.0,
        duration: duration * 0.5,
        curve: Curves.easeIn,
      );
    });
  }
  
  /// 全エフェクトの合成結果を取得
  CameraEffectResult getCombinedEffect() {
    var result = CameraEffectResult();
    
    for (final effect in _activeEffects) {
      result = result.combine(effect.getEffect());
    }
    
    return result;
  }
  
  /// 特定タイプのエフェクトを停止
  void stopEffectsByType(CameraEffectType type) {
    _activeEffects.removeWhere((effect) => effect.type == type);
  }
  
  /// 全エフェクトを停止
  void stopAllEffects() {
    _activeEffects.clear();
  }
  
  /// エフェクトが実行中かチェック
  bool hasActiveEffect(CameraEffectType type) {
    return _activeEffects.any((effect) => effect.type == type);
  }
}

/// カメラエフェクトの基底クラス
abstract class CameraEffect {
  final CameraEffectType type;
  final double duration;
  double _timer = 0.0;
  
  CameraEffect({
    required this.type,
    required this.duration,
  });
  
  /// エフェクトが終了したかどうか
  bool get isFinished => _timer >= duration;
  
  /// 進行度（0.0 - 1.0）
  double get progress => duration > 0 ? (_timer / duration).clamp(0.0, 1.0) : 1.0;
  
  /// エフェクト更新
  void update(double deltaTime) {
    _timer += deltaTime;
  }
  
  /// エフェクト結果を取得
  CameraEffectResult getEffect();
}

/// 振動エフェクト
class ShakeEffect extends CameraEffect {
  final double intensity;
  final ShakePattern pattern;
  final Curve curve;
  
  ShakeEffect({
    required this.intensity,
    required double duration,
    this.pattern = ShakePattern.random,
    this.curve = Curves.easeOut,
  }) : super(type: CameraEffectType.shake, duration: duration);
  
  @override
  CameraEffectResult getEffect() {
    if (isFinished) return CameraEffectResult();
    
    final curvedProgress = curve.transform(progress);
    final currentIntensity = intensity * (1.0 - curvedProgress);
    
    Offset shakeOffset;
    switch (pattern) {
      case ShakePattern.random:
        shakeOffset = _getRandomShake(currentIntensity);
        break;
      case ShakePattern.horizontal:
        shakeOffset = _getHorizontalShake(currentIntensity);
        break;
      case ShakePattern.vertical:
        shakeOffset = _getVerticalShake(currentIntensity);
        break;
      case ShakePattern.impact:
        shakeOffset = _getImpactShake(currentIntensity);
        break;
    }
    
    return CameraEffectResult(shakeOffset: shakeOffset);
  }
  
  Offset _getRandomShake(double intensity) {
    final random = math.Random();
    return Offset(
      (random.nextDouble() - 0.5) * intensity * 2,
      (random.nextDouble() - 0.5) * intensity * 2,
    );
  }
  
  Offset _getHorizontalShake(double intensity) {
    final random = math.Random();
    return Offset(
      (random.nextDouble() - 0.5) * intensity * 2,
      0,
    );
  }
  
  Offset _getVerticalShake(double intensity) {
    final random = math.Random();
    return Offset(
      0,
      (random.nextDouble() - 0.5) * intensity * 2,
    );
  }
  
  Offset _getImpactShake(double intensity) {
    final angle = math.Random().nextDouble() * 2 * math.pi;
    return Offset(
      math.cos(angle) * intensity,
      math.sin(angle) * intensity,
    );
  }
}

/// ズームエフェクト
class ZoomEffect extends CameraEffect {
  final double startZoom;
  final double targetZoom;
  final Curve curve;
  
  ZoomEffect({
    required this.targetZoom,
    required double duration,
    this.startZoom = 1.0,
    this.curve = Curves.easeInOut,
  }) : super(type: CameraEffectType.zoom, duration: duration);
  
  @override
  CameraEffectResult getEffect() {
    if (isFinished) {
      return CameraEffectResult(zoomMultiplier: targetZoom);
    }
    
    final curvedProgress = curve.transform(progress);
    final currentZoom = startZoom + (targetZoom - startZoom) * curvedProgress;
    
    return CameraEffectResult(zoomMultiplier: currentZoom);
  }
}

/// 視差エフェクト
class ParallaxEffect extends CameraEffect {
  final List<ParallaxLayer> layers;
  final double intensity;
  
  ParallaxEffect({
    required this.layers,
    required this.intensity,
  }) : super(type: CameraEffectType.parallax, duration: double.infinity);
  
  @override
  CameraEffectResult getEffect() {
    return CameraEffectResult(
      parallaxLayers: layers,
      parallaxIntensity: intensity,
    );
  }
}

/// 振動パターン
enum ShakePattern {
  random,
  horizontal,
  vertical,
  impact,
}

/// カメラエフェクトの結果
class CameraEffectResult {
  final Offset shakeOffset;
  final double zoomMultiplier;
  final List<ParallaxLayer>? parallaxLayers;
  final double parallaxIntensity;
  final Color? overlayColor;
  final double overlayOpacity;
  
  CameraEffectResult({
    this.shakeOffset = Offset.zero,
    this.zoomMultiplier = 1.0,
    this.parallaxLayers,
    this.parallaxIntensity = 1.0,
    this.overlayColor,
    this.overlayOpacity = 0.0,
  });
  
  /// 複数のエフェクト結果を合成
  CameraEffectResult combine(CameraEffectResult other) {
    return CameraEffectResult(
      shakeOffset: shakeOffset + other.shakeOffset,
      zoomMultiplier: zoomMultiplier * other.zoomMultiplier,
      parallaxLayers: other.parallaxLayers ?? parallaxLayers,
      parallaxIntensity: parallaxIntensity * other.parallaxIntensity,
      overlayColor: other.overlayColor ?? overlayColor,
      overlayOpacity: (overlayOpacity + other.overlayOpacity).clamp(0.0, 1.0),
    );
  }
}

/// 視差レイヤー（camera_system.dartから移動）
class ParallaxLayer {
  final double depth;
  final double speed;
  Offset offset;
  final String? texturePath;
  final Color? tintColor;
  
  ParallaxLayer({
    required this.depth,
    required this.speed,
    this.offset = Offset.zero,
    this.texturePath,
    this.tintColor,
  });
  
  /// レイヤーの更新
  void update(Offset cameraMovement) {
    offset = Offset(
      offset.dx + cameraMovement.dx * speed,
      offset.dy + cameraMovement.dy * speed,
    );
  }
  
  /// レイヤーのリセット
  void reset() {
    offset = Offset.zero;
  }
}

/// プリセットエフェクト集
class CameraEffectPresets {
  /// 軽い振動（UI操作時）
  static void lightShake(CameraEffectSystem system) {
    system.addShakeEffect(
      intensity: 2.0,
      duration: 0.1,
      pattern: ShakePattern.random,
    );
  }
  
  /// 中程度の振動（衝突時）
  static void mediumShake(CameraEffectSystem system) {
    system.addShakeEffect(
      intensity: 8.0,
      duration: 0.3,
      pattern: ShakePattern.impact,
    );
  }
  
  /// 強い振動（爆発時）
  static void heavyShake(CameraEffectSystem system) {
    system.addShakeEffect(
      intensity: 15.0,
      duration: 0.5,
      pattern: ShakePattern.random,
    );
  }
  
  /// パンチインズーム（スコア獲得時）
  static void punchInZoom(CameraEffectSystem system) {
    system.addZoomEffect(
      targetZoom: 1.1,
      duration: 0.2,
      curve: Curves.easeOut,
    );
    
    Future.delayed(const Duration(milliseconds: 200), () {
      system.addZoomEffect(
        targetZoom: 1.0,
        duration: 0.3,
        curve: Curves.easeIn,
      );
    });
  }
  
  /// スローモーションズーム（特殊技発動時）
  static void slowMotionZoom(CameraEffectSystem system) {
    system.addZoomEffect(
      targetZoom: 1.3,
      duration: 0.8,
      curve: Curves.easeInOut,
    );
  }
  
  /// インパクトコンボ（大きな衝撃時）
  static void impactCombo(CameraEffectSystem system) {
    system.addImpactEffect(
      intensity: 1.0,
      duration: 0.4,
      zoomAmount: 1.15,
    );
  }
  
  /// ボス登場演出
  static void bossEntrance(CameraEffectSystem system) {
    // 強い振動
    system.addShakeEffect(
      intensity: 20.0,
      duration: 1.0,
      pattern: ShakePattern.impact,
      curve: Curves.easeOut,
    );
    
    // ズームアウト→ズームイン
    system.addZoomEffect(
      targetZoom: 0.8,
      duration: 0.5,
      curve: Curves.easeOut,
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      system.addZoomEffect(
        targetZoom: 1.0,
        duration: 0.5,
        curve: Curves.easeIn,
      );
    });
  }
}