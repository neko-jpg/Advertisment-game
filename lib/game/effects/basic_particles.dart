import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'particle_engine.dart';

/// Basic circular particle
class BasicParticle extends Particle {
  double rotationSpeed;
  double currentRotation;
  double sizeDecay;
  double initialSize;

  BasicParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.rotationSpeed = 0.0,
    this.currentRotation = 0.0,
    this.sizeDecay = 0.0,
  }) : initialSize = size;

  @override
  void updateCustom(double deltaTime) {
    // Update rotation
    currentRotation += rotationSpeed * deltaTime;

    // Apply size decay
    if (sizeDecay > 0) {
      final lifeRatio = lifetime / maxLifetime;
      size = initialSize * lifeRatio;
    }
  }

  @override
  void render(Canvas canvas, Paint paint) {
    paint.color = color.withOpacity(opacity);
    canvas.drawCircle(position, size, paint);
  }

  /// Factory method for creating basic particles
  static BasicParticle create() {
    return BasicParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.white,
      size: 2.0,
      lifetime: 60,
    );
  }
}

/// Spark particle with trail effect
class SparkParticle extends Particle {
  final List<Offset> trail = [];
  final int maxTrailLength;
  double friction;

  SparkParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.maxTrailLength = 5,
    this.friction = 0.98,
  });

  @override
  void updateCustom(double deltaTime) {
    // Add current position to trail
    trail.add(position);
    if (trail.length > maxTrailLength) {
      trail.removeAt(0);
    }

    // Apply friction
    velocity = Offset(
      velocity.dx * friction,
      velocity.dy * friction,
    );
  }

  @override
  void render(Canvas canvas, Paint paint) {
    // Render trail
    for (int i = 0; i < trail.length - 1; i++) {
      final alpha = (i / trail.length) * opacity;
      paint.color = color.withOpacity(alpha);
      paint.strokeWidth = size * (i / trail.length);
      canvas.drawLine(trail[i], trail[i + 1], paint);
    }

    // Render main particle
    paint.color = color.withOpacity(opacity);
    canvas.drawCircle(position, size, paint);
  }

  /// Factory method for creating spark particles
  static SparkParticle create() {
    return SparkParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.yellow,
      size: 1.5,
      lifetime: 30,
      maxTrailLength: 5,
    );
  }
}

/// Glowing particle with pulsing effect
class GlowParticle extends Particle {
  double pulseSpeed;
  double pulseAmplitude;
  double baseSize;
  double glowRadius;

  GlowParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.pulseSpeed = 0.1,
    this.pulseAmplitude = 0.5,
    this.glowRadius = 10.0,
  }) : baseSize = size;

  @override
  void updateCustom(double deltaTime) {
    // Pulsing effect
    final pulseValue = math.sin((maxLifetime - lifetime) * pulseSpeed) * pulseAmplitude;
    size = baseSize + pulseValue;
  }

  @override
  void render(Canvas canvas, Paint paint) {
    // Render glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(opacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    
    canvas.drawCircle(position, glowRadius, glowPaint);

    // Render main particle
    paint.color = color.withOpacity(opacity);
    canvas.drawCircle(position, size, paint);
  }

  /// Factory method for creating glow particles
  static GlowParticle create() {
    return GlowParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.cyan,
      size: 3.0,
      lifetime: 120,
      glowRadius: 8.0,
    );
  }
}

/// Textured particle (for more complex effects)
class TexturedParticle extends Particle {
  double rotation;
  double rotationSpeed;
  double scale;
  double scaleSpeed;

  TexturedParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
    this.scale = 1.0,
    this.scaleSpeed = 0.0,
  });

  @override
  void updateCustom(double deltaTime) {
    rotation += rotationSpeed * deltaTime;
    scale += scaleSpeed * deltaTime;
    scale = scale.clamp(0.1, 3.0);
  }

  @override
  void render(Canvas canvas, Paint paint) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(rotation);
    canvas.scale(scale);

    paint.color = color.withOpacity(opacity);
    
    // Draw a star shape as example texture
    _drawStar(canvas, paint, size);
    
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Paint paint, double radius) {
    const int points = 5;
    final path = Path();
    
    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points;
      final r = i.isEven ? radius : radius * 0.5;
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Factory method for creating textured particles
  static TexturedParticle create() {
    return TexturedParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.white,
      size: 4.0,
      lifetime: 90,
      rotationSpeed: 0.05,
    );
  }
}

