import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'shape_recognition_engine.dart';
import 'shape_actions.dart';
import '../effects/particle_engine.dart';

/// 形状認識時のフィードバック管理
class ShapeFeedbackSystem {
  final ParticleEngine _particleEngine;
  final StreamController<ShapeFeedbackEvent> _feedbackController = StreamController.broadcast();
  
  // 音響フィードバック用の設定
  final Map<ShapeType, List<double>> _shapeFrequencies = {
    ShapeType.circle: [440.0, 554.37, 659.25],      // A4, C#5, E5 (メジャートライアド)
    ShapeType.triangle: [523.25, 659.25, 783.99],   // C5, E5, G5 (メジャートライアド)
    ShapeType.wave: [293.66, 369.99, 440.0, 523.25], // D4, F#4, A4, C5 (流れるような音階)
    ShapeType.spiral: [220.0, 277.18, 329.63, 392.0], // A3, C#4, E4, G4 (螺旋的な音階)
  };

  // 振動パターン
  final Map<ShapeType, List<int>> _vibrationPatterns = {
    ShapeType.circle: [100, 50, 100],           // 短い-休止-短い
    ShapeType.triangle: [150, 100, 150, 100, 150], // 3回の鋭い振動
    ShapeType.wave: [50, 30, 70, 30, 90, 30, 110], // 波のような強弱
    ShapeType.spiral: [200, 50, 180, 50, 160, 50, 140], // 螺旋的に弱くなる
  };

  ShapeFeedbackSystem(this._particleEngine);

  /// フィードバックイベントのストリーム
  Stream<ShapeFeedbackEvent> get feedbackEvents => _feedbackController.stream;

  /// 形状認識成功時のフィードバック
  Future<void> triggerSuccessFeedback(RecognizedShape shape, ShapeActionResult actionResult) async {
    // 視覚フィードバック
    await _triggerVisualFeedback(shape, actionResult);
    
    // 音響フィードバック
    await _triggerAudioFeedback(shape, actionResult);
    
    // 触覚フィードバック
    await _triggerHapticFeedback(shape);
    
    // イベント発火
    _feedbackController.add(ShapeFeedbackEvent(
      type: ShapeFeedbackType.success,
      shapeType: shape.type,
      position: shape.center,
      confidence: shape.confidence,
      actionResult: actionResult,
    ));
  }

  /// 形状認識失敗時のフィードバック
  Future<void> triggerFailureFeedback(List<Offset> points, String reason) async {
    if (points.isEmpty) return;
    
    final center = _calculateCenter(points);
    
    // 失敗時の視覚フィードバック
    await _triggerFailureVisualFeedback(center, reason);
    
    // 失敗時の音響フィードバック
    await _triggerFailureAudioFeedback();
    
    // 軽い振動
    HapticFeedback.lightImpact();
    
    // イベント発火
    _feedbackController.add(ShapeFeedbackEvent(
      type: ShapeFeedbackType.failure,
      shapeType: ShapeType.unknown,
      position: center,
      confidence: 0.0,
      failureReason: reason,
    ));
  }

  /// 認識進行中のフィードバック
  Future<void> triggerProgressFeedback(List<Offset> points, double confidence) async {
    if (points.isEmpty) return;
    
    final center = _calculateCenter(points);
    
    // 進行中の視覚フィードバック
    await _triggerProgressVisualFeedback(center, confidence);
    
    // イベント発火
    _feedbackController.add(ShapeFeedbackEvent(
      type: ShapeFeedbackType.progress,
      shapeType: ShapeType.unknown,
      position: center,
      confidence: confidence,
    ));
  }

  /// 視覚フィードバック（成功時）
  Future<void> _triggerVisualFeedback(RecognizedShape shape, ShapeActionResult actionResult) async {
    final color = _getShapeColor(shape.type);
    final particleCount = (shape.confidence * 50 + 20).round();
    
    // 形状別の特別なパーティクルエフェクト
    switch (shape.type) {
      case ShapeType.circle:
        await _createCircleSuccessEffect(shape.center, shape.size, color, particleCount);
        break;
      case ShapeType.triangle:
        await _createTriangleSuccessEffect(shape.center, shape.size, color, particleCount);
        break;
      case ShapeType.wave:
        await _createWaveSuccessEffect(shape.originalPoints, color, particleCount);
        break;
      case ShapeType.spiral:
        await _createSpiralSuccessEffect(shape.center, shape.size, color, particleCount);
        break;
      case ShapeType.unknown:
        break;
    }
    
    // 成功時の共通エフェクト
    await _createSuccessRippleEffect(shape.center, shape.size, color);
  }

