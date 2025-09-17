import 'dart:async';
import 'package:flutter/material.dart';
import 'shape_recognition_engine.dart';

/// 形状アクションの結果
class ShapeActionResult {
  final bool success;
  final String message;
  final Duration? cooldownRemaining;
  final Map<String, dynamic>? effectData;

  const ShapeActionResult({
    required this.success,
    required this.message,
    this.cooldownRemaining,
    this.effectData,
  });
}

/// 形状別のスペシャルアクション管理
class ShapeActionManager {
  final Map<ShapeType, DateTime> _lastActivation = {};
  final Map<ShapeType, Duration> _cooldowns = {
    ShapeType.circle: const Duration(seconds: 8),    // シールド
    ShapeType.triangle: const Duration(seconds: 6),  // ジャンプ台
    ShapeType.wave: const Duration(seconds: 4),      // スピードブースト
    ShapeType.spiral: const Duration(seconds: 12),   // 竜巻効果
  };

  // アクション効果の持続時間
  final Map<ShapeType, Duration> _effectDurations = {
    ShapeType.circle: const Duration(seconds: 5),    // シールド持続時間
    ShapeType.triangle: const Duration(seconds: 3),  // ジャンプ台持続時間
    ShapeType.wave: const Duration(seconds: 4),      // スピードブースト持続時間
    ShapeType.spiral: const Duration(seconds: 6),    // 竜巻効果持続時間
  };

  // 現在アクティブな効果
  final Map<ShapeType, Timer> _activeEffects = {};
  final StreamController<ShapeActionEvent> _eventController = StreamController.broadcast();

  /// アクションイベントのストリーム
  Stream<ShapeActionEvent> get actionEvents => _eventController.stream;

  /// 形状認識時のアクション実行
  Future<ShapeActionResult> executeAction(RecognizedShape shape) async {
    // クールダウンチェック
    final cooldownRemaining = getRemainingCooldown(shape.type);
    if (cooldownRemaining != null) {
      return ShapeActionResult(
        success: false,
        message: 'クールダウン中: ${cooldownRemaining.inSeconds}秒',
        cooldownRemaining: cooldownRemaining,
      );
    }

    // 信頼度チェック
    if (shape.confidence < 0.7) {
      return const ShapeActionResult(
        success: false,
        message: '形状認識の精度が不十分です',
      );
    }

    // アクション実行
    final result = await _performAction(shape);
    
    if (result.success) {
      // クールダウン開始
      _lastActivation[shape.type] = DateTime.now();
      
      // 効果の持続時間管理
      _startEffectTimer(shape.type);
      
      // イベント発火
      _eventController.add(ShapeActionEvent(
        type: ShapeActionEventType.activated,
        shapeType: shape.type,
        position: shape.center,
        effectData: result.effectData,
      ));
    }

    return result;
  }

  /// 残りクールダウン時間を取得
  Duration? getRemainingCooldown(ShapeType shapeType) {
    final lastActivation = _lastActivation[shapeType];
    if (lastActivation == null) return null;

    final cooldown = _cooldowns[shapeType] ?? Duration.zero;
    final elapsed = DateTime.now().difference(lastActivation);
    
    if (elapsed >= cooldown) return null;
    
    return cooldown - elapsed;
  }

  /// アクティブな効果があるかチェック
  bool isEffectActive(ShapeType shapeType) {
    return _activeEffects.containsKey(shapeType);
  }

  /// 効果の残り時間を取得
  Duration? getEffectRemainingTime(ShapeType shapeType) {
    if (!isEffectActive(shapeType)) return null;
    
    final lastActivation = _lastActivation[shapeType];
    if (lastActivation == null) return null;
    
    final duration = _effectDurations[shapeType] ?? Duration.zero;
    final elapsed = DateTime.now().difference(lastActivation);
    
    if (elapsed >= duration) return null;
    
    return duration - elapsed;
  }

  /// 実際のアクション実行
  Future<ShapeActionResult> _performAction(RecognizedShape shape) async {
    switch (shape.type) {
      case ShapeType.circle:
        return _activateShield(shape);
      case ShapeType.triangle:
        return _createJumpPad(shape);
      case ShapeType.wave:
        return _activateSpeedBoost(shape);
      case ShapeType.spiral:
        return _createTornado(shape);
      case ShapeType.unknown:
        return const ShapeActionResult(
          success: false,
          message: '不明な形状です',
        );
    }
  }

  /// シールド生成（円形）
  ShapeActionResult _activateShield(RecognizedShape shape) {
    final shieldRadius = shape.size * 0.6;
    final shieldStrength = (shape.confidence * 100).round();
    
    return ShapeActionResult(
      success: true,
      message: 'シールド発動！ 強度: $shieldStrength%',
      effectData: {
        'type': 'shield',
        'radius': shieldRadius,
        'strength': shieldStrength,
        'position': shape.center,
        'duration': _effectDurations[ShapeType.circle]!.inMilliseconds,
      },
    );
  }

