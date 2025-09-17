import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'particle_engine.dart';

/// Explosion particle with shockwave and debris effects
class ExplosionParticle extends Particle {
  double shockwaveRadius;
  double maxShockwaveRadius;
  double shockwaveOpacity;
  bool hasShockwave;
  double debrisRotation;
  double debrisRotationSpeed;
  ExplosionType explosionType;

  ExplosionParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.shockwaveRadius = 0.0,
    this.maxShockwaveRadius = 50.0,
    this.shockwaveOpacity = 1.0,
    this.hasShockwave = true,
    this.debrisRotation = 0.0,
    this.debrisRotationSpeed = 0.0,
    this.explosionType = ExplosionType.normal,
  });

  @override
  void updateCustom(double deltaTime) {
    // Update shockwave
    if (hasShockwave && shockwaveRadius < maxShockwaveRadius) {
      shockwaveRadius += (maxShockwaveRadius / maxLifetime) * 2;
      shockwaveOpacity = 1.0 - (shockwaveRadius / maxShockwaveRadius);
    }

    // Update debris rotation
    debrisRotation += debrisRotationSpeed * deltaTime;

    // Apply explosion-specific physics
    switch (explosionType) {
      case ExplosionType.normal:
        // Standard explosion with gravity
        break;
      case ExplosionType.fire:
        // Fire explosion - particles rise initially then fall
        if (lifetime > maxLifetime * 0.7) {
          acceleration = const Offset(0, -30); // Rise
        } else {
          acceleration = const Offset(0, 50); // Fall faster
        }
        break;
      case ExplosionType.ice:
        // Ice explosion - particles slow down quickly
        velocity = Offset(
          velocity.dx * 0.95,
          velocity.dy * 0.95,
        );
        break;
      case ExplosionType.electric:
        // Electric explosion - erratic movement
        final random = math.Random();
        if (random.nextDouble() < 0.1) {
          velocity = Offset(
            velocity.dx + (random.nextDouble() - 0.5) * 20,
            velocity.dy + (random.nextDouble() - 0.5) * 20,
          );
        }
        break;
    }
  }

  @override
  void render(Canvas canvas, Paint paint) {
    // Render shockwave
    if (hasShockwave && shockwaveRadius > 0 && shockwaveOpacity > 0) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3.0;
      paint.color = color.withOpacity(shockwaveOpacity * 0.5);
      canvas.drawCircle(position, shockwaveRadius, paint);
      
      // Inner shockwave
      paint.strokeWidth = 1.5;
      paint.color = color.withOpacity(shockwaveOpacity * 0.8);
      canvas.drawCircle(position, shockwaveRadius * 0.7, paint);
    }

    // Render debris particle
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(debrisRotation);

    paint.style = PaintingStyle.fill;
    paint.color = color.withOpacity(opacity);

    switch (explosionType) {
      case ExplosionType.normal:
        canvas.drawCircle(Offset.zero, size, paint);
        break;
      case ExplosionType.fire:
        _drawFlame(canvas, paint, size);
        break;
      case ExplosionType.ice:
        _drawIceShard(canvas, paint, size);
        break;
      case ExplosionType.electric:
        _drawSpark(canvas, paint, size);
        break;
    }

    canvas.restore();
  }

  void _drawFlame(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    const int points = 6;
    
    for (int i = 0; i < points; i++) {
      final angle = (i * 2 * math.pi) / points;
      final r = radius * (0.7 + math.sin(debrisRotation * 3 + i) * 0.3);
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

  void _drawIceShard(Canvas canvas, Paint paint, double radius) {
    final path = Path();
    path.moveTo(0, -radius);
    path.lineTo(radius * 0.5, 0);
    path.lineTo(0, radius);
    path.lineTo(-radius * 0.5, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  void _drawSpark(Canvas canvas, Paint paint, double radius) {
    paint.strokeWidth = radius * 0.3;
    paint.style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(-radius, 0),
      Offset(radius, 0),
      paint,
    );
    canvas.drawLine(
      Offset(0, -radius),
      Offset(0, radius),
      paint,
    );
  }

  /// Factory method for creating explosion particles
  static ExplosionParticle create() {
    return ExplosionParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.orange,
      size: 4.0,
      lifetime: 60,
      maxShockwaveRadius: 30.0,
    );
  }
}

/// Trail particle with smooth fading trail effect
class TrailParticle extends Particle {
  final List<TrailPoint> trail = [];
  final int maxTrailLength;
  double trailWidth;
  double friction;
  TrailType trailType;
  double waveAmplitude;
  double waveFrequency;

  TrailParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.maxTrailLength = 15,
    this.trailWidth = 2.0,
    this.friction = 0.99,
    this.trailType = TrailType.smooth,
    this.waveAmplitude = 0.0,
    this.waveFrequency = 0.1,
  });

  @override
  void updateCustom(double deltaTime) {
    // Add current position to trail
    trail.add(TrailPoint(
      position: position,
      timestamp: maxLifetime - lifetime,
      size: size,
    ));

    // Remove old trail points
    if (trail.length > maxTrailLength) {
      trail.removeAt(0);
    }

    // Apply friction
    velocity = Offset(
      velocity.dx * friction,
      velocity.dy * friction,
    );

    // Apply trail-specific effects
    switch (trailType) {
      case TrailType.smooth:
        // Standard smooth trail
        break;
      case TrailType.wavy:
        // Add wave motion
        final waveOffset = math.sin((maxLifetime - lifetime) * waveFrequency) * waveAmplitude;
        final perpendicular = _getPerpendicular(velocity.direction);
        position = Offset(
          position.dx + perpendicular.dx * waveOffset,
          position.dy + perpendicular.dy * waveOffset,
        );
        break;
      case TrailType.spiral:
        // Add spiral motion
        final spiralAngle = (maxLifetime - lifetime) * 0.2;
        final spiralRadius = waveAmplitude * (lifetime / maxLifetime);
        position = Offset(
          position.dx + math.cos(spiralAngle) * spiralRadius,
          position.dy + math.sin(spiralAngle) * spiralRadius,
        );
        break;
      case TrailType.electric:
        // Add random jitter
        final random = math.Random();
        if (random.nextDouble() < 0.3) {
          position = Offset(
            position.dx + (random.nextDouble() - 0.5) * 4,
            position.dy + (random.nextDouble() - 0.5) * 4,
          );
        }
        break;
    }
  }

  Offset _getPerpendicular(double angle) {
    return Offset(-math.sin(angle), math.cos(angle));
  }

  @override
  void render(Canvas canvas, Paint paint) {
    if (trail.length < 2) return;

    // Render trail
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;

    for (int i = 0; i < trail.length - 1; i++) {
      final current = trail[i];
      final next = trail[i + 1];
      final progress = i / (trail.length - 1);
      
      // Calculate trail opacity and width
      final trailOpacity = opacity * progress * progress;
      final currentWidth = trailWidth * progress;
      
      paint.strokeWidth = currentWidth;
      paint.color = color.withOpacity(trailOpacity);
      
      canvas.drawLine(current.position, next.position, paint);
    }

    // Render main particle
    paint.style = PaintingStyle.fill;
    paint.color = color.withOpacity(opacity);
    canvas.drawCircle(position, size, paint);

    // Add glow effect for electric trails
    if (trailType == TrailType.electric) {
      paint.color = color.withOpacity(opacity * 0.3);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(position, size * 2, paint);
      paint.maskFilter = null;
    }
  }

  /// Factory method for creating trail particles
  static TrailParticle create() {
    return TrailParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.blue,
      size: 2.0,
      lifetime: 90,
      maxTrailLength: 12,
      trailWidth: 1.5,
    );
  }
}

