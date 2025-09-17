import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'particle_engine.dart';
import 'special_particles.dart';

/// Explosion emitter for creating various explosion effects
class ExplosionEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final ExplosionType explosionType;
  final double intensity;
  final Color explosionColor;
  final bool createShockwave;
  final int particleCount;

  ExplosionEmitter({
    required this.particleSystem,
    required super.position,
    this.explosionType = ExplosionType.normal,
    this.intensity = 1.0,
    this.explosionColor = Colors.orange,
    this.createShockwave = true,
    this.particleCount = 25,
  }) : super(
    duration: 0.5, // Short burst
    particlesPerSecond: particleCount * 2, // Emit all particles quickly
  );

  @override
  void emitParticle() {
    final pool = particleSystem.getPool<ExplosionParticle>();
    if (pool == null) return;

    final particle = pool.acquire();
    if (particle == null) return;

    final random = math.Random();
    final angle = random.nextDouble() * math.pi * 2;
    final speed = (50.0 + random.nextDouble() * 100.0) * intensity;
    
    // Reset particle properties
    particle.position = position + ParticleUtils.randomInCircle(5.0);
    particle.velocity = Offset(
      math.cos(angle) * speed,
      math.sin(angle) * speed,
    );
    
    // Set acceleration based on explosion type
    switch (explosionType) {
      case ExplosionType.normal:
        particle.acceleration = const Offset(0, 50);
        break;
      case ExplosionType.fire:
        particle.acceleration = const Offset(0, -20); // Initially rise
        break;
      case ExplosionType.ice:
        particle.acceleration = const Offset(0, 30); // Less gravity
        break;
      case ExplosionType.electric:
        particle.acceleration = const Offset(0, 20);
        break;
    }
    
    particle.color = _getExplosionColor(explosionType, random);
    particle.size = (2.0 + random.nextDouble() * 4.0) * intensity;
    particle.opacity = 1.0;
    particle.lifetime = ((30 + random.nextInt(60)) * intensity).round();
    particle.maxLifetime = particle.lifetime;
    particle.explosionType = explosionType;
    particle.hasShockwave = createShockwave && random.nextDouble() < 0.3;
    particle.maxShockwaveRadius = (30.0 + random.nextDouble() * 40.0) * intensity;
    particle.shockwaveRadius = 0.0;
    particle.shockwaveOpacity = 1.0;
    particle.debrisRotation = random.nextDouble() * math.pi * 2;
    particle.debrisRotationSpeed = (random.nextDouble() - 0.5) * 0.3;
    particle.isActive = true;
  }

  Color _getExplosionColor(ExplosionType type, math.Random random) {
    switch (type) {
      case ExplosionType.normal:
        return ParticleUtils.randomColorVariation(explosionColor, 0.3);
      case ExplosionType.fire:
        final colors = [Colors.red, Colors.orange, Colors.yellow];
        return colors[random.nextInt(colors.length)];
      case ExplosionType.ice:
        final colors = [Colors.lightBlue, Colors.cyan, Colors.white];
        return colors[random.nextInt(colors.length)];
      case ExplosionType.electric:
        final colors = [Colors.yellow, Colors.white, Colors.lightBlue];
        return colors[random.nextInt(colors.length)];
    }
  }
}

/// Trail emitter for creating continuous trail effects
class TrailEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final TrailType trailType;
  final Color trailColor;
  final double trailIntensity;
  final double trailWidth;

  TrailEmitter({
    required this.particleSystem,
    required super.position,
    super.isActive,
    super.duration,
    super.particlesPerSecond,
    this.trailType = TrailType.smooth,
    this.trailColor = Colors.blue,
    this.trailIntensity = 1.0,
    this.trailWidth = 2.0,
  });

  @override
  void emitParticle() {
    final pool = particleSystem.getPool<TrailParticle>();
    if (pool == null) return;

    final particle = pool.acquire();
    if (particle == null) return;

    final random = math.Random();
    
    // Reset particle properties
    particle.position = position + ParticleUtils.randomInCircle(2.0);
    particle.velocity = _getTrailVelocity(trailType, random);
    particle.acceleration = _getTrailAcceleration(trailType);
    particle.color = ParticleUtils.randomColorVariation(trailColor, 0.1);
    particle.size = (1.5 + random.nextDouble() * 2.0) * trailIntensity;
    particle.opacity = trailIntensity;
    particle.lifetime = (60 + random.nextInt(90));
    particle.maxLifetime = particle.lifetime;
    particle.trailType = trailType;
    particle.trailWidth = trailWidth;
    particle.friction = _getTrailFriction(trailType);
    particle.waveAmplitude = _getWaveAmplitude(trailType);
    particle.waveFrequency = 0.05 + random.nextDouble() * 0.1;
    particle.trail.clear();
    particle.isActive = true;
  }

  Offset _getTrailVelocity(TrailType type, math.Random random) {
    final baseSpeed = 40.0 * trailIntensity;
    final angle = random.nextDouble() * math.pi * 2;
    
    switch (type) {
      case TrailType.smooth:
        return Offset(
          math.cos(angle) * baseSpeed,
          math.sin(angle) * baseSpeed,
        );
      case TrailType.wavy:
        return Offset(
          math.cos(angle) * baseSpeed * 0.8,
          math.sin(angle) * baseSpeed * 0.8,
        );
      case TrailType.spiral:
        return Offset(
          math.cos(angle) * baseSpeed * 0.6,
          math.sin(angle) * baseSpeed * 0.6,
        );
      case TrailType.electric:
        return Offset(
          math.cos(angle) * baseSpeed * 1.2,
          math.sin(angle) * baseSpeed * 1.2,
        );
    }
  }

  Offset _getTrailAcceleration(TrailType type) {
    switch (type) {
      case TrailType.smooth:
        return const Offset(0, 20);
      case TrailType.wavy:
        return const Offset(0, 15);
      case TrailType.spiral:
        return const Offset(0, 10);
      case TrailType.electric:
        return const Offset(0, 25);
    }
  }

  double _getTrailFriction(TrailType type) {
    switch (type) {
      case TrailType.smooth:
        return 0.99;
      case TrailType.wavy:
        return 0.98;
      case TrailType.spiral:
        return 0.97;
      case TrailType.electric:
        return 0.96;
    }
  }

  double _getWaveAmplitude(TrailType type) {
    switch (type) {
      case TrailType.smooth:
        return 0.0;
      case TrailType.wavy:
        return 8.0;
      case TrailType.spiral:
        return 12.0;
      case TrailType.electric:
        return 5.0;
    }
  }
}

