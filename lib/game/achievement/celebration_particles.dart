import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../effects/particle_engine.dart';

/// 祝福専用パーティクルエフェクト集
class CelebrationParticles {
  static const List<Color> celebrationColors = [
    Color(0xFFFFD700), // ゴールド
    Color(0xFFFF6B6B), // コーラル
    Color(0xFF4ECDC4), // ターコイズ
    Color(0xFF45B7D1), // スカイブルー
    Color(0xFF9D4EDD), // パープル
    Color(0xFFFF006E), // ピンク
  ];
}

/// 祝福爆発エフェクト
class CelebrationExplosion extends ParticleEmitter {
  final int particleCount;
  final List<Color> colors;
  final List<_ExplosionParticle> _particles = [];
  
  CelebrationExplosion({
    required Offset center,
    this.particleCount = 100,
    this.colors = CelebrationParticles.celebrationColors,
  }) : super(
    position: center,
    duration: 3.0,
    particlesPerSecond: 0, // We emit all at once
  ) {
    _initializeParticles();
  }
  
  void _initializeParticles() {
    final random = math.Random();
    
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi + random.nextDouble() * 0.5;
      final speed = 100 + random.nextDouble() * 200;
      final velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      
      _particles.add(_ExplosionParticle(
        position: position,
        velocity: velocity,
        color: colors[random.nextInt(colors.length)],
        size: 3 + random.nextDouble() * 5,
        lifespan: (2000 + random.nextInt(1000)).toDouble(),
        gravity: 50 + random.nextDouble() * 100,
      ));
    }
  }
  
  @override
  void emitParticle() {
    // All particles are emitted at initialization
  }
  
  @override
  void update(double deltaTime) {
    super.update(deltaTime);
    
    for (final particle in _particles) {
      particle.update(deltaTime);
    }
  }
  
  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const int points = 5;
    final double outerRadius = size;
    final double innerRadius = size * 0.4;
    
    for (int i = 0; i < points * 2; i++) {
      final double angle = (i * math.pi) / points;
      final double radius = i.isEven ? outerRadius : innerRadius;
      final double x = center.dx + radius * math.cos(angle - math.pi / 2);
      final double y = center.dy + radius * math.sin(angle - math.pi / 2);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
}

/// 祝福用の星形パーティクル
class CelebrationStarParticle extends Particle {
  final double rotationSpeed;
  double rotation = 0;
  
  CelebrationStarParticle({
    required Offset position,
    required Offset velocity,
    required Color color,
    required double size,
    required int lifetime,
    this.rotationSpeed = 0.1,
  }) : super(
    position: position,
    velocity: velocity,
    color: color,
    size: size,
    lifetime: lifetime,
  );
  
  @override
  void updateCustom(double deltaTime) {
    rotation += rotationSpeed * deltaTime;
  }
  
  @override
  void render(Canvas canvas, Paint paint) {
    paint.color = color.withOpacity(opacity);
    
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    
    // 星形描画
    _drawStar(canvas, Offset.zero, size, paint);
    
    canvas.restore();
    
    // グロー効果
    paint.color = color.withOpacity(opacity * 0.3);
    canvas.drawCircle(position, size * 2, paint);
  }
  
  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const int points = 5;
    final double outerRadius = size;
    final double innerRadius = size * 0.4;
    
    for (int i = 0; i < points * 2; i++) {
      final double angle = (i * math.pi) / points;
      final double radius = i.isEven ? outerRadius : innerRadius;
      final double x = center.dx + radius * math.cos(angle - math.pi / 2);
      final double y = center.dy + radius * math.sin(angle - math.pi / 2);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }
}

/// 花火バーストエフェクト
class FireworkBurst extends ParticleEmitter {
  final int particleCount;
  final double burstRadius;
  final List<Color> colors;
  final List<_FireworkParticle> _particles = [];
  
  FireworkBurst({
    required Offset center,
    this.particleCount = 50,
    this.burstRadius = 100,
    this.colors = CelebrationParticles.celebrationColors,
  }) : super(
    position: center,
    duration: 2.0,
    particlesPerSecond: 0,
  ) {
    _initializeParticles();
  }
  
  void _initializeParticles() {
    final random = math.Random();
    
    for (int i = 0; i < particleCount; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 50 + random.nextDouble() * 150;
      final velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      
      _particles.add(_FireworkParticle(
        position: position,
        velocity: velocity,
        color: colors[random.nextInt(colors.length)],
        size: 2 + random.nextDouble() * 3,
        lifespan: (1500 + random.nextInt(500)).toDouble(),
        trailLength: 5 + random.nextInt(10),
      ));
    }
  }
  
  @override
  void emitParticle() {
    // All particles are emitted at initialization
  }
  
  @override
  void update(double deltaTime) {
    super.update(deltaTime);
    
    for (final particle in _particles) {
      particle.update(deltaTime);
    }
  }
}

/// 紙吹雪パーティクル
class ConfettiParticle extends Particle {
  final double rotationSpeed;
  double rotation = 0;
  final Size particleSize;
  