  /// ジャンプ台生成（三角形）
  ShapeActionResult _createJumpPad(RecognizedShape shape) {
    final jumpPower = (shape.confidence * 150 + 50).round(); // 50-200%
    final angle = _calculateTriangleAngle(shape.originalPoints);
    
    return ShapeActionResult(
      success: true,
      message: 'ジャンプ台生成！ パワー: $jumpPower%',
      effectData: {
        'type': 'jumpPad',
        'power': jumpPower,
        'angle': angle,
        'position': shape.center,
        'size': shape.size,
        'duration': _effectDurations[ShapeType.triangle]!.inMilliseconds,
      },
    );
  }

  /// スピードブースト（波形）
  ShapeActionResult _activateSpeedBoost(RecognizedShape shape) {
    final speedMultiplier = 1.5 + (shape.confidence * 0.5); // 1.5x - 2.0x
    final boostDirection = _calculateWaveDirection(shape.originalPoints);
    
    return ShapeActionResult(
      success: true,
      message: 'スピードブースト！ ${speedMultiplier.toStringAsFixed(1)}x',
      effectData: {
        'type': 'speedBoost',
        'multiplier': speedMultiplier,
        'direction': boostDirection,
        'position': shape.center,
        'duration': _effectDurations[ShapeType.wave]!.inMilliseconds,
      },
    );
  }

  /// 竜巻効果（螺旋）
  ShapeActionResult _createTornado(RecognizedShape shape) {
    final tornadoRadius = shape.size * 0.8;
    final rotationSpeed = shape.confidence * 360; // 度/秒
    final isClockwise = _isSpiralClockwise(shape.originalPoints);
    
    return ShapeActionResult(
      success: true,
      message: '竜巻発動！ 半径: ${tornadoRadius.toStringAsFixed(0)}',
      effectData: {
        'type': 'tornado',
        'radius': tornadoRadius,
        'rotationSpeed': rotationSpeed,
        'clockwise': isClockwise,
        'position': shape.center,
        'duration': _effectDurations[ShapeType.spiral]!.inMilliseconds,
      },
    );
  }

  /// 効果タイマーを開始
  void _startEffectTimer(ShapeType shapeType) {
    // 既存のタイマーをキャンセル
    _activeEffects[shapeType]?.cancel();
    
    final duration = _effectDurations[shapeType] ?? Duration.zero;
    
    _activeEffects[shapeType] = Timer(duration, () {
      _activeEffects.remove(shapeType);
      
      // 効果終了イベント
      _eventController.add(ShapeActionEvent(
        type: ShapeActionEventType.deactivated,
        shapeType: shapeType,
        position: Offset.zero,
      ));
    });
  }

  /// 三角形の角度を計算
  double _calculateTriangleAngle(List<Offset> points) {
    if (points.length < 3) return 0.0;
    
    // 最初と最後の点から角度を推定
    final start = points.first;
    final end = points.last;
    
    return math.atan2(end.dy - start.dy, end.dx - start.dx);
  }

  /// 波の方向を計算
  Offset _calculateWaveDirection(List<Offset> points) {
    if (points.length < 2) return const Offset(1, 0);
    
    // 全体的な方向を計算
    final start = points.first;
    final end = points.last;
    
    final direction = Offset(end.dx - start.dx, end.dy - start.dy);
    final length = math.sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    
    if (length == 0) return const Offset(1, 0);
    
    return Offset(direction.dx / length, direction.dy / length);
  }

  /// 螺旋が時計回りかどうか判定
  bool _isSpiralClockwise(List<Offset> points) {
    if (points.length < 3) return true;
    
    double totalAngle = 0;
    
    for (int i = 2; i < points.length; i++) {
      final p1 = points[i - 2];
      final p2 = points[i - 1];
      final p3 = points[i];
      
      // 外積を使って回転方向を判定
      final cross = (p2.dx - p1.dx) * (p3.dy - p1.dy) - (p2.dy - p1.dy) * (p3.dx - p1.dx);
      totalAngle += cross;
    }
    
    return totalAngle > 0; // 正の値なら時計回り
  }

  /// リソースのクリーンアップ
  void dispose() {
    for (final timer in _activeEffects.values) {
      timer.cancel();
    }
    _activeEffects.clear();
    _eventController.close();
  }
}

/// 形状アクションイベントの種類
enum ShapeActionEventType {
  activated,    // アクション発動
  deactivated,  // アクション終了
  cooldown,     // クールダウン開始
}

/// 形状アクションイベント
class ShapeActionEvent {
  final ShapeActionEventType type;
  final ShapeType shapeType;
  final Offset position;
  final Map<String, dynamic>? effectData;

  const ShapeActionEvent({
    required this.type,
    required this.shapeType,
    required this.position,
    this.effectData,
  });
}

// math ライブラリのインポートを追加
import 'dart:math' as math;