  /// 失敗時の視覚フィードバック
  Future<void> _triggerFailureVisualFeedback(Offset center, String reason) async {
    const failureColor = Colors.red;
    
    // 失敗を示すX印のパーティクル
    await _createFailureXEffect(center, failureColor);
    
    // 失敗時の波紋エフェクト
    await _createFailureRippleEffect(center, failureColor);
  }

  /// 進行中の視覚フィードバック
  Future<void> _triggerProgressVisualFeedback(Offset center, double confidence) async {
    final alpha = (confidence * 255).round().clamp(50, 200);
    final color = Colors.blue.withAlpha(alpha);
    
    // 進行度を示すリングエフェクト
    await _createProgressRingEffect(center, confidence, color);
  }

  /// 音響フィードバック（成功時）
  Future<void> _triggerAudioFeedback(RecognizedShape shape, ShapeActionResult actionResult) async {
    final frequencies = _shapeFrequencies[shape.type] ?? [440.0];
    
    // 形状別の音階を再生
    for (int i = 0; i < frequencies.length; i++) {
      final frequency = frequencies[i];
      final delay = i * 100; // 100ms間隔
      
      Timer(Duration(milliseconds: delay), () {
        _playTone(frequency, 200); // 200ms duration
      });
    }
    
    // 成功時の追加音響効果
    Timer(const Duration(milliseconds: 500), () {
      _playSuccessChime(shape.confidence);
    });
  }

  /// 失敗時の音響フィードバック
  Future<void> _triggerFailureAudioFeedback() async {
    // 不協和音で失敗を表現
    _playTone(200.0, 300); // 低い不快な音
  }

  /// 触覚フィードバック
  Future<void> _triggerHapticFeedback(RecognizedShape shape) async {
    final pattern = _vibrationPatterns[shape.type] ?? [100];
    
    for (int i = 0; i < pattern.length; i++) {
      final duration = pattern[i];
      
      Timer(Duration(milliseconds: i * 100), () {
        if (duration > 100) {
          HapticFeedback.heavyImpact();
        } else if (duration > 50) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      });
    }
  }