  ConfettiParticle({
    required Offset position,
    required Offset velocity,
    required Color color,
    required int lifetime,
    this.rotationSpeed = 5.0,
    this.particleSize = const Size(6, 3),
  }) : super(
    position: position,
    velocity: velocity,
    acceleration: const Offset(0, 200), // 重力
    color: color,
    size: 4.0,
    lifetime: lifetime,
  );
  
  @override
  void updateCustom(double deltaTime) {
    rotation += rotationSpeed * deltaTime;
    // 空気抵抗
    velocity = Offset(velocity.dx * 0.99, velocity.dy);
  }
  
  @override
  void render(Canvas canvas, Paint paint) {
    paint.color = color.withOpacity(opacity);
    
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: particleSize.width,
        height: particleSize.height,
      ),
      paint,
    );
    
    canvas.restore();
  }
}

/// 紙吹雪エミッター（簡易版）
class ConfettiEmitter extends ParticleEmitter {
  final Rect sourceRect;
  final int totalParticles;
  int _emittedCount = 0;
  
  ConfettiEmitter({
    required this.sourceRect,
    this.totalParticles = 100,
  }) : super(
    position: sourceRect.center,
    duration: 0.5, // 0.5秒で全て放出
    particlesPerSecond: 200, // 高速で放出
  );
  
  @override
  void emitParticle() {
    if (_emittedCount >= totalParticles) return;
    
    // 実際の実装では ParticleSystem から ConfettiParticle を取得して設定
    _emittedCount++;
  }
}

/// フラッシュエフェクト
class FlashParticle extends Particle {
  final double intensity;
  final Size screenSize;
  
  FlashParticle({
    required Offset position,
    required Color color,
    required int lifetime,
    this.intensity = 1.0,
    this.screenSize = const Size(800, 600),
  }) : super(
    position: position,
    velocity: Offset.zero,
    color: color,
    size: 1.0,
    lifetime: lifetime,
  );
  
  @override
  void render(Canvas canvas, Paint paint) {
    final progress = 1.0 - (lifetime / maxLifetime);
    final flashOpacity = intensity * (1.0 - progress) * math.sin((1.0 - progress) * math.pi);
    
    if (flashOpacity > 0) {
      paint.color = color.withOpacity(flashOpacity * 0.8);
      
      canvas.drawRect(
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height),
        paint,
      );
    }
  }
}

/// 衝撃波エフェクト
class ShockwaveParticle extends Particle {
  final double maxRadius;
  
  ShockwaveParticle({
    required Offset position,
    required Color color,
    required int lifetime,
    this.maxRadius = 300,
  }) : super(
    position: position,
    velocity: Offset.zero,
    color: color,
    size: 0,
    lifetime: lifetime,
  );
  
  @override
  void render(Canvas canvas, Paint paint) {
    final progress = 1.0 - (lifetime / maxLifetime);
    final radius = maxRadius * progress;
    final currentOpacity = (1.0 - progress) * 0.8;
    
    if (currentOpacity > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = (3 + progress * 5).toDouble()
        ..color = color.withOpacity(currentOpacity);
      
      canvas.drawCircle(position, radius, paint);
      
      // 内側のグロー
      paint.strokeWidth = 1;
      paint.color = color.withOpacity(currentOpacity * 0.5);
      canvas.drawCircle(position, radius * 0.8, paint);
    }
  }
}

// 内部パーティクルクラス群（簡易版）
class _ExplosionParticle {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final double lifespan;
  final double gravity;
  double age = 0;
  
  _ExplosionParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifespan,
    required this.gravity,
  });
  
  void update(double deltaTime) {
    age += deltaTime;
    
    // 重力適用
    velocity = Offset(
      velocity.dx * 0.98, // 空気抵抗
      velocity.dy + gravity * deltaTime / 1000,
    );
    
    position = Offset(
      position.dx + velocity.dx * deltaTime / 1000,
      position.dy + velocity.dy * deltaTime / 1000,
    );
  }
  
  bool get isDead => age >= lifespan;
  double get opacity => math.max(0, 1.0 - age / lifespan);
}

class _FireworkParticle {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final double lifespan;
  final int trailLength;
  final List<Offset> trail = [];
  double age = 0;
  
  _FireworkParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.lifespan,
    required this.trailLength,
  });
  
  void update(double deltaTime) {
    age += deltaTime;
    
    // 軌跡更新
    trail.add(position);
    if (trail.length > trailLength) {
      trail.removeAt(0);
    }
    
    // 位置更新
    position = Offset(
      position.dx + velocity.dx * deltaTime / 1000,
      position.dy + velocity.dy * deltaTime / 1000,
    );
    
    // 減速
    velocity = Offset(
      velocity.dx * 0.95,
      velocity.dy * 0.95,
    );
  }
  
  bool get isDead => age >= lifespan;
  double get opacity => math.max(0, 1.0 - age / lifespan);
}