/// Enhanced glow emitter for magical and energy effects
class EnhancedGlowEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final GlowType glowType;
  final Color glowColor;
  final double glowIntensity;
  final double energyLevel;

  EnhancedGlowEmitter({
    required this.particleSystem,
    required super.position,
    super.isActive,
    super.duration,
    super.particlesPerSecond,
    this.glowType = GlowType.soft,
    this.glowColor = Colors.cyan,
    this.glowIntensity = 1.0,
    this.energyLevel = 1.0,
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
    particle.velocity = _getGlowVelocity(glowType, random);
    particle.acceleration = _getGlowAcceleration(glowType);
    particle.color = _getGlowColor(glowType, random);
    particle.size = (2.0 + random.nextDouble() * 4.0) * glowIntensity;
    particle.opacity = glowIntensity;
    particle.lifetime = _getGlowLifetime(glowType, random);
    particle.maxLifetime = particle.lifetime;
    particle.glowType = glowType;
    particle.energyLevel = energyLevel;
    particle.innerGlowRadius = (6.0 + random.nextDouble() * 4.0) * glowIntensity;
    particle.outerGlowRadius = (12.0 + random.nextDouble() * 8.0) * glowIntensity;
    particle.pulseSpeed = _getPulseSpeed(glowType, random);
    particle.pulseAmplitude = _getPulseAmplitude(glowType, random);
    particle.innerGlowColor = particle.color;
    particle.outerGlowColor = particle.color.withOpacity(0.3);
    particle.isActive = true;
  }

  Offset _getGlowVelocity(GlowType type, math.Random random) {
    final baseSpeed = 25.0 * glowIntensity;
    
    switch (type) {
      case GlowType.soft:
        return ParticleUtils.randomVelocityInCone(
          baseSpeed,
          -math.pi / 2, // Upward
          math.pi / 3,
        );
      case GlowType.intense:
        return ParticleUtils.randomVelocityInCone(
          baseSpeed * 1.5,
          -math.pi / 2,
          math.pi / 2,
        );
      case GlowType.magical:
        return ParticleUtils.randomVelocityInCone(
          baseSpeed * 0.8,
          random.nextDouble() * math.pi * 2,
          math.pi,
        );
      case GlowType.electric:
        return ParticleUtils.randomVelocityInCone(
          baseSpeed * 2.0,
          random.nextDouble() * math.pi * 2,
          math.pi * 2,
        );
    }
  }

  Offset _getGlowAcceleration(GlowType type) {
    switch (type) {
      case GlowType.soft:
        return const Offset(0, -10);
      case GlowType.intense:
        return const Offset(0, -15);
      case GlowType.magical:
        return const Offset(0, -5);
      case GlowType.electric:
        return const Offset(0, 0);
    }
  }

  Color _getGlowColor(GlowType type, math.Random random) {
    switch (type) {
      case GlowType.soft:
        return ParticleUtils.randomColorVariation(glowColor, 0.1);
      case GlowType.intense:
        return ParticleUtils.randomColorVariation(glowColor, 0.2);
      case GlowType.magical:
        final hue = random.nextDouble() * 360;
        return HSVColor.fromAHSV(1.0, hue, 0.8, 1.0).toColor();
      case GlowType.electric:
        final colors = [Colors.yellow, Colors.white, Colors.lightBlue];
        return colors[random.nextInt(colors.length)];
    }
  }

  int _getGlowLifetime(GlowType type, math.Random random) {
    switch (type) {
      case GlowType.soft:
        return 80 + random.nextInt(80);
      case GlowType.intense:
        return 60 + random.nextInt(60);
      case GlowType.magical:
        return 120 + random.nextInt(120);
      case GlowType.electric:
        return 40 + random.nextInt(40);
    }
  }

  double _getPulseSpeed(GlowType type, math.Random random) {
    switch (type) {
      case GlowType.soft:
        return 0.05 + random.nextDouble() * 0.05;
      case GlowType.intense:
        return 0.1 + random.nextDouble() * 0.1;
      case GlowType.magical:
        return 0.03 + random.nextDouble() * 0.04;
      case GlowType.electric:
        return 0.15 + random.nextDouble() * 0.15;
    }
  }

  double _getPulseAmplitude(GlowType type, math.Random random) {
    switch (type) {
      case GlowType.soft:
        return 0.3 + random.nextDouble() * 0.2;
      case GlowType.intense:
        return 0.5 + random.nextDouble() * 0.3;
      case GlowType.magical:
        return 0.4 + random.nextDouble() * 0.4;
      case GlowType.electric:
        return 0.6 + random.nextDouble() * 0.4;
    }
  }
}

