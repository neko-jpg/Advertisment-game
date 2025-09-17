import 'dart:math' as math;
import 'package:flutter/material.dart';

/// スコア爆発エフェクト - 数字アニメーションとカウントアップ
class ScoreExplosion {
  final Offset startPosition;
  final int targetScore;
  final Color color;
  
  late Offset _currentPosition;
  late double _scale;
  late double _opacity;
  late double _rotation;
  late int _displayScore;
  
  double _lifetime = 0.0;
  final double _duration = 2.0;
  bool _isComplete = false;
  
  // アニメーション曲線
  late double _bouncePhase;
  late double _floatVelocity;
  
  ScoreExplosion({
    required Offset position,
    required int score,
    required this.color,
  }) : startPosition = position, targetScore = score {
    _initialize();
  }
  
  void _initialize() {
    _currentPosition = startPosition;
    _scale = 0.1;
    _opacity = 1.0;
    _rotation = 0.0;
    _displayScore = 0;
    _bouncePhase = 0.0;
    _floatVelocity = -50.0; // 上向きの初期速度
  }
  
  void update(double deltaTime) {
    if (_isComplete) return;
    
    _lifetime += deltaTime;
    final progress = _lifetime / _duration;
    
    if (progress >= 1.0) {
      _isComplete = true;
      return;
    }
    
    // フェーズ別アニメーション
    if (progress < 0.3) {
      // Phase 1: 爆発的登場 (0-0.3)
      _updateExplosionPhase(progress / 0.3);
    } else if (progress < 0.7) {
      // Phase 2: カウントアップ (0.3-0.7)
      _updateCountUpPhase((progress - 0.3) / 0.4);
    } else {
      // Phase 3: フェードアウト (0.7-1.0)
      _updateFadeOutPhase((progress - 0.7) / 0.3);
    }
    
    // 浮遊効果
    _floatVelocity += 120.0 * deltaTime; // 重力
    _currentPosition = Offset(
      _currentPosition.dx,
      _currentPosition.dy + _floatVelocity * deltaTime,
    );
    
    // 微細な回転
    _rotation += deltaTime * 0.5;
  }
  
  void _updateExplosionPhase(double phaseProgress) {
    // 弾性スケールアニメーション
    final elasticScale = _elasticEaseOut(phaseProgress);
    _scale = 0.1 + elasticScale * 1.4;
    
    // バウンス効果
    _bouncePhase = phaseProgress * math.pi * 3;
    final bounce = math.sin(_bouncePhase) * 0.2 * (1.0 - phaseProgress);
    _scale += bounce;
    
    _opacity = 1.0;
  }
  
  void _updateCountUpPhase(double phaseProgress) {
    // スコアカウントアップ
    final easedProgress = _easeOutCubic(phaseProgress);
    _displayScore = (targetScore * easedProgress).round();
    
    // 安定したスケール
    _scale = 1.5 - (phaseProgress * 0.3);
    _opacity = 1.0;
    
    // 微細な脈動効果
    final pulse = math.sin(phaseProgress * math.pi * 8) * 0.05;
    _scale += pulse;
  }
  
  void _updateFadeOutPhase(double phaseProgress) {
    // 最終スコア表示
    _displayScore = targetScore;
    
    // フェードアウト
    _opacity = 1.0 - _easeInCubic(phaseProgress);
    _scale = 1.2 + (phaseProgress * 0.5); // 少し拡大しながらフェード
  }
  
  void render(Canvas canvas) {
    if (_isComplete || _opacity <= 0) return;
    
    canvas.save();
    
    // 位置とトランスフォーム適用
    canvas.translate(_currentPosition.dx, _currentPosition.dy);
    canvas.scale(_scale);
    canvas.rotate(_rotation);
    
    // グロー効果
    _renderGlow(canvas);
    
    // メインテキスト
    _renderScoreText(canvas);
    
    canvas.restore();
  }
  
  void _renderGlow(Canvas canvas) {
    final glowPaint = Paint()
      ..color = color.withOpacity(_opacity * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    
    final textPainter = _createTextPainter(_displayScore.toString(), glowPaint);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
  
  void _renderScoreText(Canvas canvas) {
    final textPaint = Paint()
      ..color = color.withOpacity(_opacity);
    
    final textPainter = _createTextPainter(_displayScore.toString(), textPaint);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
  
  TextPainter _createTextPainter(String text, Paint paint) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: paint.color,
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 4.0,
              color: Colors.black.withOpacity(0.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
  
  // イージング関数
  double _elasticEaseOut(double t) {
    if (t == 0 || t == 1) return t;
    return math.pow(2, -10 * t).toDouble() * math.sin((t - 0.1) * 2 * math.pi / 0.4) + 1;
  }
  
  double _easeOutCubic(double t) {
    return 1 - math.pow(1 - t, 3).toDouble();
  }
  
  double _easeInCubic(double t) {
    return (t * t * t).toDouble();
  }
  
  bool get isComplete => _isComplete;
}