/// Particle emitter for basic effects
class BasicParticleEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final Color baseColor;
  final double baseSize;
  final double speedRange;
  final double sizeVariation;
  final double angleSpread;
  final double emissionAngle;

  BasicParticleEmitter({
    required this.particleSystem,
    required super.position,
    super.isActive,
    super.duration,
    super.particlesPerSecond,
    this.baseColor = Colors.white,
    this.baseSize = 2.0,
    this.speedRange = 50.0,
    this.sizeVariation = 0.5,
    this.angleSpread = math.pi * 2, // Full circle
    this.emissionAngle = 0.0,
  });

  @override
  void emitParticle() {
    final pool = particleSystem.getPool<BasicParticle>();
    if (pool == null) return;

    final particle = pool.acquire();
    if (particle == null) return;

    // Reset particle properties
    particle.position = position + ParticleUtils.randomInCircle(5.0);
    particle.velocity = ParticleUtils.randomVelocityInCone(
      speedRange,
      emissionAngle,
      angleSpread,
    );
    particle.acceleration = const Offset(0, 20); // Gravity
    particle.color = ParticleUtils.randomColorVariation(baseColor, 0.2);
    particle.size = baseSize + (math.Random().nextDouble() - 0.5) * sizeVariation;
    particle.opacity = 1.0;
    particle.lifetime = 30 + math.Random().nextInt(60);
    particle.maxLifetime = particle.lifetime;
    particle.rotationSpeed = (math.Random().nextDouble() - 0.5) * 0.1;
    particle.sizeDecay = 0.02;
    particle.isActive = true;
  }
}

/// Spark emitter for electrical effects
class SparkEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final Color sparkColor;
  final double intensity;

  SparkEmitter({
    required this.particleSystem,
    required super.position,
    super.isActive,
    super.duration,
    super.particlesPerSecond,
    this.sparkColor = Colors.yellow,
    this.intensity = 1.0,
  });

  @override
  void emitParticle() {
    final pool = particleSystem.getPool<SparkParticle>();
    if (pool == null) return;

    final particle = pool.acquire();
    if (particle == null) return;

    final random = math.Random();
    
    // Reset particle properties
    particle.position = position + ParticleUtils.randomInCircle(3.0);
    particle.velocity = ParticleUtils.randomVelocityInCone(
      100.0 * intensity,
      random.nextDouble() * math.pi * 2,
      math.pi / 4,
    );
    particle.acceleration = const Offset(0, 30);
    particle.color = sparkColor;
    particle.size = 1.0 + random.nextDouble() * 2.0;
    particle.opacity = 1.0;
    particle.lifetime = (20 + random.nextInt(20)) * intensity.round();
    particle.maxLifetime = particle.lifetime;
    particle.friction = 0.95;
    particle.trail.clear();
    particle.isActive = true;
  }
}

/// Glow emitter for magical effects
class GlowEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final Color glowColor;
  final double glowIntensity;

  GlowEmitter({
    required this.particleSystem,
    required super.position,
    super.isActive,
    super.duration,
    super.particlesPerSecond,
    this.glowColor = Colors.cyan,
    this.glowIntensity = 1.0,
  });

  @override
  void emitParticle() {
    final pool = particleSystem.getPool<GlowParticle>();
    if (pool == null) return;

    final particle = pool.acquire();
    if (particle == null) return;

    final random = math.Random();
    
    // Reset particle properties
    particle.position = position + ParticleUtils.randomInCircle(8.0);
    particle.velocity = ParticleUtils.randomVelocityInCone(
      30.0,
      -math.pi / 2, // Upward
      math.pi / 3,
    );
    particle.acceleration = const Offset(0, -10); // Float upward
    particle.color = glowColor;
    particle.size = 2.0 + random.nextDouble() * 3.0;
    particle.opacity = glowIntensity;
    particle.lifetime = (60 + random.nextInt(120));
    particle.maxLifetime = particle.lifetime;
    particle.pulseSpeed = 0.05 + random.nextDouble() * 0.1;
    particle.pulseAmplitude = 0.3 + random.nextDouble() * 0.4;
    particle.glowRadius = 6.0 + random.nextDouble() * 8.0;
    particle.isActive = true;
  }
}