  /// 円形成功エフェクト
  Future<void> _createCircleSuccessEffect(Offset center, double size, Color color, int particleCount) async {
    // 円周に沿ってパーティクルを放射
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final radius = size * 0.5;
      final startPos = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      
      _particleEngine.emitParticle(
        position: startPos,
        velocity: Offset(math.cos(angle) * 100, math.sin(angle) * 100),
        color: color,
        size: 4.0,
        lifetime: 1.5,
      );
    }
  }

  /// 三角形成功エフェクト
  Future<void> _createTriangleSuccessEffect(Offset center, double size, Color color, int particleCount) async {
    // 三角形の頂点から放射
    final angles = [0, 2 * math.pi / 3, 4 * math.pi / 3]; // 120度間隔
    
    for (final angle in angles) {
      for (int i = 0; i < particleCount ~/ 3; i++) {
        final radius = size * 0.4;
        final startPos = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );
        
        _particleEngine.emitParticle(
          position: startPos,
          velocity: Offset(math.cos(angle) * 150, math.sin(angle) * 150),
          color: color,
          size: 5.0,
          lifetime: 2.0,
        );
      }
    }
  }

  /// 波形成功エフェクト
  Future<void> _createWaveSuccessEffect(List<Offset> points, Color color, int particleCount) async {
    if (points.length < 2) return;
    
    // 波の軌跡に沿ってパーティクルを生成
    for (int i = 0; i < particleCount; i++) {
      final t = i / (particleCount - 1);
      final index = (t * (points.length - 1)).floor();
      final nextIndex = math.min(index + 1, points.length - 1);
      
      final localT = (t * (points.length - 1)) - index;
      final position = Offset.lerp(points[index], points[nextIndex], localT)!;
      
      // 波の方向に垂直な速度
      final direction = nextIndex > index 
          ? points[nextIndex] - points[index]
          : Offset.zero;
      final perpendicular = Offset(-direction.dy, direction.dx);
      final normalizedPerp = perpendicular.distance > 0 
          ? perpendicular / perpendicular.distance
          : Offset.zero;
      
      _particleEngine.emitParticle(
        position: position,
        velocity: normalizedPerp * (50 + math.Random().nextDouble() * 100),
        color: color,
        size: 3.0,
        lifetime: 1.0 + math.Random().nextDouble(),
      );
    }
  }

  /// 螺旋成功エフェクト
  Future<void> _createSpiralSuccessEffect(Offset center, double size, Color color, int particleCount) async {
    // 螺旋状にパーティクルを放射
    for (int i = 0; i < particleCount; i++) {
      final t = i / particleCount;
      final angle = t * 4 * math.pi; // 2回転
      final radius = (size * 0.5) * (1 - t); // 外側から内側へ
      
      final startPos = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      
      final velocity = Offset(
        math.cos(angle + math.pi / 2) * 80,
        math.sin(angle + math.pi / 2) * 80,
      );
      
      Timer(Duration(milliseconds: (t * 500).round()), () {
        _particleEngine.emitParticle(
          position: startPos,
          velocity: velocity,
          color: color,
          size: 4.0,
          lifetime: 2.0,
        );
      });
    }
  }

  /// 成功時の波紋エフェクト
  Future<void> _createSuccessRippleEffect(Offset center, double size, Color color) async {
    // 複数の波紋を時間差で生成
    for (int i = 0; i < 3; i++) {
      Timer(Duration(milliseconds: i * 200), () {
        _createRipple(center, size * (1 + i * 0.5), color.withAlpha(150 - i * 50));
      });
    }
  }

  /// 失敗時のX印エフェクト
  Future<void> _createFailureXEffect(Offset center, Color color) async {
    const lineLength = 40.0;
    
    // X印の4つの方向
    final directions = [
      Offset(1, 1), Offset(-1, -1), Offset(1, -1), Offset(-1, 1)
    ];
    
    for (final direction in directions) {
      for (int i = 0; i < 10; i++) {
        final t = i / 9.0;
        final position = center + direction * (lineLength * t);
        
        Timer(Duration(milliseconds: i * 20), () {
          _particleEngine.emitParticle(
            position: position,
            velocity: direction * 50,
            color: color,
            size: 3.0,
            lifetime: 1.0,
          );
        });
      }
    }
  }

  /// 失敗時の波紋エフェクト
  Future<void> _createFailureRippleEffect(Offset center, Color color) async {
    _createRipple(center, 60.0, color.withAlpha(100));
  }

  /// 進行中のリングエフェクト
  Future<void> _createProgressRingEffect(Offset center, double confidence, Color color) async {
    final radius = 30.0 + confidence * 20.0;
    final particleCount = (confidence * 20 + 10).round();
    
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final position = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      
      _particleEngine.emitParticle(
        position: position,
        velocity: Offset.zero,
        color: color,
        size: 2.0,
        lifetime: 0.5,
      );
    }
  }

  /// 波紋を作成
  void _createRipple(Offset center, double radius, Color color) {
    const particleCount = 30;
    
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final position = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      
      _particleEngine.emitParticle(
        position: position,
        velocity: Offset(math.cos(angle) * 20, math.sin(angle) * 20),
        color: color,
        size: 2.0,
        lifetime: 1.0,
      );
    }
  }

  /// 形状別の色を取得
  Color _getShapeColor(ShapeType shapeType) {
    switch (shapeType) {
      case ShapeType.circle:
        return Colors.cyan;
      case ShapeType.triangle:
        return Colors.orange;
      case ShapeType.wave:
        return Colors.blue;
      case ShapeType.spiral:
        return Colors.purple;
      case ShapeType.unknown:
        return Colors.grey;
    }
  }

  /// 中心点を計算
  Offset _calculateCenter(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    
    double sumX = 0;
    double sumY = 0;
    
    for (final point in points) {
      sumX += point.dx;
      sumY += point.dy;
    }
    
    return Offset(sumX / points.length, sumY / points.length);
  }

  /// 音を再生（プレースホルダー実装）
  void _playTone(double frequency, int durationMs) {
    // 実際の実装では音響ライブラリを使用
    // ここではハプティックフィードバックで代用
    HapticFeedback.selectionClick();
  }

  /// 成功時のチャイム音（プレースホルダー実装）
  void _playSuccessChime(double confidence) {
    // 信頼度に応じた音の高さ
    final pitch = 440.0 + (confidence * 220.0);
    _playTone(pitch, 500);
  }

  /// リソースのクリーンアップ
  void dispose() {
    _feedbackController.close();
  }
}

/// フィードバックイベントの種類
enum ShapeFeedbackType {
  success,   // 認識成功
  failure,   // 認識失敗
  progress,  // 認識進行中
}

/// フィードバックイベント
class ShapeFeedbackEvent {
  final ShapeFeedbackType type;
  final ShapeType shapeType;
  final Offset position;
  final double confidence;
  final ShapeActionResult? actionResult;
  final String? failureReason;

  const ShapeFeedbackEvent({
    required this.type,
    required this.shapeType,
    required this.position,
    required this.confidence,
    this.actionResult,
    this.failureReason,
  });
}