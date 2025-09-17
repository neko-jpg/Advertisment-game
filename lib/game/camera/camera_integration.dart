import 'package:flutter/material.dart';
import 'camera_system.dart';
import 'camera_effects.dart';

/// カメラ統合システム - カメラとエフェクトの統合管理
class CameraIntegration {
  late final DynamicCameraSystem _cameraSystem;
  late final CameraEffectSystem _effectSystem;
  
  // 統合状態
  Offset _finalPosition = Offset.zero;
  double _finalZoom = 1.0;
  
  /// コンストラクタ
  CameraIntegration() {
    _cameraSystem = DynamicCameraSystem();
    _effectSystem = CameraEffectSystem();
  }
  
  /// ゲッター
  DynamicCameraSystem get cameraSystem => _cameraSystem;
  CameraEffectSystem get effectSystem => _effectSystem;
  Offset get position => _finalPosition;
  double get zoom => _finalZoom;
  
  /// 初期化
  void initialize({
    Offset? initialPosition,
    Rect? bounds,
    EdgeInsets? safeArea,
  }) {
    _cameraSystem.initialize(
      initialPosition: initialPosition,
      bounds: bounds,
      safeArea: safeArea,
    );
  }
  
  /// 更新（メインループから呼び出し）
  void update(double deltaTime) {
    // カメラシステム更新
    _cameraSystem.update(deltaTime);
    
    // エフェクトシステム更新
    _effectSystem.update(deltaTime);
    
    // 最終的な位置とズームを計算
    _calculateFinalTransform();
  }
  
  /// 最終的な変換を計算
  void _calculateFinalTransform() {
    // カメラの基本位置を取得
    final basePosition = _cameraSystem.position;
    final baseZoom = _cameraSystem.zoom;
    
    // エフェクトの結果を取得
    final effectResult = _effectSystem.getCombinedEffect();
    
    // 最終位置 = 基本位置 + エフェクトオフセット
    _finalPosition = basePosition + effectResult.shakeOffset;
    
    // 最終ズーム = 基本ズーム × エフェクトズーム
    _finalZoom = baseZoom * effectResult.zoomMultiplier;
  }
  
  /// プレイヤー追従設定
  void followPlayer(Offset playerPosition, {Offset? velocity}) {
    _cameraSystem.setTarget(playerPosition, velocity: velocity);
  }
  
  /// 境界設定
  void setBounds(Rect bounds, {EdgeInsets? safeArea}) {
    _cameraSystem.setBounds(bounds, safeArea: safeArea);
  }
  
  /// 振動エフェクト
  void shake({
    required double intensity,
    required double duration,
    ShakePattern pattern = ShakePattern.random,
  }) {
    _effectSystem.addShakeEffect(
      intensity: intensity,
      duration: duration,
      pattern: pattern,
    );
  }
  
  /// ズームエフェクト
  void zoom({
    required double targetZoom,
    required double duration,
    Curve curve = Curves.easeInOut,
  }) {
    _effectSystem.addZoomEffect(
      targetZoom: targetZoom,
      duration: duration,
      curve: curve,
    );
  }
  
  /// インパクトエフェクト
  void impact({
    required double intensity,
    double duration = 0.3,
    double zoomAmount = 1.2,
  }) {
    _effectSystem.addImpactEffect(
      intensity: intensity,
      duration: duration,
      zoomAmount: zoomAmount,
    );
  }
  
  /// プリセットエフェクト適用
  void applyPreset(CameraPreset preset) {
    switch (preset) {
      case CameraPreset.lightShake:
        CameraEffectPresets.lightShake(_effectSystem);
        break;
      case CameraPreset.mediumShake:
        CameraEffectPresets.mediumShake(_effectSystem);
        break;
      case CameraPreset.heavyShake:
        CameraEffectPresets.heavyShake(_effectSystem);
        break;
      case CameraPreset.punchInZoom:
        CameraEffectPresets.punchInZoom(_effectSystem);
        break;
      case CameraPreset.slowMotionZoom:
        CameraEffectPresets.slowMotionZoom(_effectSystem);
        break;
      case CameraPreset.impactCombo:
        CameraEffectPresets.impactCombo(_effectSystem);
        break;
      case CameraPreset.bossEntrance:
        CameraEffectPresets.bossEntrance(_effectSystem);
        break;
    }
  }
  
