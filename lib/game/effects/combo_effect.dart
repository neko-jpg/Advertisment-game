import 'dart:math' as math;
import 'package:flutter/material.dart';

/// コンボエフェクト - 画面全体のインパクト演出と連鎖反応
class ComboEffect {
  final int comboCount;
  final double intensity;
  final Offset centerPosition;
  
  double _lifetime = 0.0;
  final double _duration = 1.5;
  bool _isComplete = false;
  
  // 波紋エフェクト
  final List<RippleWave> _ripples = [];
  
  // 放射状パーティクル
  final List<RadialBurst> _bursts = [];
  
  // 画面境界エフェクト
  double _borderPulse = 0.0;
  
  // コンボテキスト
  late String _comboText;
  double _textScale = 0.0;
  double _textOpacity = 0.0;
  
  ComboEffect({
    required this.comboCount,
    required this.intensity,
    required this.centerPosition,
  }) {
    _initialize();
  }
  
  void _initialize() {
    _comboText = _getComboText(comboCount);
    
    // 波紋エフェクト生成
    final rippleCount = math.min(3 + (comboCount ~/ 3), 8);
    for (int i = 0; i < rippleCount; i++) {
      _ripples.add(RippleWave(
        startDelay: i * 0.1,
        maxRadius: 200.0 + (i * 50) + (comboCount * 20),
        color: _getComboColor(comboCount),
        intensity: intensity,
      ));
    }
    
    // 放射状バースト生成
    final burstCount = math.min(2 + (comboCount ~/ 5), 6);
    for (int i = 0; i < burstCount; i++) {
      _bursts.add(RadialBurst(
        startDelay: i * 0.05,
        particleCount: 12 + (comboCount * 2),
        radius: 100.0 + (i * 30),
        color: _getComboColor(comboCount),
        intensity: intensity,
      ));
    }
  }
  
  void update(double deltaTime) {
    if (_isComplete) return;
    
    _lifetime += deltaTime;
    final progress = _lifetime / _duration;
    
    if (progress >= 1.0) {
      _isComplete = true;
      return;
    }
    
    // 波紋更新
    for (final ripple in _ripples) {
      ripple.update(deltaTime);
    }
    
    // バースト更新
    for (final burst in _bursts) {
      burst.update(deltaTime);
    }
    
    // 境界パルス
    _borderPulse = math.sin(progress * math.pi * 6) * intensity * (1.0 - progress);
    
    // コンボテキストアニメーション
    if (progress < 0.4) {
      // 登場フェーズ
      final textProgress = progress / 0.4;
      _textScale = _elasticEaseOut(textProgress) * (1.0 + intensity * 0.5);
      _textOpacity = textProgress;
    } else if (progress < 0.8) {
      // 安定フェーズ
      _textScale = 1.0 + intensity * 0.5;
      _textOpacity = 1.0;
      
      // 脈動効果
      final pulse = math.sin((progress - 0.4) * math.pi * 10) * 0.1;
      _textScale += pulse;
    } else {
      // フェードアウトフェーズ
      final fadeProgress = (progress - 0.8) / 0.2;
      _textOpacity = 1.0 - fadeProgress;
      _textScale = (1.0 + intensity * 0.5) * (1.0 + fadeProgress * 0.3);
    }
  }
  
  void render(Canvas canvas, Size screenSize) {
    if (_isComplete) return;
    
    canvas.save();
    
    // 境界エフェクト描画
    _renderBorderEffect(canvas, screenSize);
    
    // 波紋エフェクト描画
    canvas.translate(centerPosition.dx, centerPosition.dy);
    for (final ripple in _ripples) {
      ripple.render(canvas);
    }
    
    // バーストエフェクト描画
    for (final burst in _bursts) {
      burst.render(canvas);
    }
    
    canvas.restore();
    
    // コンボテキスト描画
    _renderComboText(canvas, screenSize);
  }
  