/// Enhanced glow particle with multiple glow layers
class GlowParticle extends Particle {
  double innerGlowRadius;
  double outerGlowRadius;
  double pulseSpeed;
  double pulseAmplitude;
  double baseSize;
  Color innerGlowColor;
  Color outerGlowColor;
  GlowType glowType;
  double energyLevel;

  GlowParticle({
    required super.position,
    required super.velocity,
    super.acceleration,
    required super.color,
    required super.size,
    super.opacity,
    required super.lifetime,
    this.innerGlowRadius = 8.0,
    this.outerGlowRadius = 16.0,
    this.pulseSpeed = 0.1,
    this.pulseAmplitude = 0.5,
    Color? innerGlowColor,
    Color? outerGlowColor,
    this.glowType = GlowType.soft,
    this.energyLevel = 1.0,
  }) : baseSize = size,
       innerGlowColor = innerGlowColor ?? color,
       outerGlowColor = outerGlowColor ?? color.withOpacity(0.3);

  @override
  void updateCustom(double deltaTime) {
    // Pulsing effect
    final pulseValue = math.sin((maxLifetime - lifetime) * pulseSpeed) * pulseAmplitude;
    size = baseSize + pulseValue;
    
    // Update glow radii based on energy level
    innerGlowRadius = (8.0 + pulseValue * 2) * energyLevel;
    outerGlowRadius = (16.0 + pulseValue * 4) * energyLevel;

    // Apply glow-specific effects
    switch (glowType) {
      case GlowType.soft:
        // Standard soft glow
        break;
      case GlowType.intense:
        // Intense glow with higher energy
        energyLevel = 1.5 + math.sin((maxLifetime - lifetime) * 0.2) * 0.5;
        break;
      case GlowType.magical:
        // Magical glow with color shifting
        final hue = ((maxLifetime - lifetime) * 2) % 360;
        color = HSVColor.fromAHSV(1.0, hue.toDouble(), 0.8, 1.0).toColor();
        innerGlowColor = color;
        outerGlowColor = color.withOpacity(0.3);
        break;
      case GlowType.electric:
        // Electric glow with crackling effect
        final random = math.Random();
        if (random.nextDouble() < 0.1) {
          energyLevel = 0.5 + random.nextDouble() * 1.5;
        }
        break;
    }
  }