  /// ワールド座標をスクリーン座標に変換
  Offset worldToScreen(Offset worldPosition, Size screenSize) {
    final cameraOffset = _finalPosition;
    final zoomedPosition = Offset(
      (worldPosition.dx - cameraOffset.dx) * _finalZoom,
      (worldPosition.dy - cameraOffset.dy) * _finalZoom,
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
      centeredPosition.dx / _finalZoom,
      centeredPosition.dy / _finalZoom,
    );
    
    return unzoomedPosition + _finalPosition;
  }
  
  /// 視差レイヤー取得
  List<ParallaxLayer> getParallaxLayers() {
    return _cameraSystem.getParallaxLayers();
  }
  
  /// カメラリセット
  void reset() {
    _cameraSystem.reset();
    _effectSystem.stopAllEffects();
    _finalPosition = Offset.zero;
    _finalZoom = 1.0;
  }
  
  /// デバッグ情報取得
  CameraDebugInfo getDebugInfo() {
    return CameraDebugInfo(
      basePosition: _cameraSystem.position,
      finalPosition: _finalPosition,
      baseZoom: _cameraSystem.zoom,
      finalZoom: _finalZoom,
      target: _cameraSystem.target,
      isShaking: _cameraSystem.isShaking,
      isZooming: _cameraSystem.isZooming,
      activeEffectsCount: _effectSystem.activeEffects.length,
    );
  }
}

/// カメラプリセット
enum CameraPreset {
  lightShake,
  mediumShake,
  heavyShake,
  punchInZoom,
  slowMotionZoom,
  impactCombo,
  bossEntrance,
}

/// カメラデバッグ情報
class CameraDebugInfo {
  final Offset basePosition;
  final Offset finalPosition;
  final double baseZoom;
  final double finalZoom;
  final Offset target;
  final bool isShaking;
  final bool isZooming;
  final int activeEffectsCount;
  
  CameraDebugInfo({
    required this.basePosition,
    required this.finalPosition,
    required this.baseZoom,
    required this.finalZoom,
    required this.target,
    required this.isShaking,
    required this.isZooming,
    required this.activeEffectsCount,
  });
  
  @override
  String toString() {
    return '''
Camera Debug Info:
  Base Position: $basePosition
  Final Position: $finalPosition
  Base Zoom: ${baseZoom.toStringAsFixed(2)}
  Final Zoom: ${finalZoom.toStringAsFixed(2)}
  Target: $target
  Is Shaking: $isShaking
  Is Zooming: $isZooming
  Active Effects: $activeEffectsCount
''';
  }
}

/// カメラ統合ウィジェット - Flutterウィジェットとの統合
class CameraIntegratedWidget extends StatefulWidget {
  final Widget child;
  final CameraIntegration cameraIntegration;
  final bool enableDebugOverlay;
  
  const CameraIntegratedWidget({
    super.key,
    required this.child,
    required this.cameraIntegration,
    this.enableDebugOverlay = false,
  });
  
  @override
  State<CameraIntegratedWidget> createState() => _CameraIntegratedWidgetState();
}

class _CameraIntegratedWidgetState extends State<CameraIntegratedWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    );
    
    // 60FPSでカメラ更新
    _animationController.addListener(() {
      widget.cameraIntegration.update(1.0 / 60.0);
      setState(() {});
    });
    
    _animationController.repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final camera = widget.cameraIntegration;
    
    return Transform.translate(
      offset: -camera.position,
      child: Transform.scale(
        scale: camera.zoom,
        child: Stack(
          children: [
            // メインコンテンツ
            widget.child,
            
            // デバッグオーバーレイ
            if (widget.enableDebugOverlay)
              Positioned(
                top: 50,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    camera.getDebugInfo().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}