  void _renderBorderEffect(Canvas canvas, Size screenSize) {
    if (_borderPulse <= 0) return;
    
    final paint = Paint()
      ..color = _getComboColor(comboCount).withOpacity(_borderPulse * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 + (_borderPulse * 12.0);
    
    final rect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    canvas.drawRect(rect, paint);
  }
  
  void _renderComboText(Canvas canvas, Size screenSize) {
    if (_textOpacity <= 0) return;
    
    canvas.save();
    
    // 画面中央に配置
    canvas.translate(screenSize.width / 2, screenSize.height / 3);
    canvas.scale(_textScale);
    
    // グロー効果
    final glowPainter = TextPainter(
      text: TextSpan(
        text: _comboText,
        style: TextStyle(
          fontSize: 48 + (comboCount * 2),
          fontWeight: FontWeight.w900,
          color: _getComboColor(comboCount).withOpacity(_textOpacity * 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final glowPaint = Paint()
      ..color = _getComboColor(comboCount).withOpacity(_textOpacity * 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    
    // メインテキスト
    final textPainter = TextPainter(
      text: TextSpan(
        text: _comboText,
        style: TextStyle(
          fontSize: 48 + (comboCount * 2),
          fontWeight: FontWeight.w900,
          color: Colors.white.withOpacity(_textOpacity),
          shadows: [
            Shadow(
              offset: const Offset(0, 0),
              blurRadius: 8.0,
              color: _getComboColor(comboCount).withOpacity(_textOpacity),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    final offset = Offset(-textPainter.width / 2, -textPainter.height / 2);
    textPainter.paint(canvas, offset);
    
    canvas.restore();
  }
  
  String _getComboText(int combo) {
    if (combo < 3) return 'COMBO!';
    if (combo < 5) return 'GREAT!';
    if (combo < 8) return 'AWESOME!';
    if (combo < 12) return 'INCREDIBLE!';
    if (combo < 20) return 'LEGENDARY!';
    return 'GODLIKE!';
  }
  
  Color _getComboColor(int combo) {
    if (combo < 3) return Colors.cyan;
    if (combo < 5) return Colors.green;
    if (combo < 8) return Colors.orange;
    if (combo < 12) return Colors.red;
    if (combo < 20) return Colors.purple;
    return Colors.pink;
  }
  
  double _elasticEaseOut(double t) {
    if (t == 0 || t == 1) return t;
    return math.pow(2, -10 * t).toDouble() * math.sin((t - 0.1) * 2 * math.pi / 0.4) + 1;
  }
  
  bool get isComplete => _isComplete;
}

/// 波紋エフェクト
class RippleWave {
  final double startDelay;
  final double maxRadius;
  final Color color;
  final double intensity;
  
  double _lifetime = 0.0;
  final double _duration = 1.0;
  bool _started = false;
  
  double _currentRadius = 0.0;
  double _opacity = 0.0;
  
  RippleWave({
    required this.startDelay,
    required this.maxRadius,
    required this.color,
    required this.intensity,
  });
  
  void update(double deltaTime) {
    _lifetime += deltaTime;
    
    if (_lifetime < startDelay) return;
    
    if (!_started) {
      _started = true;
      _lifetime = 0.0;
    }
    
    final progress = _lifetime / _duration;
    if (progress >= 1.0) return;
    
    _currentRadius = maxRadius * _easeOutCubic(progress);
    _opacity = intensity * (1.0 - progress) * 0.6;
  }
  
  void render(Canvas canvas) {
    if (!_started || _opacity <= 0) return;
    
    final paint = Paint()
      ..color = color.withOpacity(_opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + (intensity * 2.0);
    
    canvas.drawCircle(Offset.zero, _currentRadius, paint);
  }
  
  double _easeOutCubic(double t) {
    return 1 - math.pow(1 - t, 3).toDouble();
  }
}

/// 放射状バースト
class RadialBurst {
  final double startDelay;
  final int particleCount;
  final double radius;
  final Color color;
  final double intensity;
  
  final List<BurstParticle> _particles = [];
  double _lifetime = 0.0;
  bool _started = false;
  
  RadialBurst({
    required this.startDelay,
    required this.particleCount,
    required this.radius,
    required this.color,
    required this.intensity,
  }) {
    _initializeParticles();
  }
  
  void _initializeParticles() {
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      _particles.add(BurstParticle(
        angle: angle,
        maxDistance: radius,
        color: color,
        intensity: intensity,
      ));
    }
  }
  
  void update(double deltaTime) {
    _lifetime += deltaTime;
    
    if (_lifetime < startDelay) return;
    
    if (!_started) {
      _started = true;
    }
    
    for (final particle in _particles) {
      particle.update(deltaTime);
    }
  }
  
  void render(Canvas canvas) {
    if (!_started) return;
    
    for (final particle in _particles) {
      particle.render(canvas);
    }
  }
}

/// バーストパーティクル
class BurstParticle {
  final double angle;
  final double maxDistance;
  final Color color;
  final double intensity;
  
  double _lifetime = 0.0;
  final double _duration = 0.8;
  
  late Offset _position;
  late double _opacity;
  late double _size;
  
  BurstParticle({
    required this.angle,
    required this.maxDistance,
    required this.color,
    required this.intensity,
  }) {
    _position = Offset.zero;
    _opacity = 1.0;
    _size = 2.0 + intensity;
  }
  
  void update(double deltaTime) {
    _lifetime += deltaTime;
    final progress = _lifetime / _duration;
    
    if (progress >= 1.0) {
      _opacity = 0.0;
      return;
    }
    
    final distance = maxDistance * _easeOutQuart(progress);
    _position = Offset(
      math.cos(angle) * distance,
      math.sin(angle) * distance,
    );
    
    _opacity = (1.0 - progress) * intensity;
    _size = (2.0 + intensity) * (1.0 + progress * 0.5);
  }
  
  void render(Canvas canvas) {
    if (_opacity <= 0) return;
    
    final paint = Paint()
      ..color = color.withOpacity(_opacity)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(_position, _size, paint);
  }
  
  double _easeOutQuart(double t) {
    return 1 - math.pow(1 - t, 4).toDouble();
  }
}