  @override
  void render(Canvas canvas, Paint paint) {
    // Render outer glow
    paint.color = outerGlowColor.withOpacity(opacity * 0.2);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(position, outerGlowRadius, paint);

    // Render middle glow
    paint.color = innerGlowColor.withOpacity(opacity * 0.4);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(position, innerGlowRadius, paint);

    // Render inner glow
    paint.color = color.withOpacity(opacity * 0.6);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(position, innerGlowRadius * 0.5, paint);

    // Clear mask filter
    paint.maskFilter = null;

    // Render core particle
    paint.color = color.withOpacity(opacity);
    canvas.drawCircle(position, size, paint);

    // Add special effects based on glow type
    switch (glowType) {
      case GlowType.electric:
        _renderElectricArcs(canvas, paint);
        break;
      case GlowType.magical:
        _renderMagicalSparkles(canvas, paint);
        break;
      default:
        break;
    }
  }

  void _renderElectricArcs(Canvas canvas, Paint paint) {
    final random = math.Random();
    paint.strokeWidth = 1.0;
    paint.style = PaintingStyle.stroke;
    paint.color = color.withOpacity(opacity * 0.8);

    for (int i = 0; i < 3; i++) {
      if (random.nextDouble() < 0.3) {
        final angle = random.nextDouble() * math.pi * 2;
        final length = innerGlowRadius * (0.5 + random.nextDouble() * 0.5);
        final endPoint = Offset(
          position.dx + math.cos(angle) * length,
          position.dy + math.sin(angle) * length,
        );
        canvas.drawLine(position, endPoint, paint);
      }
    }
  }

  void _renderMagicalSparkles(Canvas canvas, Paint paint) {
    final random = math.Random();
    paint.style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      if (random.nextDouble() < 0.4) {
        final angle = random.nextDouble() * math.pi * 2;
        final distance = random.nextDouble() * outerGlowRadius;
        final sparklePos = Offset(
          position.dx + math.cos(angle) * distance,
          position.dy + math.sin(angle) * distance,
        );
        
        paint.color = color.withOpacity(opacity * 0.6);
        canvas.drawCircle(sparklePos, 1.0, paint);
      }
    }
  }

  /// Factory method for creating glow particles
  static GlowParticle create() {
    return GlowParticle(
      position: Offset.zero,
      velocity: Offset.zero,
      color: Colors.cyan,
      size: 3.0,
      lifetime: 120,
      innerGlowRadius: 6.0,
      outerGlowRadius: 12.0,
    );
  }
}

/// Trail point for trail particles
class TrailPoint {
  final Offset position;
  final int timestamp;
  final double size;

  const TrailPoint({
    required this.position,
    required this.timestamp,
    required this.size,
  });
}

/// Explosion types
enum ExplosionType {
  normal,
  fire,
  ice,
  electric,
}

/// Trail types
enum TrailType {
  smooth,
  wavy,
  spiral,
  electric,
}

/// Glow types
enum GlowType {
  soft,
  intense,
  magical,
  electric,
}