/// Composite emitter that can create complex multi-layered effects
class CompositeEffectEmitter extends ParticleEmitter {
  final ParticleSystem particleSystem;
  final List<ParticleEmitter> childEmitters = [];
  final EffectComposition composition;

  CompositeEffectEmitter({
    required this.particleSystem,
    required super.position,
    super.isActive,
    super.duration,
    required this.composition,
  }) : super(particlesPerSecond: 0) { // Doesn't emit particles directly
    _createChildEmitters();
  }

  void _createChildEmitters() {
    switch (composition) {
      case EffectComposition.fireExplosion:
        childEmitters.addAll([
          ExplosionEmitter(
            particleSystem: particleSystem,
            position: position,
            explosionType: ExplosionType.fire,
            intensity: 1.5,
            particleCount: 30,
          ),
          EnhancedGlowEmitter(
            particleSystem: particleSystem,
            position: position,
            glowType: GlowType.intense,
            glowColor: Colors.orange,
            duration: 2.0,
            particlesPerSecond: 15,
          ),
        ]);
        break;
      case EffectComposition.electricStorm:
        childEmitters.addAll([
          ExplosionEmitter(
            particleSystem: particleSystem,
            position: position,
            explosionType: ExplosionType.electric,
            intensity: 1.2,
            particleCount: 20,
          ),
          TrailEmitter(
            particleSystem: particleSystem,
            position: position,
            trailType: TrailType.electric,
            trailColor: Colors.yellow,
            duration: 3.0,
            particlesPerSecond: 25,
          ),
          EnhancedGlowEmitter(
            particleSystem: particleSystem,
            position: position,
            glowType: GlowType.electric,
            duration: 2.5,
            particlesPerSecond: 10,
          ),
        ]);
        break;
      case EffectComposition.magicalBurst:
        childEmitters.addAll([
          EnhancedGlowEmitter(
            particleSystem: particleSystem,
            position: position,
            glowType: GlowType.magical,
            duration: 4.0,
            particlesPerSecond: 20,
          ),
          TrailEmitter(
            particleSystem: particleSystem,
            position: position,
            trailType: TrailType.spiral,
            trailColor: Colors.purple,
            duration: 3.0,
            particlesPerSecond: 15,
          ),
        ]);
        break;
      case EffectComposition.iceShatter:
        childEmitters.addAll([
          ExplosionEmitter(
            particleSystem: particleSystem,
            position: position,
            explosionType: ExplosionType.ice,
            intensity: 1.0,
            explosionColor: Colors.lightBlue,
            particleCount: 25,
          ),
          EnhancedGlowEmitter(
            particleSystem: particleSystem,
            position: position,
            glowType: GlowType.soft,
            glowColor: Colors.cyan,
            duration: 2.0,
            particlesPerSecond: 12,
          ),
        ]);
        break;
    }

    // Add all child emitters to the particle system
    for (final emitter in childEmitters) {
      particleSystem.addEmitter(emitter);
    }
  }

  @override
  void update(double deltaTime) {
    super.update(deltaTime);
    
    // Update child emitters
    for (final emitter in childEmitters.toList()) {
      emitter.update(deltaTime);
      if (emitter.isFinished) {
        childEmitters.remove(emitter);
        particleSystem.removeEmitter(emitter);
      }
    }
  }

  @override
  void emitParticle() {
    // This emitter doesn't emit particles directly
  }

  @override
  bool get isFinished => super.isFinished && childEmitters.isEmpty;
}

/// Effect composition types
enum EffectComposition {
  fireExplosion,
  electricStorm,
  magicalBurst,
  iceShatter,
}